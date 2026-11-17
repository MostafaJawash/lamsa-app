import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/account/data/address_rules.dart';
import 'package:lamsa_app/features/account/data/addresses_repository.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';

enum AddressesLoad { loading, ready, failed }

final class AddressesState extends Equatable {
  const AddressesState({
    this.status = AddressesLoad.loading,
    this.addresses = const [],
    this.governorates = const [],
    this.governoratesFailed = false,
    this.error,
  });

  final AddressesLoad status;
  final List<Address> addresses;
  final List<Governorate> governorates;

  /// The list of governorates could not be loaded: adding is unavailable.
  final bool governoratesFailed;
  final String? error;

  AddressesState copyWith({
    AddressesLoad? status,
    List<Address>? addresses,
    List<Governorate>? governorates,
    bool? governoratesFailed,
    String? error,
  }) =>
      AddressesState(
        status: status ?? this.status,
        addresses: addresses ?? this.addresses,
        governorates: governorates ?? this.governorates,
        governoratesFailed: governoratesFailed ?? this.governoratesFailed,
        error: error,
      );

  @override
  List<Object?> get props =>
      [status, addresses, governorates, governoratesFailed, error];
}

/// The address book (Account > Addresses): list, delete, set default. Adding
/// and editing go through [AddressFormCubit]; the list reloads afterwards.
final class AddressesCubit extends Cubit<AddressesState> {
  AddressesCubit(this._repo) : super(const AddressesState());

  final AddressesRepository _repo;

  Future<void> load({bool refresh = false}) async {
    if (!refresh || state.status != AddressesLoad.ready) {
      emit(state.copyWith(status: AddressesLoad.loading));
    }
    try {
      final results = await Future.wait([
        _repo.list(),
        _repo.governorates().then<List<Governorate>?>((g) => g).onError<Object>((_, _) => null),
      ]);
      final govs = results[1] as List<Governorate>?;
      if (isClosed) return;
      emit(
        AddressesState(
          status: AddressesLoad.ready,
          addresses: results[0]! as List<Address>,
          governorates: govs ?? state.governorates,
          governoratesFailed: govs == null && state.governorates.isEmpty,
        ),
      );
    } on Object catch (e) {
      if (!isClosed) {
        emit(state.copyWith(status: AddressesLoad.failed, error: messageOf(e)));
      }
    }
  }

  /// Deletes an address. Returns the backend's message on failure. The
  /// backend gives the default to the newest address when the default goes.
  Future<String?> delete(int id) => _run(() => _repo.delete(id));

  Future<String?> setDefault(int id) => _run(() => _repo.setDefault(id));

  Future<String?> _run(Future<Object?> Function() action) async {
    try {
      await action();
      await load(refresh: true);
      return null;
    } on Object catch (e) {
      await load(refresh: true);
      return messageOf(e);
    }
  }
}

final class AddressFormState extends Equatable {
  const AddressFormState({
    this.submitting = false,
    this.errors = const {},
    this.saved,
  });

  final bool submitting;
  final AddressErrors errors;

  /// Set once the address was saved.
  final Address? saved;

  @override
  List<Object?> get props => [submitting, errors, saved];
}

/// Creates or edits one address: validates with the web's limits first, then
/// lets the backend decide (its Arabic message wins for anything it rejects).
final class AddressFormCubit extends Cubit<AddressFormState> {
  AddressFormCubit(this._repo, {required this.governorateCodes, this.editing})
      : super(const AddressFormState());

  final AddressesRepository _repo;
  final List<String> governorateCodes;

  /// The address being edited; null when creating.
  final Address? editing;

  void clearError(AddressField field) {
    if (!state.errors.containsKey(field)) return;
    emit(AddressFormState(errors: {...state.errors}..remove(field)));
  }

  Future<void> save(AddressDraft draft) async {
    if (state.submitting) return;
    final errors = validateAddress(
      draft,
      governorateCodes: governorateCodes.isEmpty ? null : governorateCodes,
    );
    if (errors.isNotEmpty) {
      emit(AddressFormState(errors: errors));
      return;
    }
    emit(const AddressFormState(submitting: true));
    try {
      final saved = editing == null
          ? await _repo.create(draft)
          : await _repo.update(editing!.id, draft);
      if (!isClosed) emit(AddressFormState(saved: saved));
    } on Object catch (e) {
      if (!isClosed) emit(AddressFormState(errors: mapAddressError(e)));
    }
  }
}
