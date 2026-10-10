import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'conflict_management.dart';

class FirefaConflictAuditRecord {
  final String eventId;
  final String orderId;
  final String actorId;
  final FirefaConflictAction action;
  final DateTime resolvedAt;

  const FirefaConflictAuditRecord({
    required this.eventId,
    required this.orderId,
    required this.actorId,
    required this.action,
    required this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'orderId': orderId,
        'actorId': actorId,
        'action': action.name,
        'resolvedAt': resolvedAt.toUtc().toIso8601String(),
      };

  factory FirefaConflictAuditRecord.fromJson(Map<String, dynamic> json) {
    return FirefaConflictAuditRecord(
      eventId: json['eventId'],
      orderId: json['orderId'],
      actorId: json['actorId'],
      action: FirefaConflictAction.values.byName(json['action']),
      resolvedAt: DateTime.parse(json['resolvedAt']),
    );
  }
}

/// Immutable history of conflict decisions for traceability.
/// Audit entries cannot change business data.
class FirefaConflictAuditStore extends ChangeNotifier {
  FirefaConflictAuditStore._();
  static final instance = FirefaConflictAuditStore._();

  static const _key = 'firefa_conflict_audit_v1';
  final List<FirefaConflictAuditRecord> _records = [];

  List<FirefaConflictAuditRecord> get records => List.unmodifiable(_records);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      _records
        ..clear()
        ..addAll((jsonDecode(raw) as List).map((e) =>
            FirefaConflictAuditRecord.fromJson(
                Map<String, dynamic>.from(e as Map))));
    }
    notifyListeners();
  }

  Future<void> append(FirefaConflictAuditRecord record) async {
    _records.add(record);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_records.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }
}
