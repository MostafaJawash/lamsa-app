import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

/// `idle` only exists for search before any query was typed.
enum ListStatus { idle, loading, loaded, failed, notFound }

const _keep = Object();

final class ProductListState extends Equatable {
  const ProductListState({
    this.status = ListStatus.loading,
    this.filters = ListFilters.empty,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.error,
    this.facets,
    this.facetsFailed = false,
    this.ignored = const [],
    this.category,
    this.brand,
  });

  final ListStatus status;

  /// The filters actually applied (without any the backend rejected).
  final ListFilters filters;
  final List<ProductCard> items;
  final int total;
  final int page;
  final bool loadingMore;
  final bool loadMoreFailed;
  final String? error;
  final Facets? facets;
  final bool facetsFailed;
  final List<String> ignored;
  final CategoryDetail? category;
  final Brand? brand;

  bool get hasMore => items.length < total;

  ProductListState copyWith({
    ListStatus? status,
    ListFilters? filters,
    List<ProductCard>? items,
    int? total,
    int? page,
    bool? loadingMore,
    bool? loadMoreFailed,
    Object? error = _keep,
    Object? facets = _keep,
    bool? facetsFailed,
    List<String>? ignored,
    Object? category = _keep,
    Object? brand = _keep,
  }) =>
      ProductListState(
        status: status ?? this.status,
        filters: filters ?? this.filters,
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
        error: identical(error, _keep) ? this.error : error as String?,
        facets: identical(facets, _keep) ? this.facets : facets as Facets?,
        facetsFailed: facetsFailed ?? this.facetsFailed,
        ignored: ignored ?? this.ignored,
        category: identical(category, _keep)
            ? this.category
            : category as CategoryDetail?,
        brand: identical(brand, _keep) ? this.brand : brand as Brand?,
      );

  @override
  List<Object?> get props => [
        status,
        filters,
        items,
        total,
        page,
        loadingMore,
        loadMoreFailed,
        error,
        facets,
        facetsFailed,
        ignored,
        category,
        brand,
      ];
}

/// One product list: a category, a brand, "new", "sale" or a search. Handles
/// filters/sort, infinite-scroll pagination, the category/brand header and
/// the facets that feed the filter sheet. Responses of superseded requests
/// are dropped, so fast filter changes can never show stale results.
final class ProductListCubit extends Cubit<ProductListState> {
  ProductListCubit(
    this._repo,
    this.scope, {
    ListFilters initial = ListFilters.empty,
  }) : super(
          ProductListState(
            filters: initial,
            status: scope is SearchScope && initial.value('q') == null
                ? ListStatus.idle
                : ListStatus.loading,
          ),
        );

  final CatalogRepository _repo;
  final ListScope scope;
  int _token = 0;

  /// First load (or reload) with the current filters.
  Future<void> load({bool refresh = false}) async {
    final filters = state.filters;
    if (scope is SearchScope && filters.value('q') == null) {
      emit(const ProductListState(status: ListStatus.idle));
      return;
    }
    final token = ++_token;
    final keepContent = refresh && state.status == ListStatus.loaded;
    if (!keepContent) {
      emit(
        state.copyWith(
          status: ListStatus.loading,
          error: null,
          loadingMore: false,
          loadMoreFailed: false,
          ignored: const [],
        ),
      );
    }

    final header = _loadHeader(refresh);
    final facets = _repo
        .facets(scope, filters, refresh: refresh)
        .then<FacetsResult?>((r) => r)
        .onError<Object>((_, _) => null);
    try {
      final result = await _repo.products(scope, filters, refresh: refresh);
      final head = await header;
      if (token != _token || isClosed) return;
      if (head.notFound) {
        emit(state.copyWith(status: ListStatus.notFound));
        return;
      }
      emit(
        state.copyWith(
          status: ListStatus.loaded,
          filters: result.applied,
          items: result.page.items,
          total: result.page.total,
          page: result.page.page,
          ignored: result.ignored,
          category: head.category,
          brand: head.brand,
          error: null,
        ),
      );
    } on Object catch (e) {
      final head = await header;
      if (token != _token || isClosed) return;
      emit(
        head.notFound
            ? state.copyWith(status: ListStatus.notFound)
            : state.copyWith(status: ListStatus.failed, error: messageOf(e)),
      );
      return;
    }
    // Facets never block the list; a failure only disables the filter sheet.
    final f = await facets;
    if (token != _token || isClosed) return;
    emit(state.copyWith(facets: f?.facets, facetsFailed: f == null));
  }

  /// Retries only the facets (filter sheet "retry").
  Future<void> reloadFacets() async {
    final token = _token;
    emit(state.copyWith(facetsFailed: false));
    try {
      final f = await _repo.facets(scope, state.filters, refresh: true);
      if (token != _token || isClosed) return;
      emit(state.copyWith(facets: f.facets, facetsFailed: false));
    } on Object {
      if (token != _token || isClosed) return;
      emit(state.copyWith(facetsFailed: true));
    }
  }

  /// Applies new filters (page 1 again). Content stays visible while loading.
  Future<void> setFilters(ListFilters filters) {
    if (filters == state.filters &&
        state.status != ListStatus.idle &&
        state.status != ListStatus.failed) {
      return Future.value();
    }
    emit(state.copyWith(filters: filters));
    return load();
  }

  /// Search entry point: sets `q` (empty clears it) and reloads.
  Future<void> search(String query) {
    final q = query.trim();
    return setFilters(state.filters.setValue('q', q.isEmpty ? null : q, scope));
  }

  Future<void> loadMore() async {
    if (state.status != ListStatus.loaded ||
        state.loadingMore ||
        !state.hasMore) {
      return;
    }
    final token = _token;
    emit(state.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final result = await _repo.products(
        scope,
        state.filters,
        page: state.page + 1,
      );
      if (token != _token || isClosed) return;
      final known = {for (final p in state.items) p.id};
      emit(
        state.copyWith(
          items: [
            ...state.items,
            for (final p in result.page.items)
              if (!known.contains(p.id)) p,
          ],
          total: result.page.total,
          page: result.page.page,
          loadingMore: false,
        ),
      );
    } on Object {
      if (token != _token || isClosed) return;
      emit(state.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  Future<({bool notFound, CategoryDetail? category, Brand? brand})> _loadHeader(
    bool refresh,
  ) async {
    final s = scope;
    try {
      if (s is CategoryScope) {
        final c = await _repo.category(s.slug, refresh: refresh);
        return (notFound: false, category: c, brand: null);
      }
      if (s is BrandScope) {
        final b = await _repo.brand(s.slug, refresh: refresh);
        return (notFound: false, category: null, brand: b);
      }
    } on ApiError catch (e) {
      if (e.status == 404) return (notFound: true, category: null, brand: null);
    } on Object {
      // A missing header only loses the title/chips; the list still works.
    }
    return (notFound: false, category: null, brand: null);
  }
}
