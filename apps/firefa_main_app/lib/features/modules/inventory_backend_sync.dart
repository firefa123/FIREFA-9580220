import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/role_permissions.dart';
import 'backend_client.dart';
import 'inventory_store.dart';

class FirefaInventorySyncResult {
  final int attempted;
  final int acknowledged;
  final int failed;
  final List<String> errors;

  const FirefaInventorySyncResult({
    required this.attempted,
    required this.acknowledged,
    required this.failed,
    this.errors = const [],
  });
}

class FirefaInventoryStockDifference {
  final String localItemId;
  final String itemName;
  final int localStock;
  final double serverStock;

  const FirefaInventoryStockDifference({
    required this.localItemId,
    required this.itemName,
    required this.localStock,
    required this.serverStock,
  });

  double get difference => localStock - serverStock;
}

/// Durable retry bridge for inventory movements. A movement is only marked
/// acknowledged after the server confirms it; retry uses the same key, so a
/// lost HTTP response cannot apply the stock delta twice.
class FirefaInventoryBackendSync {
  FirefaInventoryBackendSync._();
  static final instance = FirefaInventoryBackendSync._();

  static const _deviceKey = 'firefa_inventory_sync_device_v1';
  static const _sentPrefix = 'firefa_inventory_synced_movements_v1';
  static const _blockedPrefix = 'firefa_inventory_blocked_movements_v1';

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceKey);
    if (existing != null && FirefaBackendConfig.isUuid(existing)) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await prefs.setString(_deviceKey, id);
    return id;
  }

  String _sentKey(String tenantId, String outletId, String deviceId) =>
      '$_sentPrefix:${tenantId.toLowerCase()}:${outletId.toLowerCase()}:${deviceId.toLowerCase()}';

  Future<void> retryBlockedMovement({
    required String localOutletId,
    required String movementId,
  }) async {
    final client = FirefaBackendClient.instance;
    final session = await client.restoreSession();
    if (session == null) throw const FirefaBackendException('Login backend diperlukan.');
    final serverOutletId = FirefaBackendConfig.resolveServerOutletId(
      localOutletId: localOutletId,
      mapping: FirefaBackendConfig.validatedOutletMap,
      authorizedServerOutletIds: session.outletIds,
    );
    final deviceId = await _deviceId();
    final prefs = await SharedPreferences.getInstance();
    final key = '$_blockedPrefix:${session.tenantId.toLowerCase()}:${serverOutletId.toLowerCase()}:${deviceId.toLowerCase()}';
    final blocked = (prefs.getStringList(key) ?? <String>[]).toSet();
    blocked.remove(movementId);
    await prefs.setStringList(key, blocked.toList());
  }

  Future<FirefaInventorySyncResult> syncOutlet(String localOutletId) async {
    if (!FirefaBackendConfig.isConfigured) {
      return const FirefaInventorySyncResult(attempted: 0, acknowledged: 0, failed: 0);
    }
    final store = FirefaInventoryStore.instance;
    await store.initialize();
    final client = FirefaBackendClient.instance;
    final session = await client.restoreSession();
    if (session == null || session.role != FirefaRole.owner) {
      return const FirefaInventorySyncResult(attempted: 0, acknowledged: 0, failed: 0);
    }

    final String serverOutletId;
    final Map<String, String> itemMap;
    try {
      serverOutletId = FirefaBackendConfig.resolveServerOutletId(
        localOutletId: localOutletId,
        mapping: FirefaBackendConfig.validatedOutletMap,
        authorizedServerOutletIds: session.outletIds,
      );
      itemMap = FirefaBackendConfig.validatedInventoryItemMap;
    } on FormatException catch (error) {
      return FirefaInventorySyncResult(
        attempted: 0, acknowledged: 0, failed: 1, errors: [error.message],
      );
    } on ArgumentError catch (error) {
      return FirefaInventorySyncResult(
        attempted: 0, acknowledged: 0, failed: 1, errors: [error.message?.toString() ?? 'Outlet tidak valid'],
      );
    }

    final deviceId = await _deviceId();
    final prefs = await SharedPreferences.getInstance();
    final sentKey = _sentKey(session.tenantId, serverOutletId, deviceId);
    final sent = (prefs.getStringList(sentKey) ?? <String>[]).toSet();
    final blockedKey = '$_blockedPrefix:${session.tenantId.toLowerCase()}:${serverOutletId.toLowerCase()}:${deviceId.toLowerCase()}';
    final blocked = (prefs.getStringList(blockedKey) ?? <String>[]).toSet();
    final movements = store.historyForOutlet(localOutletId).reversed.toList();
    var attempted = 0;
    var acknowledged = 0;
    var failed = 0;
    final errors = <String>[];
    // Preserve ledger order per item. If an earlier movement cannot be
    // acknowledged, do not send a later delta for that same item out of order.
    final pausedItemIds = <String>{};

    for (final movement in movements) {
      if (sent.contains(movement.id)) continue;
      if (blocked.contains(movement.id)) {
        pausedItemIds.add(movement.itemId);
        continue;
      }
      if (pausedItemIds.contains(movement.itemId)) continue;
      attempted++;
      try {
        final serverItemId = FirefaBackendConfig.resolveServerInventoryItemId(
          localItemId: movement.itemId,
          mapping: itemMap,
        );
        final delta = movement.after - movement.before;
        if (delta == 0) {
          sent.add(movement.id);
          await prefs.setStringList(sentKey, sent.toList());
          acknowledged++;
          continue;
        }
        final movementType = movement.type == 'correction'
            ? 'adjustment'
            : delta > 0 ? 'receipt' : 'sale';
        final payload = <String, dynamic>{
          'outletId': serverOutletId,
          'inventoryItemId': serverItemId,
          'movementType': movementType,
          'quantityDelta': delta,
          'unitCost': store.forOutlet(localOutletId)
              .where((item) => item.id == movement.itemId)
              .map((item) => item.unitCost)
              .firstOrNull ?? 0,
          'sourceType': 'firefa_local_movement',
          'sourceId': movement.id,
          'note': movement.note,
        };
        final idempotencyKey = 'inventory:$deviceId:${movement.id}';
        Future<http.Response> post(String token) => http.post(
          Uri.parse('${client.baseUrl}/api/v1/inventory/movements'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $token',
            'idempotency-key': idempotencyKey,
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 20));

        var token = await client.accessToken();
        if (token == null) throw const FirefaBackendException('Login backend diperlukan.');
        var response = await post(token);
        if (response.statusCode == 401) {
          token = await client.accessToken(forceRefresh: true);
          if (token == null) throw const FirefaBackendException('Sesi backend berakhir; login kembali.');
          response = await post(token);
        }
        final body = _tryJson(response.body);
        if ((response.statusCode == 200 || response.statusCode == 201) &&
            body != null &&
            body['id'] is String &&
            body['eventId'] == idempotencyKey &&
            body['outletId'] == serverOutletId &&
            body['inventoryItemId'] == serverItemId &&
            body['quantityOnHand'] is num &&
            (body['quantityOnHand'] as num).isFinite &&
            (body['quantityOnHand'] as num) >= 0) {
          sent.add(movement.id);
          await prefs.setStringList(sentKey, sent.toList());
          acknowledged++;
        } else {
          failed++;
          final permanent = response.statusCode >= 400 &&
              response.statusCode < 500 &&
              response.statusCode != 408 &&
              response.statusCode != 429;
          if (permanent) {
            blocked.add(movement.id);
            await prefs.setStringList(blockedKey, blocked.toList());
          }
          pausedItemIds.add(movement.itemId);
          errors.add('${movement.id}: ${body?['error'] ?? 'HTTP ${response.statusCode}'}'
              '${permanent ? ' (dihentikan sampai ditinjau; panggil retryBlockedMovement setelah koreksi)' : ''}');
        }
      } on TimeoutException {
        failed++;
        pausedItemIds.add(movement.itemId);
        errors.add('${movement.id}: timeout; akan dicoba lagi dengan idempotency key yang sama');
      } catch (error) {
        failed++;
        pausedItemIds.add(movement.itemId);
        errors.add('${movement.id}: $error');
      }
    }
    return FirefaInventorySyncResult(
      attempted: attempted, acknowledged: acknowledged, failed: failed, errors: errors,
    );
  }

  Future<List<FirefaInventoryStockDifference>> reconcileOutlet(String localOutletId) async {
    if (!FirefaBackendConfig.isConfigured) {
      throw const FirefaBackendException('Backend belum dikonfigurasi.');
    }
    final client = FirefaBackendClient.instance;
    final session = await client.restoreSession();
    if (session == null || session.role != FirefaRole.owner) {
      throw const FirefaBackendException('Rekonsiliasi stok memerlukan sesi Owner.');
    }
    final serverOutletId = FirefaBackendConfig.resolveServerOutletId(
      localOutletId: localOutletId,
      mapping: FirefaBackendConfig.validatedOutletMap,
      authorizedServerOutletIds: session.outletIds,
    );
    final itemMap = FirefaBackendConfig.validatedInventoryItemMap;
    final token = await client.accessToken();
    if (token == null) throw const FirefaBackendException('Login backend diperlukan.');
    final response = await http.get(
      Uri.parse('${client.baseUrl}/api/v1/inventory/reconcile?outletId=$serverOutletId'),
      headers: {'authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 20));
    final body = _tryJson(response.body);
    if (response.statusCode != 200 || body == null || body['items'] is! List) {
      throw FirefaBackendException(
        'Rekonsiliasi gagal: ${body?['error'] ?? 'HTTP ${response.statusCode}'}',
        statusCode: response.statusCode,
      );
    }
    final serverById = <String, double>{};
    final serverNameById = <String, String>{};
    for (final raw in body['items'] as List) {
      if (raw is Map && raw['id'] is String && raw['quantityOnHand'] is num) {
        final id = raw['id'] as String;
        serverById[id] = (raw['quantityOnHand'] as num).toDouble();
        if (raw['name'] is String) serverNameById[id] = raw['name'] as String;
      }
    }
    final store = FirefaInventoryStore.instance;
    await store.initialize();
    final differences = <FirefaInventoryStockDifference>[];
    final matchedServerIds = <String>{};
    for (final item in store.forOutlet(localOutletId)) {
      final serverId = itemMap[item.id];
      if (serverId == null || !FirefaBackendConfig.isUuid(serverId)) {
        differences.add(FirefaInventoryStockDifference(
          localItemId: item.id,
          itemName: item.name,
          localStock: item.stock,
          serverStock: double.nan,
        ));
        continue;
      }
      final normalizedServerId = serverId.toLowerCase();
      matchedServerIds.add(normalizedServerId);
      final serverStock = serverById[normalizedServerId];
      if (serverStock == null || serverStock != item.stock.toDouble()) {
        differences.add(FirefaInventoryStockDifference(
          localItemId: item.id,
          itemName: item.name,
          localStock: item.stock,
          serverStock: serverStock ?? double.nan,
        ));
      }
    }
    // Report server-side inventory rows that have no local counterpart rather
    // than silently declaring the outlet reconciled.
    for (final entry in serverById.entries) {
      if (!matchedServerIds.contains(entry.key)) {
        differences.add(FirefaInventoryStockDifference(
          localItemId: 'server:${entry.key}',
          itemName: serverNameById[entry.key] ?? 'Item server tidak terpetakan',
          localStock: 0,
          serverStock: entry.value,
        ));
      }
    }
    return List.unmodifiable(differences);
  }

  Map<String, dynamic>? _tryJson(String value) {
    try {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      return null;
    }
  }
}
