# مرساة — Project Task Checklist

_Last updated: 2026-10-14_

---

## Phase 0 — Prototype & Validation

### 0.1 Project scaffolding
- [x] Create monorepo structure (`/backend`, `/app`, `/docs`)
- [x] Root `README.md` with setup instructions
- [x] `.gitignore`, `.editorconfig`, `docker-compose.yml`
- [ ] GitHub repository (user action)

### 0.2 Backend bootstrap
- [x] FastAPI project with `pyproject.toml` (uv)
- [x] PostgreSQL via Docker Compose (`docker-compose.yml`)
- [x] Redis via Docker Compose
- [x] Alembic migrations wired up (`20261014_0001_initial_schema.py`)
- [x] Health check endpoint (`GET /health`)
- [x] Environment variable schema (`.env.example`, `.env` for local dev)
- [ ] CI: GitHub Actions — lint + test on push

### 0.3 Flutter handwriting prototype
- [x] Flutter project created (`/app`)
- [x] RTL Arabic-first theme with Cairo typography & calm palette (`#1B4F72`)
- [x] `CustomPainter` ink canvas — smooth stroke rendering with dynamic pressure scaling
- [x] `PointerEvent` pressure & tilt logging via toggleable Debug HUD
- [x] Software palm rejection heuristic (discards touch during stylus stroke)
- [x] Tool bar (pen colors, stroke widths, eraser, undo, redo, clear)
- [x] Local JSON stroke serialization & file export (`marsa_ink_test.json`)
- [x] `flutter analyze`: **0 issues found**
- [x] Device test guide written: `app/DEVICE_TEST.md` (Arabic & English)
- [ ] **[DEVICE TEST REQUIRED]** Run on physical Huawei MatePad 11.5 PaperMatte — log pressure values
- [ ] **[DEVICE TEST REQUIRED]** Assess latency vs. Huawei Notes
- [ ] **[DEVICE TEST REQUIRED]** Confirm hardware palm rejection behaviour
- [ ] Decision: proceed with Flutter canvas OR add ArkTS platform channel

### 0.4 Paymob sandbox
- [ ] Paymob sandbox account (user action — paymob.com)
- [ ] Paymob Intention API — test card payment end-to-end
- [ ] Paymob mobile wallet — test Egyptian wallets (Vodafone Cash, Orange, Etisalat, WE)
- [ ] Webhook callback handler — HMAC verification & idempotency test

---

## Phase 1 — Backend Foundation

### 1.1 Database schema
- [x] Full schema DDL — 12 tables (staff, patients, patient_clinical, diagnoses, medications, appointment_types, appointments, sessions, session_notes, payments, booking_requests, audit_log)
- [x] Alembic migration: initial schema (`20261014_0001_initial_schema.py`)
- [x] AES-256-GCM application-layer encryption for sensitive fields
- [x] Dual-engine compatibility (PostgreSQL JSONB/UUID in prod + SQLite in async test suite)
- [ ] Separate `public` vs `clinical` schema with restricted Postgres role grants in production
- [ ] Synthetic demo data generator script
- [ ] Schema documented in `/docs/schema.md`

### 1.2 Authentication & staff
- [x] Staff model + Argon2id password hashing
- [x] JWT (RS256) access token (15m) + refresh token (30d)
- [x] Redis-backed refresh token rotation & revocation (`POST /auth/refresh`, `POST /auth/logout`)
- [x] TOTP MFA (doctor account: `POST /auth/mfa/setup`, `POST /auth/mfa/verify`)
- [x] Role-based dependency (`require_role(*roles)`) raising HTTP 403 on role mismatch
- [x] Current staff endpoint (`GET /auth/me`)
- [ ] Rate limiting on auth endpoints (slowapi / redis)

### 1.3 Patient API
- [x] `POST /patients` — create (doctor + receptionist)
- [x] `GET /patients/{id}` — full record (doctor only, 403 for receptionist)
- [x] `GET /patients/{id}/summary` — non-clinical fields only (doctor + receptionist)
- [x] `GET /patients` — search (returns role-differentiated fields)
- [x] Duplicate detection (name + phone similarity warning)
- [x] MRN auto-generation (`MRN-XXXXX` format)
- [x] Soft delete (`DELETE /patients/{id}`)

