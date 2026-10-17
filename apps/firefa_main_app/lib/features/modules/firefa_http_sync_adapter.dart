import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/role_permissions.dart';
import 'backend_client.dart';
import 'conflict_management.dart';
import 'sync_adapter.dart';

/// Authenticated transport for the documented POST /api/v1/sync/events contract.
/// No event is acknowledged from HTTP status alone; the full receipt is checked.
class FirefaHttpSyncAdapter extends FirefaSyncAdapter {
  FirefaHttpSyncAdapter({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static const _deviceKey = 'firefa_sync_device_id_v1';
  static const _versionPrefix = 'firefa_sync_server_version_v1';

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
    final saved = await prefs.setString(_deviceKey, id);
    if (!saved) throw StateError('ID instalasi sinkronisasi tidak dapat disimpan.');
    return id;
  }

  String _versionKey(String tenantId, String outletId, String deviceId, String orderId) =>
      '$_versionPrefix:${tenantId.toLowerCase()}:${outletId.toLowerCase()}:${deviceId.toLowerCase()}:$orderId';

  @override
  Future<FirefaSyncReceipt> send(FirefaSyncEnvelope event) async {
    if (!FirefaBackendConfig.isConfigured) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.retryableFailure,
        message: 'Cloud belum dikonfigurasi; event tetap tersimpan lokal.',
      );
    }

