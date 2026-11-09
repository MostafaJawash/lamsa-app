import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/catalog/data/catalog_api.dart';

enum ServerStatus { checking, reachable, unreachable }

final class HomeState extends Equatable {
  const HomeState(this.status, [this.errorMessage]);

  final ServerStatus status;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, errorMessage];
}

/// Cubit: a single linear "check" action, no event semantics needed.
final class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._api) : super(const HomeState(ServerStatus.checking));

  final CatalogApi _api;

  Future<void> check() async {
    emit(const HomeState(ServerStatus.checking));
    try {
      await _api.ping();
      emit(const HomeState(ServerStatus.reachable));
    } on Object catch (e) {
      emit(HomeState(ServerStatus.unreachable, messageOf(e)));
    }
  }
}
