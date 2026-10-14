# FIREFA Main App — Clean Rebuild

This folder is the clean rebuild of FIREFA Main App. The previous `apps/firefa_main_app` is intentionally left untouched as a reference/backup.

## Scope for the first usable version

- Preserve the existing FIREFA visual direction: modern light UI, teal accent, clean cards, responsive layout.
- Demo role entry for Owner, Manager, Cashier, and Kitchen/Bar.
- Working local POS: choose menu items, adjust quantities, checkout, create an order, and reduce product stock.
- Orders: view orders, advance order status, and cancel an active order with stock restoration.
- Tables: show occupancy derived from active dine-in orders.
- Inventory: view and receive stock.
- Reports: show totals derived from saved orders.
- Persist the local operational data on the device using SharedPreferences.

## Explicitly out of scope for this first pass

No reconciliation/conflict center, advanced audit trail, cloud sync engine, subscriptions, billing, real payment gateway, or physical printer integration. These come later only after core flows are usable.

## Platform scaffolding

After pulling this folder, generate the Flutter platform folders once:

```powershell
cd C:\Users\Intel\FIREFA-9580220\apps\firefa_main_app_rebuild
flutter create --platforms=android,web --project-name firefa_main_app_rebuild .
flutter pub get
flutter analyze
flutter test
```

The role entry and payment are local/demo behavior, not production authentication or real payment settlement. Data is local to this app installation; no cloud backend is connected yet.
