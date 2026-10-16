import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/role_permissions.dart';

class FirefaBackendConfig {
  const FirefaBackendConfig._();

  static const bool enabled = bool.fromEnvironment('FIREFA_BACKEND_ENABLED');
  static const String baseUrl = String.fromEnvironment('FIREFA_API_BASE_URL');
  static const String outletMapJson = String.fromEnvironment('FIREFA_OUTLET_MAP', defaultValue: '{}');

  static Map<String, String> get outletMap {
    try {
      final decoded = jsonDecode(outletMapJson);
      if (decoded is! Map) return const {};
      return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return const {};
    }
  }

  /// Resolve a local demo/storage outlet ID to a real backend outlet ID.
  /// The target must also be present in the authenticated session's outlet IDs.
  /// This intentionally fails closed: local IDs must never be sent to the API.
  static String resolveServerOutletId({
    required String localOutletId,
    required Map<String, String> mapping,
    required Iterable<String> authorizedServerOutletIds,
  }) {
    if (localOutletId.trim().isEmpty) {
      throw ArgumentError.value(localOutletId, 'localOutletId', 'Outlet lokal wajib diisi.');
    }
    final serverOutletId = mapping[localOutletId]?.trim();
    if (serverOutletId == null || serverOutletId.isEmpty) {
      throw const FormatException('Pemetaan outlet lokal ke server belum dikonfigurasi.');
    }
    if (!authorizedServerOutletIds.contains(serverOutletId)) {
      throw const FormatException('Outlet server tidak termasuk akses akun yang sedang login.');
    }
    return serverOutletId;
  }

  /// Convert a persisted local outbox entry to the backend v1 contract.
  /// This prepares a payload only; it does not send it or mark it synchronized.
  static Map<String, dynamic> buildSyncPayload({
    required Map<String, dynamic> event,
    required String deviceId,
    required Map<String, String> mapping,
    required Iterable<String> authorizedServerOutletIds,
    int? expectedServerVersion,
  }) {
    final eventId = event['eventId'];
    final localOutletId = event['outletId'];
    final orderId = event['orderId'];
    final eventType = event['eventType'];
    final createdAt = event['createdAt'];
    final rawSnapshot = event['orderSnapshot'];
    if (eventId is! String ||
        eventId.trim().length < 16 ||
        orderId is! String ||
        orderId.trim().isEmpty ||
        createdAt is! String ||
        eventType is! String ||
        !const {'order.created', 'order.updated', 'order.recovered'}.contains(eventType) ||
        rawSnapshot is! Map) {
      throw const FormatException('Event outbox tidak sesuai kontrak sinkronisasi.');
    }
    if (eventType == 'order.updated' &&
        (expectedServerVersion == null || expectedServerVersion < 1)) {
      throw const FormatException('Versi server wajib untuk memperbarui pesanan.');
    }
    final serverOutletId = resolveServerOutletId(
      localOutletId: localOutletId is String ? localOutletId : '',
      mapping: mapping,
      authorizedServerOutletIds: authorizedServerOutletIds,
    );
    final snapshot = Map<String, dynamic>.from(rawSnapshot);
    if (snapshot['id'] != orderId || snapshot['outletId'] != localOutletId) {
      throw const FormatException('Identitas pesanan dan outlet pada snapshot tidak cocok.');
    }
    snapshot['outletId'] = serverOutletId;
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'eventId': eventId,
      'deviceId': deviceId,
      'outletId': serverOutletId,
      'orderId': orderId,
      'eventType': eventType,
      'createdAt': createdAt,
      'orderSnapshot': snapshot,
    };
    if (expectedServerVersion != null) {
      if (expectedServerVersion < 1) {
        throw ArgumentError.value(expectedServerVersion, 'expectedServerVersion');
      }
      payload['expectedServerVersion'] = expectedServerVersion;
    }
    return payload;
  }

  static bool get isConfigured =>
      enabled && baseUrl.trim().isNotEmpty && Uri.tryParse(baseUrl)?.hasAuthority == true;
}

