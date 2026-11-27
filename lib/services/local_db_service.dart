import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:cpf_mobile/models/auth_profile.dart';

/// Offline SQLite cache (`sqflite` + `path`) storing the signed-in user's
/// profile, role, campus, and HMAC-signed `qr_payload` so the Peer Dashboard
/// QR Pass opens reliably even without internet connectivity.
///
/// Enforces a 7-day staleness limit ([maxOfflineCacheAge]) on cached offline QR
/// data so expired or demoted credentials are not displayed indefinitely.
///
/// The Sanctum Bearer token is NEVER stored here — it stays encrypted inside
/// `flutter_secure_storage`.
class LocalDbService {
  LocalDbService({
    this.inMemoryOnly = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Maximum age allowed for cached offline Peer QR/profile data.
  static const Duration maxOfflineCacheAge = Duration(days: 7);

  final bool inMemoryOnly;
  final DateTime Function() _clock;

  static const String _dbFileName = 'cpf_mobile_offline.db';
  static const int _dbVersion = 1;
  static const String _tableCachedSession = 'cached_session';

  Database? _db;
  AuthProfile? _memoryFallback;
  DateTime? _memoryFallbackUpdatedAt;
  bool _lastReadWasStale = false;

  /// True when the most recent [readCachedProfile] call discarded a cached
  /// offline QR profile because it exceeded [maxOfflineCacheAge] (7 days).
  bool get lastReadWasStale => _lastReadWasStale;

  bool _isStale(DateTime? updatedAt) {
    if (updatedAt == null) return true;
    return _clock().difference(updatedAt) > maxOfflineCacheAge;
  }

  Future<Database?> _openDb() async {
    if (kIsWeb || inMemoryOnly) {
      return null;
    }
    if (_db != null) {
      return _db;
    }

    try {
      final dbDir = await getDatabasesPath();
      final dbPath = p.join(dbDir, _dbFileName);
      _db = await openDatabase(
        dbPath,
        version: _dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_tableCachedSession (
              slot INTEGER PRIMARY KEY CHECK (slot = 1),
              user_id INTEGER NOT NULL,
              full_name TEXT NOT NULL,
              email TEXT NOT NULL,
              verified_role TEXT,
              verified_role_label TEXT,
              campus_code TEXT,
              campus_name TEXT,
              member_id_code TEXT,
              qr_payload TEXT,
              qr_unlocked INTEGER NOT NULL DEFAULT 0,
              profile_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      );
      return _db;
    } catch (_) {
      // Gracefully fall back to in-memory cache in headless/widget test runners.
      return null;
    }
  }

  /// Saves or overwrites the single active user profile in SQLite.
  Future<void> cacheProfile(
    AuthProfile profile, {
    DateTime? cachedAt,
  }) async {
    final timestamp = cachedAt ?? _clock();
    _memoryFallback = profile;
    _memoryFallbackUpdatedAt = timestamp;
    _lastReadWasStale = false;

    final db = await _openDb();
    if (db == null) return;

    try {
      await db.insert(
        _tableCachedSession,
        <String, Object?>{
          'slot': 1,
          'user_id': profile.user.id,
          'full_name': profile.displayName,
          'email': profile.user.email,
          'verified_role':
              profile.verifiedRole?.apiValue ?? profile.verifiedRoleRaw,
          'verified_role_label': profile.effectiveRoleLabel,
          'campus_code': profile.campus?.code,
          'campus_name': profile.campus?.name,
          'member_id_code': profile.memberIdCode,
          'qr_payload': profile.qrPayload,
          'qr_unlocked': profile.qrUnlocked ? 1 : 0,
          'profile_json': jsonEncode(profile.toJson()),
          'updated_at': timestamp.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Best-effort offline cache write.
    }
  }

  /// Reads the cached offline [AuthProfile], returning `null` (and wiping the
  /// stale cache) if no entry exists or if it is older than 7 days.
  Future<AuthProfile?> readCachedProfile() async {
    _lastReadWasStale = false;
    final db = await _openDb();
    if (db == null) {
      if (_memoryFallback == null) return null;
      if (_isStale(_memoryFallbackUpdatedAt)) {
        _lastReadWasStale = true;
        await clearCachedProfile();
        return null;
      }
      return _memoryFallback;
    }

    try {
      final rows = await db.query(
        _tableCachedSession,
        where: 'slot = ?',
        whereArgs: const <Object>[1],
        limit: 1,
      );
      if (rows.isEmpty) {
        if (_memoryFallback != null && _isStale(_memoryFallbackUpdatedAt)) {
          _lastReadWasStale = true;
          await clearCachedProfile();
          return null;
        }
        return _memoryFallback;
      }

      final updatedAtRaw = rows.first['updated_at'] as String?;
      final updatedAt =
          updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw) : null;
      if (_isStale(updatedAt)) {
        _lastReadWasStale = true;
        await clearCachedProfile();
        return null;
      }

      final rawJson = rows.first['profile_json'] as String?;
      if (rawJson == null || rawJson.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        final parsed = AuthProfile.fromJson(decoded);
        _memoryFallback = parsed;
        _memoryFallbackUpdatedAt = updatedAt;
        return parsed;
      }
      return null;
    } catch (_) {
      if (_memoryFallback != null && _isStale(_memoryFallbackUpdatedAt)) {
        _lastReadWasStale = true;
        await clearCachedProfile();
        return null;
      }
      return _memoryFallback;
    }
  }

  /// Wipes the cached profile on sign-out, HTTP 401 session revocation, or
  /// 7-day offline cache expiration.
  Future<void> clearCachedProfile() async {
    _memoryFallback = null;
    _memoryFallbackUpdatedAt = null;
    final db = await _openDb();
    if (db == null) return;

    try {
      await db.delete(_tableCachedSession);
    } catch (_) {
      // Ignore cleanup errors.
    }
  }
}
