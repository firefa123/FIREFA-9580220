# FIREFA Stage 8 — Finalization and handover

Audit date: 2026-10-16  
Repository: `firefa123/FIREFA-9580220`  
Release branch: `development`  
Base commit audited: `0f6a8c8920fcbc9a1f58b713a40939b558697ebd`

## 1. Final audit and cleanup decision

The repository tree was reviewed from the Stage 7 commit. The active app roots are only `apps/firefa_main_app` and `apps/firefa_staff_app`; the former rebuild prototype is not present in this tree. The audit found 248 Dart source files and 54 Dart test files in the two Flutter apps. The most recent CI before this handover reported clean `flutter analyze` for both apps and passed their complete test suites.

No additional source file was deleted in Stage 8. The repository-wide reference evidence available from the remote tree did not prove any further file to be unreferenced safely. A file merely lacking a direct import can still be reached through route registration, reflection, generated code, tests, or a user-facing workflow. The safe result is therefore **zero speculative deletions**, not mass cleanup. Existing POS, inventory, purchasing, transaction/payment, staff management, attendance, audit trail, offline sync, conflict resolution, printer configuration, and backup/restore code were preserved.

No local workstation working tree was available for inspection. This audit does not claim to have removed untracked files, local backups, or local changes from the user's computer. Do not run `git clean`, `git reset --hard`, or delete `.bak` files without first inspecting and classifying them.

## 2. Commands to run and build

Run from the repository root in PowerShell.

### Main Flutter app

```powershell
cd apps/firefa_main_app
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter run
# Release artifacts:
flutter build apk --release
flutter build web --release
cd ../..
```

### Staff Flutter app

```powershell
cd apps/firefa_staff_app
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter run -d chrome
cd ../..
```

### Backend — local development

Requirements: Node.js 22+ and PostgreSQL 16+ (or Docker Compose).

```powershell
cd backend
npm install
$env:DATABASE_URL="postgresql://firefa:YOUR_LOCAL_PASSWORD@localhost:5432/firefa"
$env:JWT_SECRET="REPLACE_WITH_AT_LEAST_32_RANDOM_CHARACTERS"
$env:BOOTSTRAP_TOKEN="REPLACE_WITH_ANOTHER_32_RANDOM_SECRET"
npm run typecheck
npm run build
npm run db:migrate
npm test
npm start
```

For the PostgreSQL-backed integration suite, set `TEST_DATABASE_URL` to a disposable database whose name includes `test`, apply migrations to it, and never point it at production data. Under `NODE_ENV=test`, missing/unsafe test database configuration must fail rather than silently skip the integration suite.

### Self-managed backend deployment

1. Install Docker Engine and the Docker Compose plugin on the target host.
2. At the repository root, copy `.env.example` to `.env`. Replace every placeholder with a unique secret. `JWT_SECRET` and `BOOTSTRAP_TOKEN` must each be at least 32 characters. Use a URL-safe `POSTGRES_PASSWORD`.
3. Start the stack:
   ```powershell
   docker compose -f docker-compose.backend.yml config
   docker compose -f docker-compose.backend.yml up --build -d
   docker compose -f docker-compose.backend.yml ps
   ```
4. Verify from the host:
   ```powershell
   Invoke-WebRequest http://127.0.0.1:3000/health/live
   Invoke-WebRequest http://127.0.0.1:3000/health/ready
   ```
5. Review `docker compose -f docker-compose.backend.yml logs --tail 200 api` and confirm migrations/readiness succeeded.
6. Keep PostgreSQL and API bound to loopback/private network. Configure a TLS reverse proxy and firewall before production client traffic. Do not expose PostgreSQL directly to the internet.
7. Store `.env` securely outside version control. Rotate bootstrap credentials after initial owner provisioning and follow the operational secret-rotation policy.

The Compose API container runs migrations before starting the server. The PostgreSQL data volume is `firefa_postgres_data`; protect it with scheduled off-host backups and a tested restore procedure.

### Backup and restore

PowerShell commands from the repository root (PostgreSQL client tools must be installed):

```powershell
$env:DATABASE_URL="postgresql://firefa:YOUR_PASSWORD@localhost:5432/firefa"
./backend/scripts/db-backup.ps1
# Restore ONLY to an explicitly checked target database:
./backend/scripts/db-restore.ps1 -BackupFile .\backups\firefa-YYYYMMDDTHHMMSSZ.dump -ConfirmRestore
```

Restore is destructive to the target database. Verify the target connection and rehearse restore on a disposable database first.

## 3. CI evidence and test report

The final commit and run links will be recorded here after the Stage 8 pull request is merged and the post-merge workflows complete. Do not treat an earlier commit's green result as evidence for a later commit.

Required checks:
- Flutter workflow: `flutter pub get`, `flutter analyze`, full `flutter test --reporter expanded`, and `flutter build web --release` for both apps. Android APK build runs only when that app has an `android/` platform scaffold; the Staff App currently does not, so its APK target is explicitly not applicable rather than a hidden test skip.
- Backend workflow: Node.js 22, typecheck, build, PostgreSQL migrations, backend unit/integration tests, idempotent migration rerun, schema table verification, API readiness, and Docker build.

A passing CI run validates code and an ephemeral PostgreSQL service only. It is not proof of a successful production deployment, live public network access, TLS configuration, or a real backup/restore drill.

## 4. Deployment and product boundaries

- Main App remains the primary Owner/operator app. Do not replace it with a rebuild prototype or overhaul its UI as part of cleanup.
- Staff App remains a separate local UI prototype; its attendance/task data is local and not authoritative server attendance.
- Main App local-first behavior remains the default. Backend login/sync is opt-in; production endpoint configuration and a real production deployment have not been verified.
- Local payment state and cashier-reported cash/refunds do not equal settlement verification by a bank/payment provider.
- Printer configuration does not prove that physical printer hardware has been connected and tested.
- Staff CRUD, attendance/geofence API, BON receivable settlement, external payment-provider verification, and automatic migration of all local menu/inventory data are not implemented in the backend foundation.
- Production migration, real server backup/restore, public TLS endpoint tests, and multi-device acceptance on real outlets remain release blockers until performed in the target environment.

## 5. Migration note

The migration directory contains both `006_owner_cashier_roles_only.sql` and `006_payment_verification_audit.sql`. The migration runner orders files lexicographically and records their exact filenames in `schema_migrations`; CI has successfully applied the current set and rerun the migration command. Do not rename an already-applied migration casually: it can cause the runner to treat it as a new migration. If numbering is normalized later, use a forward-only migration plan that preserves existing filenames/history.

## 6. Stage 8 status

- Reference audit: completed for the current remote repository tree.
- Cleanup: no further deletion was justified by the evidence; no speculative files removed.
- Deployment/run instructions: documented above and in `backend/README.md`.
- The first expanded build CI exposed a real packaging mismatch: the Staff App has no `android/` platform directory, so `flutter build apk` cannot run there. The workflow now reports this as not applicable only for apps without that platform, while building web for both apps and APK for apps that contain Android scaffolding. The failing run is retained as evidence and was not counted as a pass.
- Analyze, tests, web builds, applicable Android APK build, backend tests, PostgreSQL migration/readiness, and Docker build: pending final rerun after the workflow correction.
- Final handover: only complete after the corrected final commit has green Flutter and backend workflows and post-merge workflows are green.
