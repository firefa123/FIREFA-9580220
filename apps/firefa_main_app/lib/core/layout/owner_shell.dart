import 'package:flutter/material.dart';

import 'owner_sidebar.dart';

class OwnerShell extends StatefulWidget {
  final Widget child;

  const OwnerShell({
    super.key,
    required this.child,
  });

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          OwnerSidebar(
            selectedIndex: selectedIndex,
            onSelected: (value) {
              setState(() => selectedIndex = value);
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}
