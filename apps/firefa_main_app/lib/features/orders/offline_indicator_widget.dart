import 'package:flutter/material.dart';
import 'offline_status.dart';

class OfflineIndicatorWidget extends StatelessWidget {
  final OfflineStatus status;

  const OfflineIndicatorWidget({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    if (!status.isOffline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      child: const Text(
        'Mode Offline - Pesanan akan disinkronkan saat koneksi tersedia',
      ),
    );
  }
}
