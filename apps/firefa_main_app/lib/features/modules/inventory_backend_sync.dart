import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/role_permissions.dart';
import 'backend_client.dart';
import 'inventory_store.dart';
import 'firefa_http_sync_adapter.dart';
import 'offline_sync_queue.dart';
import 'order_store.dart';
import 'order_models.dart';

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
  static const _suppressedPrefix = 'firefa_inventory_suppressed_movements_v1';

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
    if (session == null) {
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
    final suppressedKey = '$_suppressedPrefix:${session.tenantId.toLowerCase()}:${serverOutletId.toLowerCase()}:${deviceId.toLowerCase()}';
    final suppressed = (prefs.getStringList(suppressedKey) ?? <String>[]).toSet();
    final movements = store.historyForOutlet(localOutletId).reversed.toList();
    final orderDeviceId = await FirefaHttpSyncAdapter.installationDeviceId();
    await FirefaOfflineSyncQueue.instance.initialize();
    await FirefaOrderStore.instance.initialize();
    var attempted = 0;
    var acknowledged = 0;
    var failed = 0;
    final errors = <String>[];
    // Preserve ledger order per item. If an earlier movement cannot be
    // acknowledged, do not send a later delta for that same item out of order.
    final pausedItemIds = <String>{};

    for (final movement in movements) {
      if (sent.contains(movement.id)) continue;
      if (pausedItemIds.contains(movement.itemId)) continue;

      final posOrderId = _posOrderIdFromMovement(movement);
      final isPosSale = movement.note.startsWith('POS order ');
      final isPosReversal = movement.note.startsWith('Pembatalan POS order ');
      if (posOrderId != null && (isPosSale || isPosReversal)) {
        final order = FirefaOrderStore.instance.findOrder(localOutletId, posOrderId);
        final orderEvents = FirefaOfflineSyncQueue.instance.entriesForOutlet(localOutletId)
            .where((entry) => entry.orderId == posOrderId).toList();
        final cancellationEventSynced = orderEvents.any((entry) =>
            entry.status == FirefaSyncStatus.synced &&
            entry.eventType == 'order.updated' &&
            entry.orderSnapshot['status'] == 'cancelled');
        if (order != null && order.status == FirefaOrderStatus.cancelled &&
            cancellationEventSynced &&
            orderEvents.every((entry) => entry.status == FirefaSyncStatus.synced)) {
          final saleMovementId = movements.where((candidate) =>
              candidate.note == 'POS order $posOrderId')
              .map((candidate) => candidate.id).firstOrNull;
          if (isPosSale && !sent.contains(movement.id)) {
            // The order was cancelled before its local sale movement reached
            // the server. Suppress both local deltas instead of applying a
            // sale to an already-cancelled server order and blocking reversal.
            sent.add(movement.id);
            suppressed.add(movement.id);
            blocked.remove(movement.id);
            await prefs.setStringList(sentKey, sent.toList());
            await prefs.setStringList(suppressedKey, suppressed.toList());
            await prefs.setStringList(blockedKey, blocked.toList());
            continue;
          }
          if (isPosReversal && saleMovementId != null &&
              suppressed.contains(saleMovementId)) {
            sent.add(movement.id);
            suppressed.add(movement.id);
            blocked.remove(movement.id);
            await prefs.setStringList(sentKey, sent.toList());
            await prefs.setStringList(suppressedKey, suppressed.toList());
            await prefs.setStringList(blockedKey, blocked.toList());
            continue;
          }
        }
        if (isPosSale) {
          final creationEventExists = orderEvents.any((entry) =>
              entry.eventType == 'order.created' || entry.eventType == 'order.recovered');
          final creationEventSynced = orderEvents.any((entry) =>
              entry.status == FirefaSyncStatus.synced &&
              (entry.eventType == 'order.created' || entry.eventType == 'order.recovered'));
          if (creationEventExists && !creationEventSynced) {
            pausedItemIds.add(movement.itemId);
            errors.add('${movement.id}: menunggu pembuatan pesanan $posOrderId tersinkron sebelum stok dikirim');
            continue;
          }
          // Later status events must not pass an unacknowledged sale movement:
          // retry the sale before a pending cancellation, then send its reversal.
        }
        if (isPosReversal &&
            (!cancellationEventSynced ||
             orderEvents.any((entry) => entry.status != FirefaSyncStatus.synced))) {
          pausedItemIds.add(movement.itemId);
          errors.add('${movement.id}: menunggu pembatalan pesanan $posOrderId terkonfirmasi server');
          continue;
        }
      }

      if (blocked.contains(movement.id)) {
        pausedItemIds.add(movement.itemId);
        continue;
      }
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
        var sourceType = 'firefa_local_movement';
        var sourceId = movement.id;
        String? sourceDeviceId;
        if (posOrderId != null && (isPosSale || isPosReversal)) {
          final globalOrderId = await FirefaHttpSyncAdapter.serverOrderIdFor(
            tenantId: session.tenantId,
            serverOutletId: serverOutletId,
            localOrderId: posOrderId,
          );
          if (globalOrderId == null) {
            attempted--;
            pausedItemIds.add(movement.itemId);
            errors.add('${movement.id}: menunggu receipt pesanan $posOrderId untuk mendapatkan identitas server');
            continue;
          }
          sourceType = isPosReversal ? 'pos_order_reversal' : 'pos_order';
          sourceId = globalOrderId;
          sourceDeviceId = orderDeviceId;
        }
        final payload = <String, dynamic>{
          'outletId': serverOutletId,
          'inventoryItemId': serverItemId,
          'movementType': movementType,
          'quantityDelta': delta,
          'unitCost': store.forOutlet(localOutletId)
              .where((item) => item.id == movement.itemId)
              .map((item) => item.unitCost)
              .firstOrNull ?? 0,
          'sourceType': sourceType,
          'sourceId': sourceId,
          if (sourceDeviceId != null) 'deviceId': sourceDeviceId,
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

  String? _posOrderIdFromMovement(FirefaStockMovement movement) {
    const salePrefix = 'POS order ';
    const reversalPrefix = 'Pembatalan POS order ';
    if (movement.note.startsWith(reversalPrefix)) {
      final value = movement.note.substring(reversalPrefix.length).trim();
      return value.isEmpty ? null : value;
    }
    if (movement.note.startsWith(salePrefix)) {
      final value = movement.note.substring(salePrefix.length).trim();
      return value.isEmpty ? null : value;
    }
    return null;
  }

  Map<String, dynamic>? _tryJson(String value) {
    try {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      return null;
    }
  }
}
