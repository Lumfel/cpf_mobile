import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cpf_mobile/config/api_config.dart';
import 'package:cpf_mobile/models/auth_profile.dart';
import 'package:cpf_mobile/services/api_client.dart';
import 'package:cpf_mobile/services/auth_service.dart';
import 'package:cpf_mobile/services/local_db_service.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';

/// Authentication method awaiting a two-factor verification code.
enum TwoFactorLoginMethod { emailPassword, passkeyCode }

/// RAM-only state for an in-flight sign-in paused by HTTP 422
/// `two_factor_required: true`. Never persisted to storage or logged.
class PendingTwoFactorChallenge {
  const PendingTwoFactorChallenge({
    required this.method,
    required this.email,
    required this.secret,
    this.message,
  });

  final TwoFactorLoginMethod method;
  final String email;
  final String secret;
  final String? message;
}

/// Coordinates authentication state, SecureStorage Bearer token restoration,
/// 2FA challenge retries, in-app forced password changes, and offline SQLite
/// QR/profile fallback (`LocalDbService`).
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
  bool _passwordChangeRequired = false;
  PendingTwoFactorChallenge? _pendingTwoFactor;
  String? _errorMessage;
  String? _sessionExpiredNotice;

  AuthProfile? get profile => _profile;
  bool get isAuthenticated => _profile != null;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  bool get isOfflineCached => _isOfflineCached;
  bool get requiresPasswordChange =>
      _passwordChangeRequired || (_profile?.user.mustChangePassword ?? false);
  PendingTwoFactorChallenge? get pendingTwoFactor => _pendingTwoFactor;
  bool get isTwoFactorRequired => _pendingTwoFactor != null;
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
        _passwordChangeRequired = fresh.user.mustChangePassword;
        _errorMessage = null;
        _sessionExpiredNotice = null;
        await localDb.cacheProfile(fresh);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        apiClient.setCachedToken(null);
        await storage.deleteToken();
        await storage.clearAllEventChecklists();
        await localDb.clearCachedProfile();
        _profile = null;
        _isOfflineCached = false;
        _passwordChangeRequired = false;
        _sessionExpiredNotice =
            'Your previous session expired. Please sign in again.';
      } else if (cachedProfile != null) {
        // Keep SQLite cached profile & QR Pass available while offline!
        _profile = cachedProfile;
        _isOfflineCached = true;
        _errorMessage = null;
      } else {
        _profile = null;
        _errorMessage = localDb.lastReadWasStale
            ? 'Your offline Peer QR cache expired after 7 days. Reconnect to refresh your session.'
            : e.message;
      }
    } catch (_) {
      if (cachedProfile != null) {
        _profile = cachedProfile;
        _isOfflineCached = true;
      } else {
        _profile = null;
        if (localDb.lastReadWasStale) {
          _sessionExpiredNotice =
              'Your offline Peer QR cache expired after 7 days. Reconnect and sign in again.';
        }
      }
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Signs in with email and password (`POST /api/v1/auth/login`), supporting
  /// an optional 2FA authenticator [code] or [recoveryCode].
  Future<bool> signInWithEmail({
    required String email,
    required String password,
    String? code,
    String? recoveryCode,
  }) async {
    final isTwoFactorRetry = (code != null && code.trim().isNotEmpty) ||
        (recoveryCode != null && recoveryCode.trim().isNotEmpty);

    _isLoading = true;
    _errorMessage = null;
    _sessionExpiredNotice = null;
    if (!isTwoFactorRetry) {
      _pendingTwoFactor = null;
    }
    notifyListeners();

    try {
      final result = await authService.loginWithEmail(
        email: email,
        password: password,
        code: code,
        recoveryCode: recoveryCode,
      );
      await _persistSession(result);
      return true;
    } on ApiException catch (error) {
      if (error.twoFactorRequired) {
        _pendingTwoFactor = PendingTwoFactorChallenge(
          method: TwoFactorLoginMethod.emailPassword,
          email: email.trim(),
          secret: password,
          message: error.message,
        );
        _errorMessage = isTwoFactorRetry ? error.message : null;
      } else {
        if (!isTwoFactorRetry) {
          _pendingTwoFactor = null;
        }
        _errorMessage = error.message;
      }
      return false;
    } catch (error) {
      if (!isTwoFactorRetry) {
        _pendingTwoFactor = null;
      }
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

  /// Atomically claims a 12-character passkey (`POST /api/v1/auth/passkey-code`),
  /// supporting an optional 2FA authenticator [code] or [recoveryCode].
  Future<bool> signInWithPasskey({
    required String email,
    required String passkeyCode,
    String? code,
    String? recoveryCode,
  }) async {
    final isTwoFactorRetry = (code != null && code.trim().isNotEmpty) ||
        (recoveryCode != null && recoveryCode.trim().isNotEmpty);

    _isLoading = true;
    _errorMessage = null;
    _sessionExpiredNotice = null;
    if (!isTwoFactorRetry) {
      _pendingTwoFactor = null;
    }
    notifyListeners();

    try {
      final result = await authService.loginWithPasskey(
        email: email,
        passkeyCode: passkeyCode,
        code: code,
        recoveryCode: recoveryCode,
      );
      await _persistSession(result);
      return true;
    } on ApiException catch (error) {
      if (error.twoFactorRequired) {
        _pendingTwoFactor = PendingTwoFactorChallenge(
          method: TwoFactorLoginMethod.passkeyCode,
          email: email.trim(),
          secret: passkeyCode,
          message: error.message,
        );
        _errorMessage = isTwoFactorRetry ? error.message : null;
      } else {
        if (!isTwoFactorRetry) {
          _pendingTwoFactor = null;
        }
        _errorMessage = error.message;
      }
      return false;
    } catch (error) {
      if (!isTwoFactorRetry) {
        _pendingTwoFactor = null;
      }
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

  /// Retries the pending login or passkey-claim request with the supplied
  /// 6-digit authenticator [code] or [recoveryCode].
  Future<bool> submitTwoFactorChallenge({
    String? code,
    String? recoveryCode,
  }) async {
    final challenge = _pendingTwoFactor;
    if (challenge == null) return false;

    final cleanCode = code?.trim();
    final cleanRecovery = recoveryCode?.trim();
    if ((cleanCode == null || cleanCode.isEmpty) &&
        (cleanRecovery == null || cleanRecovery.isEmpty)) {
      _errorMessage = 'Enter your 6-digit authenticator code or a recovery code.';
      notifyListeners();
      return false;
    }

    return switch (challenge.method) {
      TwoFactorLoginMethod.emailPassword => signInWithEmail(
          email: challenge.email,
          password: challenge.secret,
          code: cleanCode,
          recoveryCode: cleanRecovery,
        ),
      TwoFactorLoginMethod.passkeyCode => signInWithPasskey(
          email: challenge.email,
          passkeyCode: challenge.secret,
          code: cleanCode,
          recoveryCode: cleanRecovery,
        ),
    };
  }

  /// Cancels an active 2FA challenge and clears any RAM-only login credentials.
  void cancelTwoFactorChallenge() {
    if (_pendingTwoFactor == null && _errorMessage == null) return;
    _pendingTwoFactor = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Completes the forced password change in-app via
  /// `POST /api/v1/auth/password/force-change`, refreshes and caches the
  /// unlocked [AuthProfile] in [LocalDbService], and returns `null` on success
  /// or an error message on failure.
  Future<String?> forceChangePassword({
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final result = await authService.forceChangePassword(
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      if (result.token != null && result.token!.isNotEmpty) {
        apiClient.setCachedToken(result.token);
        await storage.writeToken(result.token!);
      }

      final updatedProfile = result.profile ?? await authService.fetchMe();
      _profile = updatedProfile;
      _isOfflineCached = false;
      _passwordChangeRequired = updatedProfile.user.mustChangePassword;
      _errorMessage = null;
      await localDb.cacheProfile(updatedProfile);
      notifyListeners();
      return null;
    } catch (error) {
      return extractErrorMessage(error, currentBaseUrl: apiConfig.baseUrl);
    }
  }

  /// Refreshes the authenticated profile via `GET /api/v1/auth/me` and updates
  /// the offline SQLite cache.
  Future<String?> refreshProfile() async {
    try {
      final fresh = await authService.fetchMe();
      _profile = fresh;
      _isOfflineCached = false;
      _passwordChangeRequired = fresh.user.mustChangePassword;
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

  /// Silently refreshes `GET /api/v1/auth/me` in the background (for example
  /// when a campus election completes) so newly elected officers receive their
  /// updated `verified_role`, permissions, and signed QR pass immediately.
  Future<void> refreshProfileSilently() async {
    if (_profile == null) return;
    try {
      final fresh = await authService.fetchMe();
      _profile = fresh;
      _isOfflineCached = false;
      _passwordChangeRequired = fresh.user.mustChangePassword;
      await localDb.cacheProfile(fresh);
      notifyListeners();
    } catch (_) {
      // Silent background refresh — preserve current session state on transient errors.
    }
  }

  /// Revokes the current Sanctum token and clears SecureStorage tokens,
  /// per-event attendance checklists (`cpf_event_checklist_*`), and SQLite.
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
      await storage.clearAllEventChecklists();
      await localDb.clearCachedProfile();
      _profile = null;
      _isOfflineCached = false;
      _passwordChangeRequired = false;
      _pendingTwoFactor = null;
      _errorMessage = null;
      _sessionExpiredNotice = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called when an authenticated request receives HTTP 401.
  void handleUnauthorized() {
    apiClient.setCachedToken(null);
    unawaited(storage.clearAllEventChecklists());
    unawaited(localDb.clearCachedProfile());
    if (_profile == null && _isInitializing) return;
    _profile = null;
    _isOfflineCached = false;
    _passwordChangeRequired = false;
    _pendingTwoFactor = null;
    _sessionExpiredNotice =
        'Your session expired or was revoked. Sign in again.';
    notifyListeners();
  }

  /// Called when any protected API returns HTTP 403 `must_change_password_required`.
  void markPasswordChangeRequired() {
    if (_passwordChangeRequired) return;
    _passwordChangeRequired = true;
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
    await storage.clearAllEventChecklists();
    await storage.writeToken(result.token);
    await localDb.cacheProfile(result.profile);
    _profile = result.profile;
    _isOfflineCached = false;
    _passwordChangeRequired = result.profile.user.mustChangePassword;
    _pendingTwoFactor = null;
    _errorMessage = null;
    _sessionExpiredNotice = null;
  }
}
