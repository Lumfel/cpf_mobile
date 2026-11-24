import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:cpf_mobile/models/auth_profile.dart';

/// Offline SQLite cache (`sqflite` + `path`) storing the signed-in user's
/// profile, role, campus, and HMAC-signed `qr_payload` so the Peer Dashboard
/// QR Pass opens reliably even without internet connectivity.
///
/// The Sanctum Bearer token is NEVER stored here — it stays encrypted inside
/// `flutter_secure_storage`.
class LocalDbService {
  LocalDbService();

  static const String _dbFileName = 'cpf_mobile_offline.db';
  static const int _dbVersion = 1;
  static const String _tableCachedSession = 'cached_session';

  Database? _db;
  AuthProfile? _memoryFallback;

  Future<Database?> _openDb() async {
    if (kIsWeb) {
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
  Future<void> cacheProfile(AuthProfile profile) async {
    _memoryFallback = profile;
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
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Best-effort offline cache write.
    }
  }

  /// Reads the cached offline [AuthProfile], or returns `null` if none exists.
  Future<AuthProfile?> readCachedProfile() async {
    final db = await _openDb();
    if (db == null) {
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
        return _memoryFallback;
      }
      final rawJson = rows.first['profile_json'] as String?;
      if (rawJson == null || rawJson.isEmpty) {
        return _memoryFallback;
      }
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        final parsed = AuthProfile.fromJson(decoded);
        _memoryFallback = parsed;
        return parsed;
      }
      return _memoryFallback;
    } catch (_) {
      return _memoryFallback;
    }
  }

  /// Wipes the cached profile on sign-out or HTTP 401 session revocation.
  Future<void> clearCachedProfile() async {
    _memoryFallback = null;
    final db = await _openDb();
    if (db == null) return;

    try {
      await db.delete(_tableCachedSession);
    } catch (_) {
      // Ignore cleanup errors.
    }
  }
}
