import 'package:flutter/foundation.dart';
import 'package:cpf_mobile/config/api_config.dart';
import 'package:cpf_mobile/models/auth_profile.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/auth_service.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';

/// Coordinates authentication state, persisted Bearer token restoration, and
/// profile refreshes across the app.
class AuthController extends ChangeNotifier {
  AuthController({
    required this.apiConfig,
    required this.storage,
    required this.apiClient,
    required this.authService,
  });

  final ApiConfig apiConfig;
  final SecureStorageService storage;
  final ApiClient apiClient;
  final AuthService authService;

  AuthProfile? _profile;
  bool _isInitializing = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _sessionExpiredNotice;

  AuthProfile? get profile => _profile;
  bool get isAuthenticated => _profile != null;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get sessionExpiredNotice => _sessionExpiredNotice;

  /// Loads saved Server URL and attempts to restore an existing Bearer session.
  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();

    try {
      await apiConfig.loadFromStorage(storage);
      final token = await storage.readToken();
      if (token != null && token.isNotEmpty) {
        apiClient.setCachedToken(token);
        _profile = await authService.fetchMe();
        _errorMessage = null;
        _sessionExpiredNotice = null;
      }
    } on ApiException catch (e) {
      _profile = null;
      if (e.statusCode == 401) {
        apiClient.setCachedToken(null);
        await storage.deleteToken();
        _sessionExpiredNotice =
            'Your previous session expired. Please sign in again.';
      } else {
        _errorMessage = e.message;
      }
    } catch (_) {
      _profile = null;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Signs in with email and password (`POST /api/v1/auth/login`).
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _sessionExpiredNotice = null;
    notifyListeners();

    try {
      final result = await authService.loginWithEmail(
        email: email,
        password: password,
      );
      await _persistSession(result);
      return true;
    } catch (error) {
      _errorMessage = extractErrorMessage(
        error,
        currentBaseUrl: apiConfig.baseUrl,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Atomically claims a 12-character passkey (`POST /api/v1/auth/passkey-code`).
  Future<bool> signInWithPasskey({
    required String email,
    required String passkeyCode,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _sessionExpiredNotice = null;
    notifyListeners();

    try {
      final result = await authService.loginWithPasskey(
        email: email,
        passkeyCode: passkeyCode,
      );
      await _persistSession(result);
      return true;
    } catch (error) {
      _errorMessage = extractErrorMessage(
        error,
        currentBaseUrl: apiConfig.baseUrl,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes the authenticated profile and daily quote via `GET /api/v1/auth/me`.
  Future<String?> refreshProfile() async {
    try {
      final fresh = await authService.fetchMe();
      _profile = fresh;
      _errorMessage = null;
      notifyListeners();
      return null;
    } catch (error) {
      return extractErrorMessage(error, currentBaseUrl: apiConfig.baseUrl);
    }
  }

  /// Revokes the current Sanctum token and clears local storage.
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await authService.logout();
    } catch (_) {
      // Best-effort server revocation; always clear local credentials.
    } finally {
      apiClient.setCachedToken(null);
      await storage.deleteToken();
      _profile = null;
      _errorMessage = null;
      _sessionExpiredNotice = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called when an authenticated request receives HTTP 401.
  void handleUnauthorized() {
    if (_profile == null && _isInitializing) return;
    _profile = null;
    _sessionExpiredNotice = 'Your session expired or was revoked. Sign in again.';
    notifyListeners();
  }

  void clearMessages() {
    if (_errorMessage == null && _sessionExpiredNotice == null) return;
    _errorMessage = null;
    _sessionExpiredNotice = null;
    notifyListeners();
  }

  Future<void> _persistSession(LoginResponse result) async {
    if (result.token.trim().isEmpty) {
      throw const ApiException(
        message: 'Authentication token was missing from the server response.',
      );
    }
    apiClient.setCachedToken(result.token);
    await storage.writeToken(result.token);
    _profile = result.profile;
    _errorMessage = null;
    _sessionExpiredNotice = null;
  }
}
