import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FirefaPrinterRole { cashier, kitchen, bar }

extension FirefaPrinterRoleLabel on FirefaPrinterRole {
  String get label {
    switch (this) {
      case FirefaPrinterRole.cashier:
        return 'Kasir';
      case FirefaPrinterRole.kitchen:
        return 'Kitchen';
      case FirefaPrinterRole.bar:
        return 'Bar';
    }
  }
}

class FirefaPrinterConfig {
  final FirefaPrinterRole role;
  final String name;
  final String target;
  final bool enabled;

  const FirefaPrinterConfig({
    required this.role,
    required this.name,
    required this.target,
    required this.enabled,
  });

  FirefaPrinterConfig copyWith({
    String? name,
    String? target,
    bool? enabled,
  }) {
    return FirefaPrinterConfig(
      role: role,
      name: name ?? this.name,
      target: target ?? this.target,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'name': name,
        'target': target,
        'enabled': enabled,
      };

  factory FirefaPrinterConfig.fromJson(Map<String, dynamic> json) {
    return FirefaPrinterConfig(
      role: FirefaPrinterRole.values.byName(json['role'] as String),
      name: json['name'] as String? ?? '',
      target: json['target'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}

class FirefaPrinterStore extends ChangeNotifier {
  FirefaPrinterStore._();

  static final FirefaPrinterStore instance = FirefaPrinterStore._();
  static const _storageKey = 'firefa_printer_configs_v1';

  bool _initialized = false;
  final Map<FirefaPrinterRole, FirefaPrinterConfig> _configs = {};

  List<FirefaPrinterConfig> get configs =>
      FirefaPrinterRole.values.map(configFor).toList(growable: false);

  FirefaPrinterConfig configFor(FirefaPrinterRole role) {
    return _configs[role] ??
        FirefaPrinterConfig(
          role: role,
          name: 'Printer ${role.label}',
          target: '',
          enabled: false,
        );
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final value in decoded) {
          final config = FirefaPrinterConfig.fromJson(
            Map<String, dynamic>.from(value as Map),
          );
          _configs[config.role] = config;
        }
      } catch (error) {
        debugPrint('FIREFA printer config restore failed: $error');
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> save(FirefaPrinterConfig config) async {
    if (!_initialized) {
      await initialize();
    }

    _configs[config.role] = config;
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      FirefaPrinterRole.values.map((role) => configFor(role).toJson()).toList(),
    );

    final saved = await prefs.setString(_storageKey, payload);
    if (!saved) {
      throw StateError('Gagal menyimpan konfigurasi printer.');
    }

    notifyListeners();
  }
}
