class OutletManagementController {
  final List<String> activeOutlets = [];

  void addOutlet(String outletId) {
    activeOutlets.add(outletId);
  }
}
