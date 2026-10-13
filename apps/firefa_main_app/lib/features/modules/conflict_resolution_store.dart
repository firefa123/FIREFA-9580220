import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'conflict_resolution_model.dart';

/// Durable local audit of owner conflict decisions.
/// A decision is recorded here; it never mutates business data by itself.
class ConflictResolutionStore extends ChangeNotifier {
  ConflictResolutionStore._();
  static final ConflictResolutionStore instance = ConflictResolutionStore._();

  static const _storageKey = 'firefa_conflict_resolution_audit_v1';
  final List<FirefaConflictResolution> _records = [];
  bool _initialized = false;
  Future<void> _pendingSave = Future<void>.value();

  List<FirefaConflictResolution> get records => List.unmodifiable(_records);

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List;
      _records
        ..clear()
        ..addAll(decoded.map((value) {
          final json = Map<String, dynamic>.from(value as Map);
          return FirefaConflictResolution(
            conflictId: json['conflictId'] as String,
            action: FirefaResolutionAction.values.byName(json['action'] as String),
            actorId: json['actorId'] as String,
            resolvedAt: DateTime.parse(json['resolvedAt'] as String),
          );
        }));
    }
    _initialized = true;
    notifyListeners();
  }

  List<FirefaConflictResolution> byConflictId(String conflictId) =>
      _records.where((record) => record.conflictId == conflictId).toList(growable: false);

  Future<void> resolve({
    required String conflictId,
    required FirefaResolutionAction action,
    required String actorId,
  }) async {
    if (!_initialized) throw StateError('ConflictResolutionStore belum diinisialisasi.');
    if (conflictId.trim().isEmpty || actorId.trim().isEmpty) {
      throw ArgumentError('Conflict ID dan actor ID wajib diisi.');
    }
    final record = FirefaConflictResolution(
      conflictId: conflictId,
      action: action,
      actorId: actorId,
      resolvedAt: DateTime.now().toUtc(),
    );
    _records.add(record);
    try {
      await _save();
    } catch (_) {
      _records.remove(record);
      rethrow;
    }
    notifyListeners();
  }

  bool isResolved(String conflictId) => _records.any((record) =>
      record.conflictId == conflictId &&
      record.action != FirefaResolutionAction.manualReview);

  Future<void> _save() {
    final snapshot = jsonEncode(_records.map((record) => record.toJson()).toList());
    _pendingSave = _pendingSave.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_storageKey, snapshot)) {
        throw StateError('Gagal menyimpan audit resolusi konflik.');
      }
    });
    return _pendingSave;
  }

  Future<void> waitForPendingSave() => _pendingSave;
}
