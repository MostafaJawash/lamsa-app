import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/catalog/cubit/load_status.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

/// Categories tab: top-level categories with a cover image.
final class CategoriesCubit extends Cubit<Section<List<CategoryTile>>> {
  CategoriesCubit(this._repo) : super(const Section.loading());

  final CatalogRepository _repo;

  Future<void> load({bool refresh = false}) async {
    if (!refresh) emit(const Section.loading());
    try {
      emit(Section.loaded(await _repo.categoryTiles(refresh: refresh)));
    } on Object catch (e) {
      emit(Section.failed(messageOf(e)));
    }
  }
}

/// Brands screen.
final class BrandsCubit extends Cubit<Section<List<Brand>>> {
  BrandsCubit(this._repo) : super(const Section.loading());

  final CatalogRepository _repo;

  Future<void> load({bool refresh = false}) async {
    if (!refresh) emit(const Section.loading());
    try {
      emit(Section.loaded(await _repo.brands(refresh: refresh)));
    } on Object catch (e) {
      emit(Section.failed(messageOf(e)));
    }
  }
}
