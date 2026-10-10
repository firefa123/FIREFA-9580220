import 'package:flutter/material.dart';

import '../../sync/hybrid_sync_status.dart';

class HybridStatusBadge extends StatefulWidget {
  const HybridStatusBadge({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<HybridStatusBadge> createState() => _HybridStatusBadgeState();
}

class _HybridStatusBadgeState extends State<HybridStatusBadge> {
  final status = FirefaHybridSyncStatus.instance;

  @override
  void initState() {
    super.initState();
    status.addListener(_refresh);
  }

  @override
  void dispose() {
    status.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status.state) {
      FirefaHybridConnectionState.online =>
        ('Online', Colors.green, Icons.cloud_done_outlined),
      FirefaHybridConnectionState.offline =>
        ('Offline Mode', Colors.red, Icons.cloud_off_outlined),
      FirefaHybridConnectionState.syncing =>
        ('Syncing', Colors.amber.shade800, Icons.sync),
    };

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: widget.compact ? 18 : 16, color: color),
        if (!widget.compact) ...[
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    return Tooltip(
      message: status.message ?? label,
      child: widget.compact
          ? child
          : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: child,
            ),
    );
  }
}
