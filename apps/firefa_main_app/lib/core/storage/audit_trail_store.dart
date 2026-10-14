import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FirefaAuditEntry {
  const FirefaAuditEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actorId,
    required this.outletId,
    required this.timestamp,
    this.details = const {},
  });

  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String actorId;
  final String outletId;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'actorId': actorId,
        'outletId': outletId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'details': details,
      };

  factory FirefaAuditEntry.fromJson(Map<String, dynamic> json) =>
      FirefaAuditEntry(
        id: json['id'] as String,
        action: json['action'] as String,
        entityType: json['entityType'] as String,
        entityId: json['entityId'] as String,
        actorId: json['actorId'] as String,
        outletId: json['outletId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
        details: Map<String, dynamic>.from(json['details'] as Map? ?? const {}),
      );
}

class FirefaAuditTrailStore {
  FirefaAuditTrailStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const storageKey = 'firefa_audit_trail_v1';
  SharedPreferences? _preferences;
  Future<void> _queue = Future<void>.value();
  int _sequence = 0;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<FirefaAuditEntry> append({
    required String action,
    required String entityType,
    required String entityId,
    required String actorId,
    required String outletId,
    Map<String, dynamic> details = const {},
    DateTime? timestamp,
  }) {
    final completer = Completer<FirefaAuditEntry>();
    _queue = _queue.then((_) async {
      try {
        final normalized = [
          action.trim(),
          entityType.trim(),
          entityId.trim(),
          actorId.trim(),
          outletId.trim(),
        ];
        if (normalized.any((value) => value.isEmpty)) {
          throw ArgumentError('Field audit trail tidak boleh kosong.');
        }
        final prefs = await _prefs;
        final raw = prefs.getString(storageKey);
        final existing = raw == null
            ? <FirefaAuditEntry>[]
            : (jsonDecode(raw) as List<dynamic>)
                .map((item) => FirefaAuditEntry.fromJson(
                    Map<String, dynamic>.from(item as Map)))
                .toList();
        _sequence++;
        final entry = FirefaAuditEntry(
          id: 'AUD-${DateTime.now().microsecondsSinceEpoch}-$_sequence',
          action: normalized[0],
          entityType: normalized[1],
          entityId: normalized[2],
          actorId: normalized[3],
          outletId: normalized[4],
          timestamp: timestamp ?? DateTime.now(),
          details: Map.unmodifiable(details),
        );
        existing.add(entry);
        if (!await prefs.setString(
          storageKey,
          jsonEncode(existing.map((item) => item.toJson()).toList()),
        )) {
          throw StateError('Gagal menyimpan audit trail.');
        }
        completer.complete(entry);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<List<FirefaAuditEntry>> read({
    String? outletId,
    String? entityType,
    int limit = 100,
  }) async {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    await _queue;
    final raw = (await _prefs).getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final entries = (jsonDecode(raw) as List<dynamic>)
        .map((item) => FirefaAuditEntry.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .where((entry) =>
            (outletId == null || entry.outletId == outletId) &&
            (entityType == null || entry.entityType == entityType))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(entries.take(limit));
  }
}