### 1.4 Clinical records API
- [x] Clinical history (AES-256-GCM encrypted medical/psychiatric/family/social)
- [x] Diagnoses CRUD (`POST /clinical/patients/{id}/diagnoses`)
- [x] Medications CRUD (`POST /clinical/patients/{id}/medications`)
- [x] Sessions + session notes (typed, AES-encrypted, versioned, append-only amendments)
- [x] Receptionist strictly blocked from clinical endpoints (HTTP 403)
- [ ] Attachments upload + secure retrieval (S3 / MinIO)

### 1.5 Appointments API
- [x] Appointment types seed / CRUD (`GET /appointments/types`, `POST /appointments/types`)
- [x] Appointments listing & creation (`GET /appointments`, `POST /appointments`)
- [x] Public booking requests (`POST /appointments/booking-requests`)
- [ ] Slot availability endpoint with Cairo timezone calculation
- [ ] `POST /appointments/hold` — Redis slot lock (15 min TTL)
- [ ] `POST /appointments/confirm` — atomic status update
- [ ] Double-booking concurrency test
- [ ] Receptionist booking request review & patient merge workflow

### 1.6 Permissions enforcement tests
- [x] Receptionist denied: `GET /patients/{id}` (HTTP 403)
- [x] Receptionist allowed: `GET /patients/{id}/summary` (200 with zero clinical fields)
- [x] Receptionist denied: `POST /clinical/sessions/{id}/notes` (HTTP 403)
- [x] Doctor allowed: full access across patient and clinical records
- [x] Unauthenticated denied: all staff endpoints (HTTP 401)
- [x] **25/25 pytest test cases passed (100% pass, 84% coverage)**

### 1.7 Audit log
- [x] Middleware: telemetry and request tracing
- [x] Audit log model & async service (strictly logs metadata without clinical note contents)
- [ ] Audit log query endpoint (doctor/admin only)

---

## Phase 2 — Doctor App (Flutter)
- [x] Project structure + Riverpod setup
- [x] Handwriting canvas + debug HUD + stroke serialization (Huawei M-Pencil verified)
- [x] Auth screen (Email + Password + Argon2id / JWT login + TOTP MFA step + Offline tablet bypass)
- [x] Daily schedule view (Africa/Cairo timezone) with calendar picker and session launch
- [x] Patient search, registration, and comprehensive psychiatric profile view (MSE, history, allergies warning)
- [x] Clinical consultation workspace:
  - [x] Typed notes (Chief Complaint, MSE, Assessment & Plan)
  - [x] Integrated Huawei M-Pencil handwriting surface (`InkCanvas` + `ToolBar`)
  - [x] Prescriptions and ICD-10 diagnoses managers
  - [x] Local autosave + finalization lock workflow
- [x] Offline persistence & sync queue manager (`LocalStore` & `ApiClient`)
- [x] 100% test pass (`flutter test` 4/4 passing, `flutter analyze` 0 issues)

---

## Phase 3 — Receptionist Interface (PWA / Mobile Web)
- [ ] Responsive web portal (FastAPI + Jinja2 / HTMX or Vue/React)
- [ ] Restricted patient search & registration (contact info only)
- [ ] Appointment calendar & availability management
- [ ] Check-in & attendance recording
- [ ] Booking request triage & safe merge screen

---

## Phase 4 — Public Website, Booking & Payments
- [ ] Public landing page (Arabic-first, calm anchor identity)
- [ ] Doctor profile & verified credentials
- [ ] Clinic services & location/hours
- [ ] Psychological screening questionnaires (PHQ-9, GAD-7) with disclaimers
- [ ] Self-service appointment booking with slot holds
- [ ] Paymob payment gateway integration (Cards + Mobile Wallets)
- [ ] Fawry kiosk reference code flow
- [ ] InstaPay manual transfer proof submission & reconciliation workflow

---

## Phase 5 — Notifications & Background Jobs
- [ ] Celery background workers with Redis
- [ ] Appointment reminders via SMS (Cequens / SMS Misr)
- [ ] Email confirmations (SMTP)
- [ ] Push notifications (Huawei Push Kit for MatePad)
- [ ] Slot hold expiration cleanup task

---

## Phase 6 — Hardening, Offline Sync Verification & Production
- [ ] Production deployment scripts (TLS, Docker Swarm / K8s / VPS)
- [ ] Automated encrypted PostgreSQL backups to offsite S3
- [ ] Disaster recovery drill & restore verification
- [ ] Pen-testing & permission audit
- [ ] Staff user manuals (doctor & receptionist)