class FirefaBackendException implements Exception {
  final String message;
  final int? statusCode;
  const FirefaBackendException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class FirefaBackendSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
  final String displayName;
  final String tenantId;
  final FirefaRole role;
  final List<String> outletIds;

  const FirefaBackendSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.displayName,
    required this.tenantId,
    required this.role,
    required this.outletIds,
  });

  factory FirefaBackendSession.fromJson(Map<String, dynamic> json) {
    final role = switch (json['role']) {
      'owner' => FirefaRole.owner,
      'cashier' => FirefaRole.cashier,
      _ => throw const FormatException('Role akun tidak diizinkan di Main App.'),
    };
    final user = Map<String, dynamic>.from(json['user'] as Map);
    return FirefaBackendSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      userId: user['id'] as String,
      email: user['email'] as String,
      displayName: user['displayName'] as String,
      tenantId: json['tenantId'] as String,
      role: role,
      outletIds: (json['outletIds'] as List).cast<String>(),
    );
  }
}

/// Authentication stays opt-in. No credentials or production secrets are
/// embedded in the Flutter source.
class FirefaBackendClient {
  FirefaBackendClient._();
  static final FirefaBackendClient instance = FirefaBackendClient._();

  static const _accessKey = 'firefa_backend_access_token';
  static const _refreshKey = 'firefa_backend_refresh_token';
  static const _sessionKey = 'firefa_backend_session_v1';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final http.Client _http = http.Client();

  String get baseUrl => FirefaBackendConfig.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  Future<FirefaBackendSession> login({
    required String email,
    required String password,
  }) async {
    _requireConfigured();
    final response = await _http.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw FirefaBackendException(_responseMessage(response, 'Login gagal.'), statusCode: response.statusCode);
    }
    final session = FirefaBackendSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
    await _secure.write(key: _accessKey, value: session.accessToken);
    await _secure.write(key: _refreshKey, value: session.refreshToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode({
      'userId': session.userId,
      'email': session.email,
      'displayName': session.displayName,
      'tenantId': session.tenantId,
      'role': session.role.name,
      'outletIds': session.outletIds,
    }));
    return session;
  }

  Future<String?> accessToken({bool forceRefresh = false}) async {
    var token = await _secure.read(key: _accessKey);
    if (!forceRefresh && token != null) return token;
    final refresh = await _secure.read(key: _refreshKey);
    if (refresh == null) return null;
    final response = await _http.post(
      Uri.parse('$baseUrl/api/v1/auth/refresh'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'refreshToken': refresh}),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      await logout();
      return null;
    }
    final json = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    token = json['accessToken'] as String;
    await _secure.write(key: _accessKey, value: token);
    await _secure.write(key: _refreshKey, value: json['refreshToken'] as String);
    return token;
  }

  Future<void> logout() async {
    final refresh = await _secure.read(key: _refreshKey);
    if (FirefaBackendConfig.isConfigured && refresh != null) {
      try {
        await _http.post(
          Uri.parse('$baseUrl/api/v1/auth/logout'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  void _requireConfigured() {
    if (!FirefaBackendConfig.isConfigured) {
      throw const FirefaBackendException('Backend belum dikonfigurasi.');
    }
    if (!baseUrl.toLowerCase().startsWith('https://') && !kDebugMode) {
      throw const FirefaBackendException('Backend production wajib menggunakan HTTPS.');
    }
  }

  String _responseMessage(http.Response response, String fallback) {
    try {
      final json = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      return switch (json['error']) {
        'invalid_credentials' => 'Email atau password salah.',
        'unauthorized' => 'Sesi tidak valid. Silakan login kembali.',
        'invalid_request' => 'Data permintaan tidak valid.',
        final String value => value.replaceAll('_', ' '),
        _ => fallback,
      };
    } catch (_) {
      return fallback;
    }
  }
}
