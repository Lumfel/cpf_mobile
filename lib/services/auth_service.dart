import 'package:cpf_mobile/models/auth_profile.dart';
import 'package:cpf_mobile/services/api_client.dart';

/// REST API v1 authentication endpoints.
class AuthService {
  const AuthService(this._client);

  final ApiClient _client;

  static const String _deviceName = 'Android (cpf_mobile)';

  /// `POST /api/v1/auth/login`
  Future<LoginResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post<dynamic>(
        '/auth/login',
        data: <String, dynamic>{
          'email': email.trim(),
          'password': password,
          'device_name': _deviceName,
        },
      );
      return LoginResponse.fromJson(_client.expectJsonMap(response.data));
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `POST /api/v1/auth/passkey-code`
  Future<LoginResponse> loginWithPasskey({
    required String email,
    required String passkeyCode,
  }) async {
    try {
      final response = await _client.dio.post<dynamic>(
        '/auth/passkey-code',
        data: <String, dynamic>{
          'email': email.trim(),
          'passkey_code': passkeyCode.trim().toUpperCase(),
          'device_name': _deviceName,
        },
      );
      return LoginResponse.fromJson(_client.expectJsonMap(response.data));
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `GET /api/v1/auth/me`
  Future<AuthProfile> fetchMe() async {
    try {
      final response = await _client.dio.get<dynamic>('/auth/me');
      return AuthProfile.fromJson(_client.expectJsonMap(response.data));
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `POST /api/v1/auth/logout`
  Future<void> logout() async {
    try {
      await _client.dio.post<dynamic>('/auth/logout');
    } catch (error) {
      throw _client.toApiException(error);
    }
  }
}
