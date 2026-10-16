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
  static const String outletMapJson = String.fromEnvironment(
    'FIREFA_OUTLET_MAP',
    defaultValue: '{}',
  );

  static bool isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);

  static Map<String, String> get validatedOutletMap {
    final decoded = jsonDecode(outletMapJson);
    if (decoded is! Map) {
      throw const FormatException('FIREFA_OUTLET_MAP harus berupa object JSON.');
    }
    final result = <String, String>{};
    final serverIds = <String>{};
    for (final entry in decoded.entries) {
      final localId = entry.key;
      final serverId = entry.value;
      if (localId is! String ||
          localId.trim().isEmpty ||
          serverId is! String ||
          !isUuid(serverId.trim())) {
        throw const FormatException(
          'Pemetaan outlet harus berisi ID lokal dan UUID server yang valid.',
        );
      }
      final normalized = serverId.trim().toLowerCase();
      if (!serverIds.add(normalized)) {
        throw const FormatException(
          'Satu UUID server tidak boleh dipetakan ke beberapa outlet lokal.',
        );
      }
      result[localId.trim()] = normalized;
    }
    return Map.unmodifiable(result);
  }

  static Map<String, String> get outletMap {
    try {
      return validatedOutletMap;
    } catch (_) {
      return const {};
    }
  }

  static void validateSessionOutletMapping(FirefaBackendSession session) {
    if (session.tenantId.trim().isEmpty || session.outletIds.isEmpty) {
      throw const FormatException('Akun tidak memiliki tenant atau outlet aktif.');
    }
    final mapping = validatedOutletMap;
    final authorized = session.outletIds.map((id) => id.toLowerCase()).toSet();
    if (!mapping.values.any(authorized.contains)) {
      throw const FormatException(
        'Akun berhasil diautentikasi, tetapi tidak ada outlet lokal yang dipetakan ke outlet server milik akun ini.',
      );
    }
  }

  static String resolveServerOutletId({
    required String localOutletId,
    required Map<String, String> mapping,
    required Iterable<String> authorizedServerOutletIds,
  }) {
    if (localOutletId.trim().isEmpty) {
      throw ArgumentError.value(
        localOutletId,
        'localOutletId',
        'Outlet lokal wajib diisi.',
      );
    }
    final serverOutletId = mapping[localOutletId]?.trim();
    if (serverOutletId == null || !isUuid(serverOutletId)) {
      throw const FormatException(
        'Pemetaan outlet lokal ke server belum dikonfigurasi dengan UUID valid.',
      );
    }
    final authorized = authorizedServerOutletIds.map((id) => id.toLowerCase()).toSet();
    if (!authorized.contains(serverOutletId.toLowerCase())) {
      throw const FormatException(
        'Outlet server tidak termasuk akses akun yang sedang login.',
      );
    }
    return serverOutletId.toLowerCase();
  }

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
        DateTime.tryParse(createdAt) == null ||
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
      throw const FormatException(
        'Identitas pesanan dan outlet pada snapshot tidak cocok.',
      );
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

  static const String inventoryItemMapJson = String.fromEnvironment(
    'FIREFA_INVENTORY_ITEM_MAP',
    defaultValue: '{}',
  );

  static Map<String, String> get validatedInventoryItemMap {
    final decoded = jsonDecode(inventoryItemMapJson);
    if (decoded is! Map) {
      throw const FormatException('FIREFA_INVENTORY_ITEM_MAP harus berupa object JSON.');
    }
    final result = <String, String>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String ||
          (entry.key as String).trim().isEmpty ||
          entry.value is! String ||
          !isUuid((entry.value as String).trim())) {
        throw const FormatException(
          'Pemetaan inventori harus berisi ID lokal dan UUID server yang valid.',
        );
      }
      result[(entry.key as String).trim()] = (entry.value as String).trim().toLowerCase();
    }
    if (result.values.toSet().length != result.length) {
      throw const FormatException('UUID item server tidak boleh dipakai oleh beberapa item lokal.');
    }
    return Map.unmodifiable(result);
  }

  static String resolveServerInventoryItemId({
    required String localItemId,
    required Map<String, String> mapping,
  }) {
    final id = mapping[localItemId]?.trim();
    if (id == null || !isUuid(id)) {
      throw const FormatException(
        'Pemetaan item inventori lokal ke UUID server belum dikonfigurasi.',
      );
    }
    return id.toLowerCase();
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
    final rawUser = json['user'];
    if (rawUser is! Map) {
      throw const FormatException('Identitas user pada respons login tidak valid.');
    }
    final user = Map<String, dynamic>.from(rawUser);
    final userId = user['id'];
    final email = user['email'];
    final displayName = user['displayName'];
    final tenantId = json['tenantId'];
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final rawOutletIds = json['outletIds'];
    if (userId is! String ||
        !FirefaBackendConfig.isUuid(userId) ||
        email is! String ||
        email.trim().isEmpty ||
        displayName is! String ||
        displayName.trim().isEmpty ||
        tenantId is! String ||
        !FirefaBackendConfig.isUuid(tenantId) ||
        accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        rawOutletIds is! List ||
        rawOutletIds.isEmpty ||
        rawOutletIds.any((id) => id is! String || !FirefaBackendConfig.isUuid(id))) {
      throw const FormatException(
        'Respons sesi login tidak lengkap atau memiliki identitas yang tidak valid.',
      );
    }
    final outletIds = rawOutletIds.cast<String>();
    if (outletIds.toSet().length != outletIds.length) {
      throw const FormatException('Respons sesi berisi outlet duplikat.');
    }
    return FirefaBackendSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
      email: email,
      displayName: displayName,
      tenantId: tenantId,
      role: role,
      outletIds: List.unmodifiable(outletIds),
    );
  }

  factory FirefaBackendSession.fromStored({
    required Map<String, dynamic> json,
    required String accessToken,
    required String refreshToken,
  }) {
    return FirefaBackendSession.fromJson({
      'role': json['role'],
      'tenantId': json['tenantId'],
      'outletIds': json['outletIds'],
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': {
        'id': json['userId'],
        'email': json['email'],
        'displayName': json['displayName'],
      },
    });
  }
}

