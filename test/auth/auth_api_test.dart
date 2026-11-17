import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/network/auth_interceptor.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';

const _user = {
  'id': 1,
  'name': 'ليلى',
  'phone': '+963933123456',
  'email': null,
  'role': 'customer',
  'auth_provider': 'phone',
  'must_change_password': false,
  'created_at': '2026-10-22T17:00:00',
};

const _pair = {
  'access_token': 'a',
  'refresh_token': 'r',
  'token_type': 'bearer',
  'expires_in': 900,
  'refresh_expires_in': 5184000,
  'user': _user,
};

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, [this.status = 200]);

  final Object body;
  final int status;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AuthApi apiWith(HttpClientAdapter adapter) => AuthApi(
  Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = adapter,
  now: () => DateTime.utc(2026),
);

void main() {
  test(
    'login posts phone + password anonymously and parses the pair',
    () async {
      final adapter = _Adapter(_pair);
      final pair = await apiWith(adapter)
          .login(phone: '+963933123456', password: 'secret123');
      expect(adapter.last!.path, '/auth/login');
      expect(adapter.last!.data, {
        'phone': '+963933123456',
        'password': 'secret123',
      });
      expect(adapter.last!.extra[AuthExtra.noAuth], isTrue);
      expect(pair.user.name, 'ليلى');
      expect(pair.user.mustChangePassword, isFalse);
      expect(pair.refreshExpiresIn, 5184000);
    },
  );

  test(
    'register sends name, phone, password (and device name when given)',
    () async {
      final adapter = _Adapter(_pair, 201);
      await apiWith(adapter).register(
        name: 'ليلى',
        phone: '+963933123456',
        password: 'secret123',
        deviceName: 'Pixel',
      );
      expect(adapter.last!.path, '/auth/register');
      expect(adapter.last!.data, {
        'name': 'ليلى',
        'phone': '+963933123456',
        'password': 'secret123',
        'device_name': 'Pixel',
      });
    },
  );

  test('google returns tokens for a known account', () async {
    final adapter = _Adapter({'registered': true, 'tokens': _pair});
    final r = await apiWith(adapter).loginWithGoogle(idToken: 'tok');
    expect(adapter.last!.path, '/auth/google');
    expect(adapter.last!.data, {'id_token': 'tok'});
    expect(r, isA<GoogleRegistered>());
  });

  test(
    'google returns a signup token + prefilled profile for a new account',
    () async {
      final adapter = _Adapter({
        'registered': false,
        'signup_token': 'signup-1',
        'profile': {'email': 'a@b.c', 'name': 'سارة'},
      });
      final r = await apiWith(adapter).loginWithGoogle(idToken: 'tok');
      expect(r, isA<GoogleNeedsProfile>());
      final need = r as GoogleNeedsProfile;
      expect(need.signupToken, 'signup-1');
      expect(need.name, 'سارة');
      expect(need.email, 'a@b.c');
    },
  );

  test('complete posts the signup token with name and phone', () async {
    final adapter = _Adapter(_pair, 201);
    await apiWith(adapter).completeGoogleSignup(
      signupToken: 's',
      name: 'سارة',
      phone: '+963933123456',
    );
    expect(adapter.last!.path, '/auth/google/complete');
    expect(adapter.last!.data, {
      'signup_token': 's',
      'name': 'سارة',
      'phone': '+963933123456',
    });
  });

  test(
    'change password is authenticated (no noAuth flag) and returns a new pair',
    () async {
      final adapter = _Adapter(_pair);
      final pair = await apiWith(adapter)
          .changePassword(currentPassword: 'temp', newPassword: 'new-secret1');
      expect(adapter.last!.path, '/auth/password/change');
      expect(adapter.last!.data, {
        'current_password': 'temp',
        'new_password': 'new-secret1',
      });
      expect(adapter.last!.extra[AuthExtra.noAuth], isNot(true));
      expect(pair.accessToken, 'a');
    },
  );

  test(
    'logout sends the refresh token; refresh yields storable tokens',
    () async {
      final adapter = _Adapter(_pair);
      final api = apiWith(adapter);
      final stored = await api.refresh('old-refresh');
      expect(adapter.last!.data, {'refresh_token': 'old-refresh'});
      expect(stored.refreshToken, 'r');
      expect(
        stored.accessExpiresAt,
        DateTime.utc(2026).add(const Duration(seconds: 900)),
      );
      await api.logout('r');
      expect(adapter.last!.path, '/auth/logout');
      expect(adapter.last!.data, {'refresh_token': 'r'});
    },
  );

  test('me parses must_change_password', () async {
    final adapter = _Adapter({..._user, 'must_change_password': true});
    final u = await apiWith(adapter).me();
    expect(u.mustChangePassword, isTrue);
  });
}
