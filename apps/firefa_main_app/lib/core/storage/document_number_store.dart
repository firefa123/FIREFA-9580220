import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FirefaDocumentNumberStore {
  FirefaDocumentNumberStore({this._preferences});

  static const storageKey = 'firefa_document_sequences_v1';
  static const Map<String, String> prefixes = {
    'transaction': 'TRX',
    'expense': 'EXP',
    'purchase_order': 'PO',
    'goods_receipt': 'GR',
    'refund': 'RFD',
    'inventory': 'INV',
    'shift': 'SHF',
  };

  SharedPreferences? _preferences;
  Future<void> _queue = Future<void>.value();

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<String> next({
    required String outletId,
    required String documentType,
    DateTime? date,
  }) {
    final completer = Completer<String>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await _nextUnlocked(
          outletId: outletId,
          documentType: documentType,
          date: date ?? DateTime.now(),
        ));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<String> _nextUnlocked({
    required String outletId,
    required String documentType,
    required DateTime date,
  }) async {
    final outlet = outletId.trim();
    final type = documentType.trim().toLowerCase();
    final prefix = prefixes[type];
    if (outlet.isEmpty || prefix == null) {
      throw ArgumentError('Outlet atau tipe dokumen tidak valid.');
    }
    final day = '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final sequenceKey = '$outlet|$type|$day';
    final prefs = await _prefs;
    final raw = prefs.getString(storageKey);
    final sequences = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final previous = sequences[sequenceKey] as int? ?? 0;
    final nextValue = previous + 1;
    sequences[sequenceKey] = nextValue;
    if (!await prefs.setString(storageKey, jsonEncode(sequences))) {
      throw StateError('Gagal menyimpan nomor dokumen.');
    }
    return '$prefix-$day-${nextValue.toString().padLeft(6, '0')}';
  }
}
