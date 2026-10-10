import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_store.dart';

class FirefaLocalBackupInfo {
  final DateTime createdAt;
  final int orderCount;
  final int pendingEvents;

  const FirefaLocalBackupInfo({
    required this.createdAt,
    required this.orderCount,
    required this.pendingEvents,
  });
}

class FirefaLocalBackupManager extends ChangeNotifier {
  FirefaLocalBackupManager._();

  static final FirefaLocalBackupManager instance = FirefaLocalBackupManager._();

  static const _backupKey = 'firefa_local_backup_v1';
  static const _backupMetaKey = 'firefa_local_backup_meta_v1';

  FirefaLocalBackupInfo? _latest;

  FirefaLocalBackupInfo? get latest => _latest;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_backupMetaKey);

    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _latest = FirefaLocalBackupInfo(
        createdAt: DateTime.parse(decoded['createdAt'] as String).toLocal(),
        orderCount: decoded['orderCount'] as int,
        pendingEvents: decoded['pendingEvents'] as int,
      );
      notifyListeners();
    } catch (error) {
      debugPrint('FIREFA backup metadata read failed: $error');
    }
  }

  Future<FirefaLocalBackupInfo> createBackup() async {
    final store = FirefaOrderStore.instance;
    await store.waitForPendingSave();

    final snapshot = store.exportLocalSnapshot();
    final orders = snapshot['orders'] as List;
    final outbox = Map<String, dynamic>.from(snapshot['outbox'] as Map);
    final entries = outbox['entries'] as List;

    final pending = entries.where((entry) {
      final map = Map<String, dynamic>.from(entry as Map);
      final status = map['status'] as String?;
      return status == 'pending' || status == 'failed' || status == 'syncing';
    }).length;

    final now = DateTime.now();
    final payload = jsonEncode({
      'backupVersion': 1,
      'createdAt': now.toUtc().toIso8601String(),
      'snapshot': snapshot,
    });

    final prefs = await SharedPreferences.getInstance();
    final stored = await prefs.setString(_backupKey, payload);
    if (!stored) {
      throw StateError('Gagal menyimpan local backup FIREFA.');
    }

    final info = FirefaLocalBackupInfo(
      createdAt: now,
      orderCount: orders.length,
      pendingEvents: pending,
    );

    final metaStored = await prefs.setString(
      _backupMetaKey,
      jsonEncode({
        'createdAt': now.toUtc().toIso8601String(),
        'orderCount': info.orderCount,
        'pendingEvents': info.pendingEvents,
      }),
    );

    if (!metaStored) {
      throw StateError('Backup tersimpan tetapi metadata gagal disimpan.');
    }

    _latest = info;
    notifyListeners();
    return info;
  }

  Future<FirefaLocalBackupInfo> restoreLatestBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_backupKey);

    if (raw == null || raw.isEmpty) {
      throw StateError('Belum ada local backup FIREFA.');
    }

    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (decoded['backupVersion'] != 1) {
      throw const FormatException('Versi file backup tidak didukung.');
    }

    final createdAt = DateTime.parse(decoded['createdAt'] as String).toLocal();
    final snapshot = Map<String, dynamic>.from(decoded['snapshot'] as Map);

    // OrderStore validates the snapshot before replacing active state.
    FirefaOrderStore.instance.restoreLocalSnapshot(snapshot);
    await FirefaOrderStore.instance.waitForPendingSave();

    final orders = snapshot['orders'] as List;
    final outbox = Map<String, dynamic>.from(snapshot['outbox'] as Map);
    final entries = outbox['entries'] as List;
    final pending = entries.where((entry) {
      final map = Map<String, dynamic>.from(entry as Map);
      final status = map['status'] as String?;
      return status == 'pending' || status == 'failed' || status == 'syncing';
    }).length;

    final info = FirefaLocalBackupInfo(
      createdAt: createdAt,
      orderCount: orders.length,
      pendingEvents: pending,
    );

    _latest = info;
    notifyListeners();
    return info;
  }
}