    final backend = FirefaBackendClient.instance;
    if (!kDebugMode && !backend.baseUrl.toLowerCase().startsWith('https://')) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.permanentFailure,
        message: 'Sinkronisasi produksi wajib menggunakan HTTPS.',
      );
    }
    try {
      final session = await backend.restoreSession();
      if (session == null) {
        return FirefaSyncReceipt(
          eventId: event.eventId,
          outcome: FirefaSyncOutcome.retryableFailure,
          message: 'Login backend diperlukan untuk melanjutkan sinkronisasi.',
        );
      }
      if (event.eventType == 'order.recovered' && session.role != FirefaRole.owner) {
        return FirefaSyncReceipt(
          eventId: event.eventId,
          outcome: FirefaSyncOutcome.permanentFailure,
          message: 'Pemulihan snapshot pesanan memerlukan akun Owner.',
        );
      }
      final mapping = FirefaBackendConfig.validatedOutletMap;
      final serverOutletId = FirefaBackendConfig.resolveServerOutletId(
        localOutletId: event.outletId,
        mapping: mapping,
        authorizedServerOutletIds: session.outletIds,
      );
      final deviceId = await _deviceId();
      final prefs = await SharedPreferences.getInstance();
      final versionKey = _versionKey(session.tenantId, serverOutletId, deviceId, event.orderId);
      final expectedVersion = prefs.getInt(versionKey);

      if (event.eventType == 'order.updated' && (expectedVersion == null || expectedVersion < 1)) {
        return FirefaSyncReceipt(
          eventId: event.eventId,
          outcome: FirefaSyncOutcome.permanentFailure,
          message: 'Versi server pesanan tidak diketahui. Perlu rekonsiliasi manual sebelum pembaruan dikirim.',
        );
      }

      final payload = FirefaBackendConfig.buildSyncPayload(
        event: event.toJson(),
        deviceId: deviceId,
        mapping: mapping,
        authorizedServerOutletIds: session.outletIds,
        expectedServerVersion: event.eventType == 'order.updated' ? expectedVersion : null,
      );

      Future<http.Response> post(String token) => _http.post(
        Uri.parse('${backend.baseUrl}/api/v1/sync/events'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $token',
          'idempotency-key': event.eventId,
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));

      var token = await backend.accessToken();
      if (token == null) {
        return FirefaSyncReceipt(
          eventId: event.eventId,
          outcome: FirefaSyncOutcome.retryableFailure,
          message: 'Sesi backend tidak tersedia.',
        );
      }
      var response = await post(token);
      if (response.statusCode == 401) {
        token = await backend.accessToken(forceRefresh: true);
        if (token == null) {
          return FirefaSyncReceipt(
            eventId: event.eventId,
            outcome: FirefaSyncOutcome.retryableFailure,
            message: 'Sesi berakhir; login kembali untuk melanjutkan sinkronisasi.',
          );
        }
        response = await post(token);
      }

      final Map<String, dynamic>? body = _decodeObject(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body == null ||
            body['schemaVersion'] != 1 ||
            body['eventId'] != event.eventId ||
            body['outcome'] != 'acknowledged' ||
            body['serverReference'] is! String ||
            (body['serverReference'] as String).trim().isEmpty ||
            body['globalOrderId'] is! String ||
            !FirefaBackendConfig.isUuid(body['globalOrderId'] as String) ||
            body['serverVersion'] is! int ||
            (body['serverVersion'] as int) < 1) {
          return FirefaSyncReceipt(
            eventId: event.eventId,
            outcome: FirefaSyncOutcome.retryableFailure,
            message: 'Respons server tidak memenuhi kontrak receipt; event tidak ditandai tersinkron.',
          );
        }
        final serverVersion = body['serverVersion'] as int;
        final saved = await prefs.setInt(versionKey, serverVersion);
        if (!saved) {
          return FirefaSyncReceipt(
            eventId: event.eventId,
            outcome: FirefaSyncOutcome.retryableFailure,
            message: 'Receipt diterima tetapi versi server tidak dapat disimpan lokal.',
          );
        }
        return FirefaSyncReceipt(
          eventId: event.eventId,
          outcome: FirefaSyncOutcome.acknowledged,
          serverReference: body['serverReference'] as String,
        );
      }

      if (response.statusCode == 409 && body != null) {
        final code = body['code'] ?? body['error'];
        if (code == 'idempotency_payload_mismatch') {
          return FirefaSyncReceipt(
            eventId: event.eventId,
            outcome: FirefaSyncOutcome.permanentFailure,
            message: 'ID event yang sama diterima dengan payload berbeda; perlu investigasi.',
          );
        }
        final rawSnapshot = body['serverSnapshot'];
        if (rawSnapshot is Map) {
          final snapshot = Map<String, dynamic>.from(rawSnapshot);
          final conflictServerVersion = body['serverVersion'];
          if (conflictServerVersion is int && conflictServerVersion > 0) {
            await prefs.setInt(versionKey, conflictServerVersion);
          } else {
            // Do not send future updates using a possibly stale version.
            await prefs.remove(versionKey);
          }
          final responseOutlet = body['serverOutletId'];
          final responseOrder = body['serverOrderId'];
          if (responseOutlet == serverOutletId &&
              responseOrder == event.orderId &&
              snapshot['id'] == event.orderId &&
              snapshot['outletId'] == serverOutletId) {
            snapshot['outletId'] = event.outletId;
            final kind = switch (code) {
              'stale_server_version' || 'stale_version' => FirefaConflictKind.staleServerVersion,
              'duplicate_payment' => FirefaConflictKind.duplicatePayment,
              'inventory_divergence' => FirefaConflictKind.inventoryDivergence,
              'invalid_server_response' => FirefaConflictKind.invalidServerResponse,
              _ => FirefaConflictKind.concurrentEdit,
            };
            return FirefaSyncReceipt(
              eventId: event.eventId,
              outcome: FirefaSyncOutcome.conflict,
              message: 'Konflik versi atau perubahan pesanan memerlukan rekonsiliasi.',
              serverOutletId: event.outletId,
              serverOrderId: event.orderId,
              serverSnapshot: snapshot,
              conflictKind: kind,
            );
          }
        }
        return FirefaSyncReceipt(
          eventId: event.eventId,
          outcome: FirefaSyncOutcome.permanentFailure,
          message: 'Server menolak event dengan konflik yang tidak dapat diverifikasi.',
        );
      }

      if (response.statusCode == 400 ||
          response.statusCode == 403 ||
          response.statusCode == 404 ||
          response.statusCode == 413 ||
          response.statusCode == 422) {
        return FirefaSyncReceipt(
          eventId: event.eventId,
          outcome: FirefaSyncOutcome.permanentFailure,
          message: _safeMessage(body, 'Server menolak event sinkronisasi.'),
        );
      }
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.retryableFailure,
        message: response.statusCode == 429
            ? 'Server membatasi permintaan; event akan dicoba kembali.'
            : 'Server belum dapat menerima event (HTTP ${response.statusCode}); event tetap pending.',
      );
    } on FormatException catch (error) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.permanentFailure,
        message: 'Konfigurasi atau payload sinkronisasi tidak valid: $error',
      );
    } catch (_) {
      return FirefaSyncReceipt(
        eventId: event.eventId,
        outcome: FirefaSyncOutcome.retryableFailure,
        message: 'Koneksi sinkronisasi terputus; event tetap tersimpan untuk dicoba kembali.',
      );
    }
  }

  Map<String, dynamic>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  String _safeMessage(Map<String, dynamic>? body, String fallback) {
    final message = body?['message'] ?? body?['error'];
    if (message is! String || message.trim().isEmpty) return fallback;
    final safe = message.replaceAll(RegExp(r'[\r\n]'), ' ');
    return safe.substring(0, safe.length > 180 ? 180 : safe.length);
  }
}