class FirefaBackendClient {
  FirefaBackendClient._();
  static final FirefaBackendClient instance = FirefaBackendClient._();

  static const _accessKey = 'firefa_backend_access_token';
  static const _refreshKey = 'firefa_backend_refresh_token';
  static const _sessionKey = 'firefa_backend_session_v1';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final http.Client _http = http.Client();

  String get baseUrl =>
      FirefaBackendConfig.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

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
      throw FirefaBackendException(
        _responseMessage(response, 'Login gagal.'),
        statusCode: response.statusCode,
      );
    }
    final session = FirefaBackendSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
    FirefaBackendConfig.validateSessionOutletMapping(session);
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

  Future<FirefaBackendSession?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final stored = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final token = await accessToken();
      final refresh = await _secure.read(key: _refreshKey);
      if (token == null || refresh == null || refresh.isEmpty) return null;
      final session = FirefaBackendSession.fromStored(
        json: stored,
        accessToken: token,
        refreshToken: refresh,
      );
      FirefaBackendConfig.validateSessionOutletMapping(session);
      return session;
    } on FormatException {
      await logout();
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<String> resolveAuthorizedServerOutletId(String localOutletId) async {
    final session = await restoreSession();
    if (session == null) {
      throw const FirefaBackendException('Sesi backend tidak tersedia; login kembali.');
    }
    return FirefaBackendConfig.resolveServerOutletId(
      localOutletId: localOutletId,
      mapping: FirefaBackendConfig.validatedOutletMap,
      authorizedServerOutletIds: session.outletIds,
    );
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
    final nextToken = json['accessToken'];
    final nextRefresh = json['refreshToken'];
    if (nextToken is! String || nextToken.isEmpty ||
        nextRefresh is! String || nextRefresh.isEmpty) {
      await logout();
      return null;
    }
    token = nextToken;
    await _secure.write(key: _accessKey, value: token);
    await _secure.write(key: _refreshKey, value: nextRefresh);
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
