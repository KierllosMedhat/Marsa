# مرساة — Decision Log

Decisions are recorded here to preserve rationale across conversations.
Newest entries are at the top.

---

## 2026-10-14 — Architecture approved

### DECISION-001: Flutter for the doctor app (not native HarmonyOS)
**Decision**: Use Flutter (`flutter_ohos` community port) rather than native ArkTS for the doctor app.  
**Rationale**: Single codebase covers Huawei tablet (primary) + Android phone companion. Native ArkTS would require two full codebases and ArkTS expertise.  
**Risk**: Huawei Pen Kit stylus features (predictive inking, shape recognition) are ArkTS-only and won't be available in Flutter without a platform channel bridge.  
**Mitigation**: Phase 0 prototype will test whether Flutter `PointerEvent` pressure data and latency are acceptable. If not, we add a narrow ArkTS platform channel just for the ink canvas.  
**Gate**: Go/no-go on this decision after Phase 0 device test.

---

### DECISION-002: InstaPay is manual-only
**Decision**: InstaPay is implemented as a manual bank transfer workflow, not automated.  
**Rationale**: Research confirmed InstaPay Egypt operates on the CBE's IPN (Instant Payment Network) as a P2P system. No merchant payment collection API is publicly available. Any third-party claiming otherwise is not connected to the official IPN.  
**Implementation**: Patient is shown clinic's InstaPay QR/phone + unique reference code. Slot hold is extended 4 hours. Receptionist manually confirms receipt in admin panel.  
**Label in UI**: "تحويل بنكي يدوي — الموعد مؤقت حتى تأكيد الدفع من العيادة" (Manual bank transfer — appointment is provisional until clinic confirms payment).

---

### DECISION-003: Paymob as primary payment gateway
**Decision**: Paymob covers cards (Visa/MC/Amex/Meeza) and all 4 Egyptian mobile wallets (Vodafone Cash, Orange Cash, Etisalat Cash, WE Pay).  
**Rationale**: Single integration covers the widest set of automated payment methods in Egypt. Paymob has a Flutter-accessible API, sandbox, and HMAC webhook validation.  
**Fawry**: Added as secondary gateway (cash kiosk reference model) in Phase 5. Fawry has a Flutter SDK and sandbox.

---

### DECISION-004: SMS via Cequens (not Twilio)
**Decision**: Use Cequens as the SMS provider.  
**Rationale**: Egyptian company, healthcare-appropriate, OAuth2 REST API, Python SDK, sandbox available. International providers (Twilio, Vonage) have higher costs and potential delivery quality issues on Egyptian networks.  
**Compliance**: Sender ID must be registered with NTRA through Cequens before production SMS goes live. This is mandatory under Egyptian telecommunications law.

---

### DECISION-005: Huawei Push Kit (no Firebase)
**Decision**: Use Huawei Push Kit (HPK) for push notifications on the MatePad tablet.  
**Rationale**: The MatePad has no Google Play Services; Firebase Cloud Messaging requires GMS and will not work.  
**Android phone companion**: Uses Firebase FCM. Backend sends to both HPK and FCM simultaneously depending on the registered device token type.

---

### DECISION-006: Cequens for SMS, not WhatsApp Business API
**Decision**: Use SMS (Cequens) rather than WhatsApp Business API for patient notifications at MVP.  
**Rationale**: WhatsApp Business API requires Meta business verification, has per-message costs, and enforces message template pre-approval. SMS is simpler for MVP.  
**Future**: WhatsApp Business API can be added in a later phase as an optional channel with patient consent.

---

### DECISION-007: No AI features at this time
**Decision**: No AI diagnosis, clinical decision support, or transmission of records to external AI APIs.  
**Rationale**: Explicitly requested by client. Psychiatric records are maximally sensitive. Any AI feature would require a separate design, privacy impact assessment, and explicit approval.

---

### DECISION-008: Booking requests are separate from patients
**Decision**: A public website booking creates a `booking_request` record, never a `patient` record directly.  
**Rationale**: Psychiatric records require careful identity management. A phone number + name match is not sufficient to confirm identity. A human (receptionist or doctor) must review and explicitly merge a booking request into an existing patient record, or create a new one.  
**Security**: This prevents an attacker from probing the system by submitting bookings with known patient names/phones and observing responses.

---

### DECISION-009: PostgreSQL `clinical` schema with separate grants
**Decision**: Clinical tables (session_notes, diagnoses, medications, patient_clinical) live in a PostgreSQL `clinical` schema. The receptionist application DB role has no GRANT on this schema.  
**Rationale**: Defense-in-depth. Even if the application-layer permission check were bypassed, the DB-layer grant would prevent clinical data exposure for the receptionist role.

---

### DECISION-010: Offline scope = full record access
**Decision**: The doctor's offline mode includes full record access for all patients, not just today's appointments.  
**Rationale**: User confirmed this is the requirement. The security mitigation is: encrypted local storage (SQLCipher + device PIN), auto-lock after 5 minutes, wipe on sign-out, wipe on refresh token revocation.

---

### DECISION-011: Hosting on Railway/Render for MVP
**Decision**: Use Railway or Render for MVP hosting (managed PostgreSQL + Redis + app service).  
**Rationale**: Minimal operational overhead for a small clinic. No dedicated IT staff. Portable to a VPS/local Egyptian data center later if data sovereignty is required.  
**Data sovereignty note**: Egyptian PDPL compliance (Law 151/2020) requirements for health data hosting are not fully settled. Legal advice required before production launch.
