import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FirefaHybridConnectionState {
  online,
  offline,
  syncing,
}

/// App-level hybrid connectivity state.
///
/// This represents FIREFA cloud readiness, not merely device internet access.
/// Until an authenticated cloud transport is configured, the safe default is
/// offline/local mode.
class FirefaHybridSyncStatus extends ChangeNotifier {
  FirefaHybridSyncStatus._();

  static final FirefaHybridSyncStatus instance = FirefaHybridSyncStatus._();

  static const _lastSyncKey = 'firefa_last_successful_sync_v1';

  FirefaHybridConnectionState _state = FirefaHybridConnectionState.offline;
  DateTime? _lastSyncAt;
  String? _message;
  bool _initialized = false;

  FirefaHybridConnectionState get state => _state;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get message => _message;
  bool get isOnline => _state == FirefaHybridConnectionState.online;
  bool get isOffline => _state == FirefaHybridConnectionState.offline;
  bool get isSyncing => _state == FirefaHybridConnectionState.syncing;

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncKey);
    if (raw != null && raw.isNotEmpty) {
      _lastSyncAt = DateTime.tryParse(raw)?.toLocal();
    }

    _initialized = true;
    notifyListeners();
  }

  void setOnline({String? message}) {
    _state = FirefaHybridConnectionState.online;
    _message = message;
    notifyListeners();
  }

  void setOffline({String? message}) {
    _state = FirefaHybridConnectionState.offline;
    _message = message;
    notifyListeners();
  }

  void beginSync({String? message}) {
    _state = FirefaHybridConnectionState.syncing;
    _message = message;
    notifyListeners();
  }

  Future<void> markSynced({String? message}) async {
    _lastSyncAt = DateTime.now();
    _state = FirefaHybridConnectionState.online;
    _message = message;

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _lastSyncKey,
      _lastSyncAt!.toUtc().toIso8601String(),
    );

    if (!saved) {
      debugPrint('FIREFA: gagal menyimpan last sync time.');
    }

    notifyListeners();
  }

  void markSyncFailed({String? message}) {
    _state = FirefaHybridConnectionState.offline;
    _message = message ?? 'Sinkronisasi gagal. Data tetap aman di lokal.';
    notifyListeners();
  }
}
