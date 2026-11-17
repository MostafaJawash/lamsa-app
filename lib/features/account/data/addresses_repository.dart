import 'package:lamsa_app/features/account/data/addresses_api.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';

/// Addresses and the (fixed) governorate list. The governorates never change
/// within a session, so they are fetched once and kept; addresses are always
/// read fresh.
class AddressesRepository {
  AddressesRepository(this._api);

  final AddressesApi _api;

  List<Governorate>? _governorates;
  Future<List<Governorate>>? _inflight;

  /// The 14 governorates (cached for the session; a failure is not cached).
  Future<List<Governorate>> governorates() {
    final known = _governorates;
    if (known != null) return Future.value(known);
    return _inflight ??= _api.governorates().then((list) {
      _governorates = list;
      return list;
    }).whenComplete(() => _inflight = null);
  }

  Future<List<Address>> list() => _api.list();

  Future<Address> create(AddressDraft draft) => _api.create(draft);

  Future<Address> update(int id, AddressDraft draft) => _api.update(id, draft);

  Future<void> delete(int id) => _api.delete(id);

  Future<Address> setDefault(int id) => _api.setDefault(id);

  /// Forgets nothing user-specific is kept, but sign-out clears for safety.
  void clear() {
    _governorates = null;
  }
}
