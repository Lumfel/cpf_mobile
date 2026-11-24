import 'package:flutter/foundation.dart';
import 'package:cpf_mobile/config/api_config.dart';
import 'package:cpf_mobile/models/auth_profile.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/auth_service.dart';
import 'package:cpf_mobile/services/local_db_service.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';

/// Coordinates authentication state, SecureStorage Bearer token restoration,
/// and offline SQLite QR/profile fallback (`LocalDbService`).
class AuthController extends ChangeNotifier {
  AuthController({
    required this.apiConfig,
    required this.storage,
    required this.apiClient,
    required this.authService,
    LocalDbService? localDb,
  }) : localDb = localDb ?? LocalDbService();

  final ApiConfig apiConfig;
  final SecureStorageService storage;
  final ApiClient apiClient;
  final AuthService authService;
  final LocalDbService localDb;

  AuthProfile? _profile;
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _isOfflineCached = false;
  String? _errorMessage;
  String? _sessionExpiredNotice;

  AuthProfile? get profile => _profile;
  bool get isAuthenticated => _profile != null;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  bool get isOfflineCached => _isOfflineCached;
  String? get errorMessage => _errorMessage;
  String? get sessionExpiredNotice => _sessionExpiredNotice;

  /// Loads saved Server URL, restores cached SQLite profile immediately for
  /// offline QR availability, and refreshes from `/api/v1/auth/me` when online.
  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();

    AuthProfile? cachedProfile;
    try {
      await apiConfig.loadFromStorage(storage);
      final token = await storage.readToken();
      if (token != null && token.isNotEmpty) {
        apiClient.setCachedToken(token);
        cachedProfile = await localDb.readCachedProfile();
        if (cachedProfile != null) {
          _profile = cachedProfile;
          _isOfflineCached = true;
        }

        final fresh = await authService.fetchMe();
        _profile = fresh;
        _isOfflineCached = false;
        _errorMessage = null;
        _sessionExpiredNotice = null;
        await localDb.cacheProfile(fresh);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        apiClient.setCachedToken(null);
        await storage.deleteToken();
        await localDb.clearCachedProfile();
        _profile = null;
        _isOfflineCached = false;
        _sessionExpiredNotice =
            'Your previous session expired. Please sign in again.';
      } else if (cachedProfile != null) {
        // Keep SQLite cached profile & QR Pass available while offline!
        _profile = cachedProfile;
        _isOfflineCached = true;
        _errorMessage = null;
      } else {
        _profile = null;
        _errorMessage = e.message;
      }
    } catch (_) {
      if (cachedProfile != null) {
        _profile = cachedProfile;
        _isOfflineCached = true;
      } else {
        _profile = null;
      }
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

  /// Refreshes the authenticated profile via `GET /api/v1/auth/me` and updates
  /// the offline SQLite cache.
  Future<String?> refreshProfile() async {
    try {
      final fresh = await authService.fetchMe();
      _profile = fresh;
      _isOfflineCached = false;
      _errorMessage = null;
      await localDb.cacheProfile(fresh);
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      if (error.statusCode != 401 && _profile != null) {
        _isOfflineCached = true;
        notifyListeners();
      }
      return error.message;
    } catch (error) {
      if (_profile != null) {
        _isOfflineCached = true;
        notifyListeners();
      }
      return extractErrorMessage(error, currentBaseUrl: apiConfig.baseUrl);
    }
  }

  /// Revokes the current Sanctum token and clears both SecureStorage & SQLite.
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
      await localDb.clearCachedProfile();
      _profile = null;
      _isOfflineCached = false;
      _errorMessage = null;
      _sessionExpiredNotice = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called when an authenticated request receives HTTP 401.
  void handleUnauthorized() {
    if (_profile == null && _isInitializing) return;
    localDb.clearCachedProfile();
    _profile = null;
    _isOfflineCached = false;
    _sessionExpiredNotice =
        'Your session expired or was revoked. Sign in again.';
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
    await localDb.cacheProfile(result.profile);
    _profile = result.profile;
    _isOfflineCached = false;
    _errorMessage = null;
    _sessionExpiredNotice = null;
  }
}
