import 'package:dio/dio.dart';
import 'package:lamsa_app/core/network/api_call.dart';
import 'package:lamsa_app/core/network/auth_interceptor.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';

/// `GET /governorates` (public) and the signed-in user's `/users/me/addresses`.
class AddressesApi {
  AddressesApi(this._dio);

  final Dio _dio;

  static final _public = Options(extra: {AuthExtra.noAuth: true});

  /// The fixed list of the 14 governorates.
  Future<List<Governorate>> governorates() async {
    final r = await sendJson(_dio, 'GET', '/governorates', options: _public);
    return [
      for (final e in r.data! as List<dynamic>)
        Governorate.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// The user's addresses (at most 10), default first.
  Future<List<Address>> list() async {
    final r = await sendJson(_dio, 'GET', '/users/me/addresses');
    return [
      for (final e in r.data! as List<dynamic>)
        Address.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// `is_default` is only sent when asked for (the first address is always
  /// the default).
  Future<Address> create(AddressDraft draft) async => Address.fromJson(
        (await sendJson(
          _dio,
          'POST',
          '/users/me/addresses',
          data: draft.toBody(includeDefault: true),
        ))
            .map,
      );

  /// A full update (every field, blanks clear). `is_default: true` only when
  /// the user asked to make it the default.
  Future<Address> update(int id, AddressDraft draft) async => Address.fromJson(
        (await sendJson(
          _dio,
          'PATCH',
          '/users/me/addresses/$id',
          data: {
            ...draft.toBody(),
            if (draft.isDefault) 'is_default': true,
          },
        ))
            .map,
      );

  /// The backend gives the default to the newest address when the default is
  /// deleted.
  Future<void> delete(int id) async {
    await sendJson(_dio, 'DELETE', '/users/me/addresses/$id');
  }

  Future<Address> setDefault(int id) async => Address.fromJson(
        (await sendJson(_dio, 'POST', '/users/me/addresses/$id/default')).map,
      );
}
