# FIREFA Main App — Clean Rebuild

This is the clean rebuild of FIREFA Main App. The previous `apps/firefa_main_app` remains untouched as a reference and rollback point.

## First usable Main App scope

- Modern light UI in the existing FIREFA visual direction.
- Role entry for Owner, Manager, Cashier, and Kitchen/Bar.
- POS: menu selection, quantity controls, dine-in/take-away, table selection, stock validation, and checkout.
- Order management: view orders, advance statuses, cancel orders, and restore stock on cancellation.
- Tables: occupancy follows active dine-in orders.
- Menu management: add/edit product name, category, and price.
- Inventory: see stock and receive stock.
- Reports: totals derived from locally saved orders.
- Receipts: preview, copy, and print/save as PDF through the operating system's print flow.
- Printer configuration for cashier/kitchen/bar and basic business name/footer settings.
- Operational data and settings persist locally through SharedPreferences.

## Setup on Windows

Do not run `flutter create .` inside this folder: it could replace the custom `lib/main.dart`.

Create platform scaffolding in a temporary sibling folder, then copy only the platform folders:

```powershell
cd C:\Users\Intel\FIREFA-9580220\apps
flutter create --platforms=android,web --project-name firefa_main_app_rebuild _firefa_platform_scaffold
Copy-Item -Recurse -Force .\_firefa_platform_scaffold\android .\firefa_main_app_rebuild\
Copy-Item -Recurse -Force .\_firefa_platform_scaffold\web .\firefa_main_app_rebuild\
Copy-Item -Force .\_firefa_platform_scaffold\.metadata .\firefa_main_app_rebuild\
Remove-Item -Recurse -Force .\_firefa_platform_scaffold
cd .\firefa_main_app_rebuild
flutter pub get
flutter analyze
flutter test
```

## Honest current boundaries

- Role entry is demo access, not production authentication.
- Payment is simulated locally; it does not settle through a bank or QRIS gateway.
- Orders, menu, stock, and settings are local to this app installation.
- PDF printing opens the OS print/save flow. Saved printer targets are configuration only; direct device-specific routing (for example, automatic kitchen/bar printing) is not connected yet.
- Cloud backend, multi-device synchronization, tenant/subscription administration, and conflict resolution are intentionally not part of this first functional milestone. Do not present them as active.
