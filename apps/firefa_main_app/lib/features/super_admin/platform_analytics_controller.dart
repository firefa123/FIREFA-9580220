import 'platform_analytics_model.dart';

/// Summarizes platform-wide counts from explicitly supplied data sources.
/// No counts are inferred from outlet-local data or fabricated when a source
/// has not been connected.
class PlatformAnalyticsController {
  PlatformAnalyticsController({
    Iterable<String> tenantIds = const [],
    Iterable<String> outletIds = const [],
    Iterable<String> userIds = const [],
    int totalTransactions = 0,
  })  : _tenantIds = List.unmodifiable(tenantIds),
        _outletIds = List.unmodifiable(outletIds),
        _userIds = List.unmodifiable(userIds),
        _totalTransactions = totalTransactions {
    if (totalTransactions < 0) {
      throw ArgumentError.value(
        totalTransactions,
        'totalTransactions',
        'Jumlah transaksi tidak boleh negatif.',
      );
    }
  }

  final List<String> _tenantIds;
  final List<String> _outletIds;
  final List<String> _userIds;
  final int _totalTransactions;

  int _uniqueCount(Iterable<String> ids) => ids
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .length;

  PlatformAnalyticsModel getSummary() {
    return PlatformAnalyticsModel(
      totalTenants: _uniqueCount(_tenantIds),
      totalOutlets: _uniqueCount(_outletIds),
      totalUsers: _uniqueCount(_userIds),
      totalTransactions: _totalTransactions,
    );
  }
}
