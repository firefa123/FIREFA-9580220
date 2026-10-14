import 'package:flutter/material.dart';

import '../../../modules/orders_page.dart' as integrated;

/// Compatibility route for older navigation references.
/// The main module owns the persistent, outlet-scoped order workflow.
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) => const integrated.OrdersPage();
}
