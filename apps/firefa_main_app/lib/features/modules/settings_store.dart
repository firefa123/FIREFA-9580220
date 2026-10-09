import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirefaOutletSettings {
  const FirefaOutletSettings({
    required this.outletId,
    this.receiptFooter = 'Terima kasih atas kunjungan Anda!',
    this.contact = '',
    this.address = '',
    this.showTaxOnReceipt = true,
  });

  final String outletId;
  final String receiptFooter;
  final String contact;
  final String address;
  final bool showTaxOnReceipt;

  FirefaOutletSettings copyWith({
    String? receiptFooter,
    String? contact,
    String? address,
    bool? showTaxOnReceipt,
  }) => FirefaOutletSettings(
    outletId: outletId,
    receiptFooter: receiptFooter ?? this.receiptFooter,
    contact: contact ?? this.contact,
    address: address ?? this.address,
    showTaxOnReceipt: showTaxOnReceipt ?? this.showTaxOnReceipt,
  );

  Map<String, dynamic> toJson() => {
    'outletId': outletId,
    'receiptFooter': receiptFooter,
    'contact': contact,
    'address': address,
    'showTaxOnReceipt': showTaxOnReceipt,
  };

  factory FirefaOutletSettings.fromJson(Map<String, dynamic> json) =>
      FirefaOutletSettings(
        outletId: json['outletId'] as String,
        receiptFooter: json['receiptFooter'] as String? ??
            'Terima kasih atas kunjungan Anda!',
        contact: json['contact'] as String? ?? '',
        address: json['address'] as String? ?? '',
        showTaxOnReceipt: json['showTaxOnReceipt'] as bool? ?? true,
      );
}

/// Per-outlet local preferences. No backend or payment processing.
class FirefaSettingsStore extends ChangeNotifier {
  FirefaSettingsStore._();
  static final FirefaSettingsStore instance = FirefaSettingsStore._();
  static const storageKey = 'firefa_outlet_settings_v1';
  final Map<String, FirefaOutletSettings> _values = {};
  bool _initialized = false;
  Future<void> _pendingSave = Future<void>.value();

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final restored = <String, FirefaOutletSettings>{};
      for (final entry in decoded.entries) {
        final value = FirefaOutletSettings.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
        if (entry.key != value.outletId) {
          throw const FormatException('Outlet settings key mismatch');
        }
        restored[entry.key] = value;
      }
      _values..clear()..addAll(restored);
    }
    _initialized = true;
    notifyListeners();
  }

  FirefaOutletSettings forOutlet(String outletId) {
    if (!_initialized) throw StateError('Settings not initialized');
    return _values[outletId] ?? FirefaOutletSettings(outletId: outletId);
  }

  bool update(String outletId, FirefaOutletSettings value) {
    if (!_initialized || outletId.trim().isEmpty ||
        value.outletId != outletId ||
        value.receiptFooter.length > 160 ||
        value.contact.length > 80 ||
        value.address.length > 240) return false;
    _values[outletId] = value;
    notifyListeners();
    final snapshot = jsonEncode(_values.map(
      (key, settings) => MapEntry(key, settings.toJson()),
    ));
    _pendingSave = _pendingSave.catchError((Object error) {
      debugPrint('Previous settings save failed: $error');
    }).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, snapshot)) {
        throw StateError('Failed to save outlet settings');
      }
    });
    unawaited(_pendingSave.catchError((Object error) {
      debugPrint('Settings save failed: $error');
    }));
    return true;
  }

  Future<void> waitForPendingSave() => _pendingSave;
}
