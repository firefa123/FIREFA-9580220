import 'package:flutter/material.dart';

import 'offline_indicator_controller.dart';

class OfflineBanner extends StatelessWidget {
  final OfflineIndicatorController controller;

  const OfflineBanner({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isOffline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      child: const Text(
        'Mode Offline - Pesanan akan disinkronkan kembali saat online',
      ),
    );
  }
}
