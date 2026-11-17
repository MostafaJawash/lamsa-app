import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/catalog/cubit/load_status.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

final class HomeState extends Equatable {
  const HomeState({
    this.banners = const Section.loading(),
    this.newArrivals = const Section.loading(),
    this.categories = const Section.loading(),
    this.onSale = const Section.loading(),
    this.brands = const Section.loading(),
  });

  final Section<List<HomeBanner>> banners;
  final Section<List<ProductCard>> newArrivals;
  final Section<List<CategoryTile>> categories;
  final Section<List<ProductCard>> onSale;
  final Section<List<Brand>> brands;

  HomeState copyWith({
    Section<List<HomeBanner>>? banners,
    Section<List<ProductCard>>? newArrivals,
    Section<List<CategoryTile>>? categories,
    Section<List<ProductCard>>? onSale,
    Section<List<Brand>>? brands,
  }) =>
      HomeState(
        banners: banners ?? this.banners,
        newArrivals: newArrivals ?? this.newArrivals,
        categories: categories ?? this.categories,
        onSale: onSale ?? this.onSale,
        brands: brands ?? this.brands,
      );

  @override
  List<Object?> get props => [banners, newArrivals, categories, onSale, brands];
}

/// The home screen. Every section loads and fails on its own, so one slow or
/// broken endpoint never blanks the screen.
final class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._repo) : super(const HomeState());

  final CatalogRepository _repo;

  /// Loads every section. With [refresh] (pull-to-refresh) the cache is
  /// skipped and current content stays visible until the new data arrives.
  /// Completes when all sections are done.
  Future<void> load({bool refresh = false}) {
    if (!refresh) emit(const HomeState());
    return Future.wait([
      _run(
        _repo.banners(refresh: refresh),
        (s) => state.copyWith(banners: s),
      ),
      _run(
        _repo
            .products(
              const NewScope(),
              ListFilters.empty,
              pageSize: railSize,
              refresh: refresh,
            )
            .then((r) => r.page.items),
        (s) => state.copyWith(newArrivals: s),
      ),
      _run(
        _repo.categoryTiles(refresh: refresh),
        (s) => state.copyWith(categories: s),
      ),
      _run(
        _repo
            .products(
              const SaleScope(),
              ListFilters.empty,
              pageSize: railSize,
              refresh: refresh,
            )
            .then((r) => r.page.items),
        (s) => state.copyWith(onSale: s),
      ),
      _run(
        _repo.brands(refresh: refresh),
        (s) => state.copyWith(brands: s),
      ),
    ]);
  }

  Future<void> _run<T>(
    Future<T> request,
    HomeState Function(Section<T>) apply,
  ) async {
    try {
      final data = await request;
      if (!isClosed) emit(apply(Section.loaded(data)));
    } on Object catch (e) {
      if (!isClosed) emit(apply(Section.failed(messageOf(e))));
    }
  }
}
