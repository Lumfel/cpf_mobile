import 'package:cpf_mobile/models/auth_profile.dart';
import 'package:cpf_mobile/services/api_client.dart';

/// Result returned by `POST /api/v1/auth/password/force-change`.
class ForcePasswordChangeResult {
  const ForcePasswordChangeResult({
    this.profile,
    this.token,
  });

  final AuthProfile? profile;
  final String? token;
}

/// REST API v1 authentication endpoints.
class AuthService {
  const AuthService(this._client);

  final ApiClient _client;

  static const String _deviceName = 'Android (cpf_mobile)';

  /// `POST /api/v1/auth/login`
  ///
  /// Supports optional 2FA authenticator [code] or [recoveryCode] when the
  /// server responds with HTTP 422 `two_factor_required: true`.
  Future<LoginResponse> loginWithEmail({
    required String email,
    required String password,
    String? code,
    String? recoveryCode,
  }) async {
    final cleanCode = code?.trim();
    final cleanRecovery = recoveryCode?.trim();
    try {
      final response = await _client.dio.post<dynamic>(
        '/auth/login',
        data: <String, dynamic>{
          'email': email.trim(),
          'password': password,
          'device_name': _deviceName,
          if (cleanCode != null && cleanCode.isNotEmpty) 'code': cleanCode,
          if (cleanRecovery != null && cleanRecovery.isNotEmpty)
            'recovery_code': cleanRecovery,
        },
      );
      return LoginResponse.fromJson(_client.expectJsonMap(response.data));
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `POST /api/v1/auth/passkey-code`
  ///
  /// Supports optional 2FA authenticator [code] or [recoveryCode] when the
  /// server responds with HTTP 422 `two_factor_required: true`.
  Future<LoginResponse> loginWithPasskey({
    required String email,
    required String passkeyCode,
    String? code,
    String? recoveryCode,
  }) async {
    final cleanCode = code?.trim();
    final cleanRecovery = recoveryCode?.trim();
    try {
      final response = await _client.dio.post<dynamic>(
        '/auth/passkey-code',
        data: <String, dynamic>{
          'email': email.trim(),
          'passkey_code': passkeyCode.trim().toUpperCase(),
          'device_name': _deviceName,
          if (cleanCode != null && cleanCode.isNotEmpty) 'code': cleanCode,
          if (cleanRecovery != null && cleanRecovery.isNotEmpty)
            'recovery_code': cleanRecovery,
        },
      );
      return LoginResponse.fromJson(_client.expectJsonMap(response.data));
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  /// `POST /api/v1/auth/password/force-change`
  ///
  /// Replaces a temporary or passkey-issued password using the active Sanctum
  /// Bearer token. Returns an updated [AuthProfile] when included in the
  /// response payload (and an optional rotated Bearer token if issued).
  Future<ForcePasswordChangeResult> forceChangePassword({
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _client.dio.post<dynamic>(
        '/auth/password/force-change',
        data: <String, dynamic>{
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
      final map = _client.expectJsonMap(response.data);
      final rotatedToken = (map['token'] as String?)?.trim();

      AuthProfile? profile;
      if (map['user'] is Map) {
        profile = AuthProfile.fromJson(map);
      } else if (map['profile'] is Map) {
        profile = AuthProfile.fromJson(
          Map<String, dynamic>.from(map['profile'] as Map),
        );
      }

      return ForcePasswordChangeResult(
        profile: profile,
        token: (rotatedToken != null && rotatedToken.isNotEmpty)
            ? rotatedToken
            : null,
      );
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
