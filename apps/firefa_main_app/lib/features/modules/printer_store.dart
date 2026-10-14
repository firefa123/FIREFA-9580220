import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FirefaPrinterRole { cashier }

extension FirefaPrinterRoleLabel on FirefaPrinterRole {
  String get label => 'Kasir';
}

class FirefaPrinterConfig {
  final FirefaPrinterRole role;
  final String outletId;
  final String name;
  final String target;
  final bool enabled;

  const FirefaPrinterConfig({
    required this.role,
    required this.outletId,
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
      outletId: outletId,
      name: name ?? this.name,
      target: target ?? this.target,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'outletId': outletId,
        'name': name,
        'target': target,
        'enabled': enabled,
      };

  factory FirefaPrinterConfig.fromJson(Map<String, dynamic> json) {
    return FirefaPrinterConfig(
      role: FirefaPrinterRole.values.byName(json['role'] as String),
      outletId: json['outletId'] as String? ?? 'outlet-001',
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
  final Map<String, FirefaPrinterConfig> _configs = {};

  String _key(String outletId, FirefaPrinterRole role) =>
      '$outletId:${role.name}';

  List<FirefaPrinterConfig> get configs => configsForOutlet('outlet-001');

  List<FirefaPrinterConfig> configsForOutlet(String outletId) =>
      FirefaPrinterRole.values
          .map((role) => configFor(role, outletId: outletId))
          .toList(growable: false);

  FirefaPrinterConfig configFor(
    FirefaPrinterRole role, {
    String outletId = 'outlet-001',
  }) {
    return _configs[_key(outletId, role)] ??
        FirefaPrinterConfig(
          role: role,
          outletId: outletId,
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
          try {
            final config = FirefaPrinterConfig.fromJson(
              Map<String, dynamic>.from(value as Map),
            );
            // Ignore legacy kitchen/bar configs while preserving cashier settings.
            _configs[_key(config.outletId, config.role)] = config;
          } on ArgumentError {
            continue;
          } on TypeError {
            continue;
          }
        }
      } catch (error) {
        debugPrint('FIREFA printer config restore failed: $error');
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> save(FirefaPrinterConfig config) async {
    if (!_initialized) await initialize();

    _configs[_key(config.outletId, config.role)] = config;
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      _configs.values.map((config) => config.toJson()).toList(),
    );

    final saved = await prefs.setString(_storageKey, payload);
    if (!saved) throw StateError('Gagal menyimpan konfigurasi printer.');

    notifyListeners();
  }
}
