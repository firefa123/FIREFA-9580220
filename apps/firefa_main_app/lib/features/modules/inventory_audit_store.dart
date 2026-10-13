import 'package:flutter/foundation.dart';

class InventoryAuditEntry {
  final String itemId;
  final String action;
  final String actor;
  final DateTime createdAt;

  const InventoryAuditEntry({
    required this.itemId,
    required this.action,
    required this.actor,
    required this.createdAt,
  });
}

/// Compatibility model for dashboard audit summaries.
typedef InventoryAuditRecord = InventoryAuditEntry;

/// Read-oriented audit history for inventory conflict resolutions.
class InventoryAuditStore extends ChangeNotifier {
  final List<InventoryAuditEntry> _entries = [];

  List<InventoryAuditEntry> get entries => List.unmodifiable(_entries);

  void add(InventoryAuditEntry entry) {
    _entries.add(entry);
    notifyListeners();
  }
}
