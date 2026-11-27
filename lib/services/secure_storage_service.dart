import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cpf_mobile/models/campus_event.dart';

/// Encrypted key-value storage wrapper using `flutter_secure_storage`.
class SecureStorageService {
  const SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _authTokenKey = 'cpf_auth_token';
  static const String _serverUrlKey = 'cpf_server_base_url';
  static const String _themeIdKey = 'cpf_theme_id';
  static const String _checklistPrefix = 'cpf_event_checklist_';

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _authTokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeToken(String token) =>
      _storage.write(key: _authTokenKey, value: token);

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _authTokenKey);
    } catch (_) {
      // Ignore KeyStore cleanup failures on corrupted/reset devices.
    }
  }

  Future<String?> readServerUrl() async {
    try {
      return await _storage.read(key: _serverUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeServerUrl(String url) =>
      _storage.write(key: _serverUrlKey, value: url);

  Future<void> deleteServerUrl() async {
    try {
      await _storage.delete(key: _serverUrlKey);
    } catch (_) {
      // Ignore KeyStore cleanup failures.
    }
  }

  Future<String?> readThemeId() async {
    try {
      return await _storage.read(key: _themeIdKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeThemeId(String themeId) =>
      _storage.write(key: _themeIdKey, value: themeId);

  Future<List<ManualChecklistEntry>> readEventChecklist(int eventId) async {
    try {
      final raw = await _storage.read(key: '$_checklistPrefix$eventId');
      if (raw == null || raw.trim().isEmpty) {
        return const <ManualChecklistEntry>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return const <ManualChecklistEntry>[];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ManualChecklistEntry.fromJson)
          .where((entry) => entry.identifier.isNotEmpty)
          .toList();
    } catch (_) {
      return const <ManualChecklistEntry>[];
    }
  }

  Future<void> writeEventChecklist(
    int eventId,
    List<ManualChecklistEntry> entries,
  ) async {
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _storage.write(key: '$_checklistPrefix$eventId', value: encoded);
  }

  /// Removes all cached per-event attendance checklist entries
  /// (`cpf_event_checklist_*`) so shared devices do not retain attendee data
  /// across sign-out or session revocation.
  Future<void> clearAllEventChecklists() async {
    try {
      final all = await _storage.readAll();
      for (final key in all.keys) {
        if (key.startsWith(_checklistPrefix)) {
          await _storage.delete(key: key);
        }
      }
    } catch (_) {
      // Ignore KeyStore cleanup failures on corrupted/reset devices.
    }
  }
}
