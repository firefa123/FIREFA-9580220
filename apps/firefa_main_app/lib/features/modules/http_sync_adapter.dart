import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_client.dart';
import 'sync_adapter.dart';

/// REST adapter matching backend/src/routes/sync.ts.
/// Local IDs are mapped to server outlet UUIDs; cloud sync is never inferred
/// from a successful socket connection alone.
class FirefaHttpSyncAdapter extends FirefaSyncAdapter {
  const FirefaHttpSyncAdapter();

  static const _deviceKey = 'firefa_backend_device_id_v1';
  static const _versionsKey = 'firefa_backend_order_versions_v1';

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_deviceKey);
    if (saved != null && _isUuid(saved)) return saved;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final parts = [
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 20),
      hex.substring(20),
    ];
    final id = parts.join('-');
    await prefs.setString(_deviceKey, id);
    return id;
  }

  String _versionKey(String tenantId, String serverOutletId, String deviceId, String orderId) =>
      '${tenantId.toLowerCase()}|${serverOutletId.toLowerCase()}|${deviceId.toLowerCase()}|$orderId';

  String? _utcIso(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc().toIso8601String();
  }

  Future<int?> _version(String key) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final data = Map<String, dynamic>.from(
        jsonDecode(prefs.getString(_versionsKey) ?? '{}') as Map,
      );
      return data[key] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveVersion(String key, int version) async {
    final prefs = await SharedPreferences.getInstance();
    final data = Map<String, dynamic>.from(
      jsonDecode(prefs.getString(_versionsKey) ?? '{}') as Map,
    );
    data[key] = version;
    await prefs.setString(_versionsKey, jsonEncode(data));
  }

  @override
  Future<FirefaSyncReceipt> send(FirefaSyncEnvelope event) async {
    if (!FirefaBackendConfig.isConfigured) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.retryableFailure,
        message: 'Backend belum dikonfigurasi; event tetap tersimpan lokal.',
      );
    }

    if (!FirefaBackendConfig.baseUrl.toLowerCase().startsWith('https://') && !kDebugMode) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.permanentFailure,
        message: 'Backend production wajib menggunakan HTTPS.',
      );
    }

    final client = FirefaBackendClient.instance;
    final FirefaBackendSession? session;
    try {
      session = await client.restoreSession();
    } on FormatException catch (error) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.permanentFailure,
        message: error.message,
      );
    }
    if (session == null) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.retryableFailure,
        message: 'Login backend diperlukan sebelum sinkronisasi.',
      );
    }

    final String serverOutletId;
    try {
      serverOutletId = FirefaBackendConfig.resolveServerOutletId(
        localOutletId: event.outletId,
        mapping: FirefaBackendConfig.validatedOutletMap,
        authorizedServerOutletIds: session.outletIds,
      );
    } on FormatException catch (error) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.permanentFailure,
        message: error.message,
      );
    } on ArgumentError catch (error) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.permanentFailure,
        message: error.message?.toString() ?? 'Outlet lokal tidak valid.',
      );
    }

    final source = event.orderSnapshot;
    final paymentStatus = source['paymentStatus'] as String? ?? 'unpaid';
    final paymentMethod = (source['paymentMethod'] as String?)?.toLowerCase();
    final rawRefundRecords = source['refundRecords'];
    final refundRecords = rawRefundRecords is List ? rawRefundRecords : const [];
    final hasNonCashRefund = refundRecords.any((entry) {
      final refund = Map<String, dynamic>.from(entry as Map);
      return (refund['method'] as String? ?? '').toLowerCase() != 'cash';
    });
    if (hasNonCashRefund) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.permanentFailure,
        message: 'Refund non-tunai memerlukan verifikasi penyedia pembayaran.',
      );
    }
    if (paymentStatus == 'paid' && paymentMethod != 'cash') {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.permanentFailure,
        message: 'Pembayaran non-tunai memerlukan endpoint verifikasi pembayaran.',
      );
    }
    final deviceId = await _deviceId();
    final versionKey = _versionKey(session.tenantId, serverOutletId, deviceId, event.orderId);
    final isCreate = event.eventType == 'order.created';
    final expectedVersion = isCreate || event.eventType == 'order.recovered'
        ? null
        : await _version(versionKey);
    if (!isCreate && event.eventType != 'order.recovered' && expectedVersion == null) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.retryableFailure,
        message: 'Versi server pesanan belum tersedia; event ditahan untuk rekonsiliasi.',
      );
    }

    final rawItems = source['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.permanentFailure,
        message: 'Pesanan tidak memiliki item yang dapat disinkronkan.',
      );
    }
    final items = rawItems.map((item) {
      final value = Map<String, dynamic>.from(item as Map);
      return {
        'productName': value['productName'],
        'quantity': value['quantity'],
        'unitPrice': value['unitPrice'],
        'details': value['details'] ?? '',
      };
    }).toList();

    final snapshot = <String, dynamic>{
      'id': event.orderId,
      'outletId': serverOutletId,
      'orderType': source['orderType'] ?? 'Take Away',
      'tableId': source['tableId'],
      'createdAt': _utcIso(source['createdAt']) ?? event.createdAt.toUtc().toIso8601String(),
      'items': items,
      'subtotal': source['subtotal'],
      'discount': source['discount'],
      'tax': source['tax'],
      'service': source['service'],
      'total': source['total'],
      'status': source['status'],
      'paymentStatus': source['paymentStatus'] ?? 'unpaid',
      'paymentMethod': source['paymentMethod'],
      'cashPaidAmount': source['cashPaidAmount'] ?? 0,
      'paidAt': _utcIso(source['paidAt']),
      'customerId': source['customerId'],
      'customerName': source['customerName'],
      'refundAmount': source['refundAmount'] ?? 0,
      'cashRefundAmount': source['cashRefundAmount'] ?? 0,
      'refundedAt': _utcIso(source['refundedAt']),
      'refundMethod': source['refundMethod'],
      'refundReason': source['refundReason'],
      'refundRecords': refundRecords.map((entry) {
        final refund = Map<String, dynamic>.from(entry as Map);
        return {
          'amount': refund['amount'],
          'method': refund['method'],
          'reason': refund['reason'],
          'createdAt': _utcIso(refund['createdAt']) ?? event.createdAt.toUtc().toIso8601String(),
        };
      }).toList(),
    };
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'eventId': event.eventId,
      'deviceId': deviceId,
      'outletId': serverOutletId,
      'orderId': event.orderId,
      'eventType': event.eventType,
      'createdAt': event.createdAt.toUtc().toIso8601String(),
      'expectedServerVersion': ?expectedVersion,
      'orderSnapshot': snapshot,
    };

    Future<http.Response> post(String token) => http.post(
      Uri.parse('${client.baseUrl}/api/v1/sync/events'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
        'idempotency-key': event.eventId,
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 20));

    try {
      var token = await client.accessToken();
      if (token == null) {
        return FirefaSyncReceipt(
          eventId: event.eventId,
          outcome: FirefaSyncOutcome.retryableFailure,
          message: 'Login backend diperlukan sebelum sinkronisasi.',
        );
      }
      var response = await post(token);
      if (response.statusCode == 401) {
        token = await client.accessToken(forceRefresh: true);
        if (token == null) {
          return FirefaSyncReceipt(
            eventId: event.eventId,
            outcome: FirefaSyncOutcome.retryableFailure,
            message: 'Sesi backend berakhir; login kembali.',
          );
        }
        response = await post(token);
      }

      final body = _tryJson(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final serverReference = body?['serverReference'];
        final globalOrderId = body?['globalOrderId'];
        final serverVersion = body?['serverVersion'];
        if (body == null ||
            body['schemaVersion'] != 1 ||
            body['eventId'] != event.eventId ||
            body['outcome'] != 'acknowledged' ||
            serverReference is! String ||
            serverReference.trim().isEmpty ||
            globalOrderId is! String ||
            !_isUuid(globalOrderId) ||
            serverVersion is! int ||
            serverVersion < 1) {
          return FirefaSyncReceipt(
            eventId: event.eventId,
            outcome: FirefaSyncOutcome.permanentFailure,
            message: 'Tanda terima server tidak valid; event tidak ditandai tersinkron.',
          );
        }
        await _saveVersion(versionKey, serverVersion);
        return FirefaSyncReceipt(
          eventId: event.eventId,
          outcome: FirefaSyncOutcome.acknowledged,
          serverReference: serverReference,
          serverOutletId: event.outletId,
          serverOrderId: event.orderId,
        );
      }

      if (response.statusCode == 409 && body?['error'] == 'stale_order_version') {
        final rawServerSnapshot = body?['serverSnapshot'];
        final serverVersion = body?['serverVersion'];
        if (rawServerSnapshot is Map && serverVersion is int && serverVersion > 0) {
          final serverSnapshot = Map<String, dynamic>.from(rawServerSnapshot);
          // Never normalize a mismatched server identity into a valid conflict.
          // Verify the response's actual server scope before translating IDs.
          if (serverSnapshot['outletId'] != serverOutletId ||
              serverSnapshot['id'] != event.orderId) {
            return FirefaSyncReceipt(
              eventId: event.eventId,
              outcome: FirefaSyncOutcome.permanentFailure,
              message: 'Identitas outlet/pesanan pada konflik server tidak cocok.',
            );
          }
          await _saveVersion(versionKey, serverVersion);
          serverSnapshot['outletId'] = event.outletId;
          return FirefaSyncReceipt(
            eventId: event.eventId,
            outcome: FirefaSyncOutcome.conflict,
            serverOutletId: event.outletId,
            serverOrderId: event.orderId,
            serverSnapshot: serverSnapshot,
            message: 'Pesanan berubah di server (versi $serverVersion).',
          );
        }
      }

      final permanent = response.statusCode >= 400 &&
          response.statusCode < 500 &&
          response.statusCode != 408 &&
          response.statusCode != 429;
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: permanent ? FirefaSyncOutcome.permanentFailure : FirefaSyncOutcome.retryableFailure,
        message: (body?['error'] as String?)?.replaceAll('_', ' ') ??
            'Sinkronisasi gagal (${response.statusCode}).',
      );
    } on TimeoutException {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.retryableFailure,
        message: 'Koneksi habis waktu; event tetap tersimpan lokal.',
      );
    } catch (_) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.retryableFailure,
        message: 'Backend tidak dapat dijangkau; event tetap tersimpan lokal.',
      );
    }
  }

  Map<String, dynamic>? _tryJson(String value) {
    try {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      return null;
    }
  }
}