# FIREFA Stage 6 — Payment, Transaction History, and Refund Audit

## State semantics

- A local POS payment is **reported**, not verified. The local `paid` state alone is not proof of server settlement.
- The backend creates payment rows with status `reported`. Only an authenticated Owner can verify a report; verification records actor and timestamp and creates immutable payment-event and audit-log entries.
- An unverified payment report never changes the authoritative order payment status to `paid`. Client sync payloads cannot promote reported cash to verified payment.
- BON creates an open receivable and leaves the order unpaid. Verified collections reduce the outstanding amount; partial collections use `partially_paid`, and full collection closes the receivable.
- Refunds are reported separately. Only an Owner can verify them. A partial verified refund leaves the order paid; only verified refunds cumulatively equal to the order total can set the order status to `refunded`.
- Client sync cannot create a verified refund or change the authoritative refund total. Refunds must use the refund API.
- The UI, receipt, and CSV include payment/refund verification state. Loyalty and product-sales reports include only verified payments.

## API

All routes require a valid Bearer token and an outlet membership. Every report requires an `Idempotency-Key` header (8–200 characters).

- `POST /api/v1/payments` — Owner/Cashier reports a payment. Allowed methods: `cash`, `card`, `bank_transfer`, `ewallet`, `other`. Returns `status: reported`, `verified: false`.
- `POST /api/v1/payments/bon` — Owner/Cashier records a BON receivable; it remains open and unpaid.
- `POST /api/v1/payments/:paymentId/verify` — Owner-only. Marks a report verified after checking remaining balance; full verified payment marks the order paid.
- `POST /api/v1/payments/:paymentId/fail` — Owner-only. Records a failed report without marking the order paid.
- `POST /api/v1/refunds` — Owner/Cashier reports a refund against verified funds.
- `POST /api/v1/refunds/:refundId/verify` — Owner-only. Verifies a refund and applies the cumulative verified refund total to the order.
- `GET /api/v1/payments/history?outletId=<uuid>&orderId=<uuid>` — Returns payments, refunds, immutable payment events, and BON receivables, including verification state.

Reports with the same idempotency key and identical payload replay the original record. Reusing a key with a different payload returns HTTP 409. Overpayments, over-refunds, unauthorized verification, cancelled orders, and reports against another outlet are rejected.

## Verification

From the repository root:

PowerShell:
```powershell
cd apps/firefa_main_app
flutter pub get
flutter analyze
flutter test
```

Backend:
```bash
cd backend
npm ci
npm run typecheck
npm test
npm run build
```

The backend CI migration suite applies migrations to a disposable PostgreSQL database, checks idempotency and required schema, runs integration tests, verifies API readiness, and builds Docker.

## Production boundary

No production server is provisioned in this project context. Passing local/CI tests does not mean payments were verified against a live bank, e-wallet provider, or production database. Provider webhooks/settlement are not claimed implemented; the Owner verification endpoint is an explicit internal verification action and remains auditable.
