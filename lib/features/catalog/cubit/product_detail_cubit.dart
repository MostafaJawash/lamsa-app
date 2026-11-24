import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/catalog/cubit/load_status.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/data/variants.dart';

final class ProductDetailState extends Equatable {
  const ProductDetailState({
    this.status = LoadStatus.loading,
    this.product,
    this.selectedVariantId,
    this.related = const Section.loading(),
    this.notFound = false,
    this.error,
    this.connection = false,
  });

  final LoadStatus status;
  final ProductDetail? product;
  final int? selectedVariantId;
  final Section<List<ProductCard>> related;
  final bool notFound;
  final String? error;
  final bool connection;

  Variant? get variant =>
      product == null ? null : findVariant(product!, selectedVariantId);

  @override
  List<Object?> get props =>
      [status, product, selectedVariantId, related, notFound, error, connection];
}

/// Product screen: the detail, the selected variant (all client-side, no
/// refetch when the shopper switches options) and the related rail.
final class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductDetailCubit(this._repo, this.slug) : super(const ProductDetailState());

  final CatalogRepository _repo;
  final String slug;

  Future<void> load({bool refresh = false}) async {
    if (!refresh || state.product == null) {
      emit(const ProductDetailState());
    }
    final related = _repo
        .related(slug, refresh: refresh)
        .then<Section<List<ProductCard>>>(Section.loaded)
        .onError<Object>((e, _) => Section.failed(messageOf(e)));
    try {
      final product = await _repo.product(slug, refresh: refresh);
      if (isClosed) return;
      final keep = state.selectedVariantId;
      emit(
        ProductDetailState(
          status: LoadStatus.loaded,
          product: product,
          selectedVariantId:
              findVariant(product, keep) != null ? keep : defaultVariantId(product),
        ),
      );
    } on Object catch (e) {
      if (isClosed) return;
      emit(
        ProductDetailState(
          status: LoadStatus.failed,
          notFound: e is ApiError && e.status == 404,
          error: messageOf(e),
          connection: isConnectionFailure(e),
        ),
      );
      return;
    }
    final r = await related;
    if (!isClosed) {
      emit(
        ProductDetailState(
          status: state.status,
          product: state.product,
          selectedVariantId: state.selectedVariantId,
          related: r,
        ),
      );
    }
  }

  /// The shopper picked [value] for option [key].
  void selectOption(String key, String value) {
    final product = state.product;
    if (product == null) return;
    final picked = pickVariant(product, state.variant, key, value);
    if (picked == null || picked.id == state.selectedVariantId) return;
    emit(
      ProductDetailState(
        status: state.status,
        product: product,
        selectedVariantId: picked.id,
        related: state.related,
      ),
    );
  }
}
