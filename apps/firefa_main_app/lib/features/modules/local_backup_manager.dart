import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inventory_store.dart';
import 'menu_store.dart';
import 'order_store.dart';
import 'table_store.dart';

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

  Future<void> _initializeStores() async {
    await Future.wait([
      FirefaOrderStore.instance.initialize(),
      FirefaInventoryStore.instance.initialize(),
      FirefaMenuStore.instance.initialize(),
      FirefaTableStore.instance.initialize(),
    ]);
  }

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
    await _initializeStores();
    final orders = FirefaOrderStore.instance;
    final inventory = FirefaInventoryStore.instance;
    final menu = FirefaMenuStore.instance;
    final tables = FirefaTableStore.instance;

    await Future.wait([
      orders.waitForPendingSave(),
      inventory.waitForPendingSave(),
      menu.waitForPendingSave(),
      tables.waitForPendingSave(),
    ]);

    final snapshot = <String, dynamic>{
      'orders': orders.exportLocalSnapshot(),
      'inventory': inventory.exportLocalSnapshot(),
      'menu': menu.exportLocalSnapshot(),
      'tables': tables.exportLocalSnapshot(),
    };
    final orderSnapshot = snapshot['orders'] as Map<String, dynamic>;
    final orderList = orderSnapshot['orders'] as List;
    final outbox = Map<String, dynamic>.from(orderSnapshot['outbox'] as Map);
    final entries = outbox['entries'] as List;
    final pending = entries.where((entry) {
      final status = Map<String, dynamic>.from(entry as Map)['status'] as String?;
      return status == 'pending' || status == 'failed' || status == 'syncing';
    }).length;

    final now = DateTime.now();
    final payload = jsonEncode({
      'backupVersion': 2,
      'createdAt': now.toUtc().toIso8601String(),
      'snapshot': snapshot,
    });
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_backupKey, payload)) {
      throw StateError('Gagal menyimpan local backup FIREFA.');
    }

    final info = FirefaLocalBackupInfo(
      createdAt: now,
      orderCount: orderList.length,
      pendingEvents: pending,
    );
    if (!await prefs.setString(_backupMetaKey, jsonEncode({
      'createdAt': now.toUtc().toIso8601String(),
      'orderCount': info.orderCount,
      'pendingEvents': info.pendingEvents,
    }))) {
      throw StateError('Backup tersimpan tetapi metadata gagal disimpan.');
    }

    _latest = info;
    notifyListeners();
    return info;
  }

  Future<FirefaLocalBackupInfo> restoreLatestBackup() async {
    await _initializeStores();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_backupKey);
    if (raw == null || raw.isEmpty) {
      throw StateError('Belum ada local backup FIREFA.');
    }

    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final version = decoded['backupVersion'];
    if (version != 1 && version != 2) {
      throw const FormatException('Versi file backup tidak didukung.');
    }
    final createdAt = DateTime.parse(decoded['createdAt'] as String).toLocal();
    final snapshot = Map<String, dynamic>.from(decoded['snapshot'] as Map);
    final Map<String, dynamic> orderSnapshot;

    if (version == 1) {
      // Compatibility with backups created before the full operational backup.
      orderSnapshot = snapshot;
    } else {
      final rawOrders = snapshot['orders'];
      final rawInventory = snapshot['inventory'];
      final rawMenu = snapshot['menu'];
      final rawTables = snapshot['tables'];
      if (rawOrders is! Map || rawInventory is! Map || rawMenu is! Map || rawTables is! List) {
        throw const FormatException('Struktur backup operasional tidak lengkap.');
      }
      final inventorySnapshot = Map<String, dynamic>.from(rawInventory);
      final menuSnapshot = Map<String, dynamic>.from(rawMenu);
      final tableSnapshot = List<dynamic>.from(rawTables);

      // Validate every domain snapshot before replacing any active store.
      FirefaInventoryStore.instance.validateLocalSnapshot(inventorySnapshot);
      FirefaMenuStore.instance.validateLocalSnapshot(menuSnapshot);
      FirefaTableStore.instance.validateLocalSnapshot(tableSnapshot);
      orderSnapshot = Map<String, dynamic>.from(rawOrders);
    }

    final orderList = orderSnapshot['orders'];
    final rawOutbox = orderSnapshot['outbox'];
    if (orderList is! List || rawOutbox is! Map) {
      throw const FormatException('Data order atau antrean sync pada backup tidak valid.');
    }
    final outbox = Map<String, dynamic>.from(rawOutbox);
    if (outbox['entries'] is! List) {
      throw const FormatException('Antrean sync pada backup tidak valid.');
    }

    // OrderStore validates its model snapshot before applying it.
    FirefaOrderStore.instance.restoreLocalSnapshot(orderSnapshot);
    await FirefaOrderStore.instance.waitForPendingSave();

    if (version == 2) {
      await FirefaInventoryStore.instance.restoreLocalSnapshot(
        Map<String, dynamic>.from(snapshot['inventory'] as Map),
      );
      await FirefaMenuStore.instance.restoreLocalSnapshot(
        Map<String, dynamic>.from(snapshot['menu'] as Map),
      );
      await FirefaTableStore.instance.restoreLocalSnapshot(
        List<dynamic>.from(snapshot['tables'] as List),
      );
    }

    final entries = outbox['entries'] as List;
    final pending = entries.where((entry) {
      final status = Map<String, dynamic>.from(entry as Map)['status'] as String?;
      return status == 'pending' || status == 'failed' || status == 'syncing';
    }).length;
    final info = FirefaLocalBackupInfo(
      createdAt: createdAt,
      orderCount: orderList.length,
      pendingEvents: pending,
    );
    _latest = info;
    notifyListeners();
    return info;
  }
}
