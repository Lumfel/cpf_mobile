import 'package:flutter/foundation.dart';
import 'package:cpf_mobile/services/secure_storage_service.dart';

/// Default server root URL for Flutter Web (`http://127.0.0.1:8000`).
const String defaultWebBaseUrl = 'http://127.0.0.1:8000';

/// Default server root URL for Android Emulator (`http://10.0.2.2:8000`).
const String defaultAndroidBaseUrl = 'http://10.0.2.2:8000';

/// Platform-aware default server root URL when no custom URL is saved.
const String defaultBaseUrl =
    kIsWeb ? defaultWebBaseUrl : defaultAndroidBaseUrl;

/// Runtime-configurable server URL holder for demo and environment switching.
class ApiConfig extends ChangeNotifier {
  ApiConfig({String? initialBaseUrl})
      : _baseUrl = normalizeBaseUrl(initialBaseUrl ?? defaultBaseUrl);

  String _baseUrl;

  /// Normalized server root URL without trailing slash or `/api/v1`.
  String get baseUrl => _baseUrl;

  /// Origin root URL (alias of [baseUrl]).
  String get originUrl => _baseUrl;

  /// REST API v1 base URL (`<baseUrl>/api/v1`).
  String get apiBaseUrl => '$_baseUrl/api/v1';

  /// Public Android APK download URL (`<baseUrl>/download/android`).
  String get androidDownloadUrl => '$_baseUrl/download/android';

  /// Whether the current URL differs from [defaultBaseUrl].
  bool get isCustom => _baseUrl != normalizeBaseUrl(defaultBaseUrl);

  /// Normalizes user-entered URLs by trimming whitespace, stripping trailing
  /// slashes, and removing a trailing `/api/v1` or `/api` suffix if provided.
  static String normalizeBaseUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    final lower = value.toLowerCase();
    if (lower.endsWith('/api/v1')) {
      value = value.substring(0, value.length - '/api/v1'.length);
    } else if (lower.endsWith('/api')) {
      value = value.substring(0, value.length - '/api'.length);
    }

    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    return value;
  }

  /// Validates that [raw] is a valid `http://` or `https://` URL with a host.
  static bool isValidUrl(String raw) {
    final normalized = normalizeBaseUrl(raw);
    if (normalized.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return false;
    }
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
  }

  /// Loads any persisted custom server URL from secure storage, normalizing
  /// whitespace and trailing slashes, or falling back to [defaultBaseUrl].
  Future<void> loadFromStorage(SecureStorageService storage) async {
    final stored = await storage.readServerUrl();
    final target = (stored != null && isValidUrl(stored))
        ? normalizeBaseUrl(stored)
        : normalizeBaseUrl(defaultBaseUrl);
    if (target != _baseUrl) {
      _baseUrl = target;
      notifyListeners();
    }
  }

  /// Validates, normalizes, persists, and applies a new server URL.
  Future<void> updateBaseUrl(String raw, SecureStorageService storage) async {
    if (!isValidUrl(raw)) {
      throw const FormatException(
        'Enter a valid http:// or https:// server URL.',
      );
    }
    final normalized = normalizeBaseUrl(raw);
    await storage.writeServerUrl(normalized);
    if (normalized != _baseUrl) {
      _baseUrl = normalized;
      notifyListeners();
    }
  }

  /// Clears any stored override and reverts to [defaultBaseUrl].
  Future<void> resetToDefault(SecureStorageService storage) async {
    await storage.deleteServerUrl();
    final fallback = normalizeBaseUrl(defaultBaseUrl);
    if (fallback != _baseUrl) {
      _baseUrl = fallback;
      notifyListeners();
    }
  }
}
