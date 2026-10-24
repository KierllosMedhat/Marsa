import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { encryptField, decryptField } from './encryption';

export type StaffRole = 'doctor' | 'receptionist' | 'admin';

export interface StaffMember {
  staff_id: string;
  role: StaffRole;
  name_ar: string;
  name_en: string | null;
  email: string;
  phone: string | null;
  password_hash: string;
  mfa_enabled: boolean;
  is_active: boolean;
  created_at: string;
}

export interface PatientRecord {
  patient_id: string;
  mrn: string;
  name_ar: string;
  name_en: string | null;
  dob: string | null;
  sex: 'male' | 'female' | 'other' | 'prefer_not_to_say' | null;
  national_id: string | null; // AES-256-GCM encrypted
  phone: string | null;
  email: string | null;
  address: string | null;
  occupation: string | null;
  marital_status: string | null;
  children: string | null;
  first_session_date: string | null;
  last_session_date: string | null;
  emergency_contact: Record<string, unknown> | null;
  created_by: string;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface PatientClinicalRecord {
  patient_id: string;
  medical_history: string | null; // encrypted
  psychiatric_history: string | null; // encrypted
  family_history: string | null; // encrypted
  social_history: string | null; // encrypted
  history: string | null; // encrypted
  psychiatric_examinations: string | null; // encrypted
  physical_neurological_exam: string | null; // encrypted
  risk_assessment: string | null; // encrypted
  suicide_attempts: string | null; // encrypted
  admitted_before: string | null; // encrypted
  notes: string | null; // encrypted
  allergies: string[];
  updated_at: string;
  updated_by: string;
}

export interface DiagnosisRecord {
  diagnosis_id: string;
  patient_id: string;
  icd10_code: string | null;
  description_ar: string;
  description_en: string | null;
  date_diagnosed: string;
  status: 'active' | 'resolved' | 'in_remission';
  author_id: string;
  created_at: string;
  finalized_at: string | null;
}

export interface MedicationRecord {
  medication_id: string;
  patient_id: string;
  name_ar: string;
  name_en: string | null;
  dose: string | null;
  frequency: string | null;
  route: string | null;
  duration: string | null;
  date: string | null;
  start_date: string | null;
  end_date: string | null;
  notes: string | null;
  prescribed_by: string;
  is_active: boolean;
  created_at: string;
}

export interface SessionRecord {
  session_id: string;
  patient_id: string;
  appointment_id: string | null;
  started_at: string;
  ended_at: string | null;
  status: 'draft' | 'finalized';
  session_number: number | null;
  chief_complaint: string | null;
  sleep: string | null;
  appetite: string | null;
  mood: string | null;
  anxiety: string | null;
  suicidal_self_harm_assessment: string | null;
  substance_use: string | null;
  mental_status_examination: string | null;
  diagnosis: string | null;
  treatment_plan: string | null;
  follow_up: string | null;
  created_by: string;
  finalized_by: string | null;
  finalized_at: string | null;
  created_at: string;
}

export interface SessionNoteRecord {
  note_id: string;
  session_id: string;
  note_type: 'typed' | 'handwritten' | 'mixed';
  content_typed: string | null; // encrypted
  content_ink_ref: string | null;
  version: number;
  is_draft: boolean;
  amended_from: string | null;
  edited_at: string;
  edited_by: string;
}

export interface PatientFileRecord {
  file_id: string;
  patient_id: string;
  file_name: string;
  file_type: string;
  file_location: string;
  uploaded_at: string;
}

export interface PatientNoteRecord {
  note_id: string;
  patient_id: string;
  note_text: string;
  last_modified: string;
}

export interface AppointmentTypeRecord {
  type_id: string;
  name_ar: string;
  name_en: string | null;
  duration_minutes: number;
  price_egp: number;
  is_active: boolean;
}

export interface AppointmentRecord {
  appointment_id: string;
  patient_id: string | null;
  booking_request_id: string | null;
  type_id: string;
  slot_start: string;
  slot_end: string;
  status: 'available' | 'held' | 'confirmed' | 'cancelled' | 'no_show' | 'completed';
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface BookingRequestRecord {
  request_id: string;
  name: string;
  phone: string;
  email: string | null;
  type_id: string;
  preferred_slot: string | null;
  status: 'pending_match' | 'matched' | 'rejected';
  matching_patient_id: string | null;
  notes: string | null;
  created_at: string;
}

export interface AuditLogRecord {
  log_id: string;
  staff_id: string | null;
  action: string;
  resource_type: string;
  resource_id: string | null;
  timestamp: string;
}

export interface MarsaDatabase {
  staff: StaffMember[];
  patients: PatientRecord[];
  patient_clinical: PatientClinicalRecord[];
  diagnoses: DiagnosisRecord[];
  medications: MedicationRecord[];
  sessions: SessionRecord[];
  session_notes: SessionNoteRecord[];
  patient_files: PatientFileRecord[];
  patient_notes: PatientNoteRecord[];
  appointment_types: AppointmentTypeRecord[];
  appointments: AppointmentRecord[];
  booking_requests: BookingRequestRecord[];
  audit_log: AuditLogRecord[];
}

function hashPwd(pwd: string): string {
  const salt = 'marsa_argon_salt_v1';
  const derived = crypto.scryptSync(pwd, salt, 64).toString('hex');
  return `scrypt$${salt}$${derived}`;
}

function createInitialSeedData(): MarsaDatabase {
  const nowIso = new Date().toISOString();
  const todayStr = nowIso.slice(0, 10);

  const doctorId = '11111111-1111-4111-8111-111111111111';
  const receptionId = '22222222-2222-4222-8222-222222222222';

  const typeEvalId = '41c617ef-a313-43f4-9812-b85c35f99bdf';
  const typeCbtId = 'b23192df-aeae-4a11-b3ce-be0c324ee592';
  const typeMedId = 'f9a71352-7b90-4d61-bed6-f87bdbfbcfed';

  const pat1Id = 'a1111111-1111-4111-8111-111111111111';
  const pat2Id = 'a2222222-2222-4222-8222-222222222222';
  const pat3Id = 'a3333333-3333-4333-8333-333333333333';

  return {
    staff: [
      {
        staff_id: doctorId,
        role: 'doctor',
        name_ar: 'د. مارينا نبيه نمر',
        name_en: 'Dr. Marina Nabih Nemer',
        email: 'doctor@marsa.clinic',
        phone: '01098042486',
        password_hash: hashPwd('DoctorPass123!'),
        mfa_enabled: false,
        is_active: true,
        created_at: nowIso,
      },
      {
        staff_id: receptionId,
        role: 'receptionist',
        name_ar: 'سارة مصطفى (الاستقبال)',
        name_en: 'Sara Mostafa (Receptionist)',
        email: 'receptionist@marsa.clinic',
        phone: '01000000002',
        password_hash: hashPwd('ReceptionPass123!'),
        mfa_enabled: false,
        is_active: true,
        created_at: nowIso,
      },
      {
        staff_id: '22222222-2222-4222-8222-222222222223',
        role: 'receptionist',
        name_ar: 'سارة مصطفى (الاستقبال)',
        name_en: 'Sara Mostafa (Receptionist)',
        email: 'reception@marsa.clinic',
        phone: '01000000002',
        password_hash: hashPwd('ReceptionPass123!'),
        mfa_enabled: false,
        is_active: true,
        created_at: nowIso,
      },
    ],
    appointment_types: [
      {
        type_id: typeEvalId,
        name_ar: 'كشف وتقييم نفسي أولي',
        name_en: 'Initial Psychiatric Evaluation',
        duration_minutes: 60,
        price_egp: 800,
        is_active: true,
      },
      {
        type_id: typeCbtId,
        name_ar: 'جلسة علاج معرفي سلوكي (CBT)',
        name_en: 'Cognitive Behavioral Therapy (CBT)',
        duration_minutes: 45,
        price_egp: 600,
        is_active: true,
      },
      {
        type_id: typeMedId,
        name_ar: 'متابعة استشارية وتقييم دوائي',
        name_en: 'Medication Follow-up',
        duration_minutes: 30,
        price_egp: 500,
        is_active: true,
      },
    ],
    patients: [
      {
        patient_id: pat1Id,
        mrn: 'MRN-00001',
        name_ar: 'أحمد محمود السعيد',
        name_en: 'Ahmed Mahmoud El-Saeed',
        dob: '1992-05-14',
        sex: 'male',
        national_id: encryptField('29205140101234'),
        phone: '01012345678',
        email: 'ahmed.m@example.com',
        address: 'مدينة نصر، القاهرة',
        occupation: 'مهندس برمجيات',
        marital_status: 'متزوج',
        children: 'ولد وبنت (6 و 3 سنوات)',
        first_session_date: '2026-01-15',
        last_session_date: '2026-10-10',
        emergency_contact: { name: 'منى السعيد', phone: '01099887766', relation: 'زوجة' },
        created_by: doctorId,
        created_at: nowIso,
        updated_at: nowIso,
        deleted_at: null,
      },
      {
        patient_id: pat2Id,
        mrn: 'MRN-00002',
        name_ar: 'مريم عادل الشناوي',
        name_en: 'Mariam Adel El-Shennawy',
        dob: '1998-08-22',
        sex: 'female',
        national_id: encryptField('29808220105678'),
        phone: '01123456789',
        email: 'mariam.a@example.com',
        address: 'المعادي، القاهرة',
        occupation: 'باحثة ماجستير',
        marital_status: 'عزباء',
        children: 'لا يوجد',
        first_session_date: '2026-03-05',
        last_session_date: '2026-09-28',
        emergency_contact: null,
        created_by: doctorId,
        created_at: nowIso,
        updated_at: nowIso,
        deleted_at: null,
      },
      {
        patient_id: pat3Id,
        mrn: 'MRN-00003',
        name_ar: 'طارق حسام الدين',
        name_en: 'Tarek Hossam',
        dob: '1981-11-03',
        sex: 'male',
        national_id: encryptField('28111030109999'),
        phone: '01234567890',
        email: 'tarek.h@example.com',
        address: 'مصر الجديدة، القاهرة',
        occupation: 'محاسب قانوني',
        marital_status: 'متزوج',
        children: 'ثلاثة أبناء',
        first_session_date: '2026-05-12',
        last_session_date: '2026-10-01',
        emergency_contact: null,
        created_by: doctorId,
        created_at: nowIso,
        updated_at: nowIso,
        deleted_at: null,
      },
    ],
    patient_clinical: [
      {
        patient_id: pat1Id,
        history: encryptField(
          'المريض يعاني من نوبات هلع متكررة بدأت منذ 8 أشهر مصحوبة بتسارع ضربات القلب وضيق تنفس وخوف شديد من الموت أو فقدان السيطرة، خاصة أثناء ضغوط العمل وركوب المترو.'
        ),
        psychiatric_history: encryptField(
          'بداية الأعراض منذ 8 أشهر مع تزايد المسؤوليات المهنية.'
        ),
        psychiatric_examinations: encryptField(
          'المظهر مهندم ومناسب، متوتر وحركي أثناء الجلسة. التواصل البصري جيد، الكلام متدفق بمعدل طبيعي. المزاج قلق، الوجدان متطابق. لا توجد هلاوس أو ضلالات. الاستبصار جيد ومدرك لحالته.'
        ),
        physical_neurological_exam: encryptField(
          'فحص عصبي سليم، منعكسات الأوتار متناظرة، لا توجد علامات عصبية بؤرية. ضغط الدم 125/80، النبض 84/دقيقة، رسم القلب ECG سليم.'
        ),
        risk_assessment: encryptField(
          'مستوى خطورة منخفض، لا توجد ميول إيذاء للنفس أو الغير. يوجد قلق توقعي ملحوظ.'
        ),
        suicide_attempts: encryptField('لا توجد أي محاولات انتحار سابقة.'),
        admitted_before: encryptField('لم يسبق له الدخول لأي مصحة أو مستشفى نفسي.'),
        medical_history: encryptField('حساسية موسمية خفيفة، لا يعاني من ضغط أو سكر.'),
        family_history: encryptField('الوالدة تعاني من اضطراب قلق معمم.'),
        social_history: encryptField(
          'غير مدخن، لا يتعاطى أي مواد مخدرة أو كحوليات، علاقاته الأسرية مستقرة وداعمة.'
        ),
        notes: encryptField(
          'مستجيب جيداً لجلسات CBT مع تقنيات التنفس البطني وإعادة الهيكلة المعرفية.'
        ),
        allergies: ['البنسلين'],
        updated_at: nowIso,
        updated_by: doctorId,
      },
      {
        patient_id: pat2Id,
        history: encryptField(
          'أفكار وسواسية حول التلوث والنظافة مصحوبة بأفعال قهرية متكررة كغسل الأيدي والتحقق المتكرر من إغلاق الأبواب والأجهزة، مما يستهلك 3-4 ساعات يومياً.'
        ),
        psychiatric_history: encryptField('بدأت الأعراض منذ عامين وتفاقمت خلال فترة الامتحانات.'),
        psychiatric_examinations: encryptField(
          'متوترة، جلد اليدين متقشر ومحمر نتيجة الغسيل المتكرر. الوعي والاستبصار تام بأن الأفكار مبالغ فيها لكنها تشعر بضيق شديد عند مقاومتها.'
        ),
        physical_neurological_exam: encryptField(
          'فحص عصبي طبيعي، التهاب جلدي خفيف باليدين نتيجة المنظفات.'
        ),
        risk_assessment: encryptField('لا يوجد خطر انتحاري، انزعاج وإرهاق نفسي ملحوظ.'),
        suicide_attempts: encryptField('لا يوجد'),
        admitted_before: encryptField('لا يوجد'),
        medical_history: encryptField('لا توجد أمراض مزمنة'),
        family_history: encryptField('الخالة تعاني من وسواس قهري مشابه'),
        social_history: encryptField('تعيش مع الأسرة، غير مدخنة.'),
        notes: encryptField('تحتاج للاستمرار على برنامج التعرض ومنع الاستجابة ERP.'),
        allergies: ['السلفا'],
        updated_at: nowIso,
        updated_by: doctorId,
      },
    ],
    diagnoses: [
      {
        diagnosis_id: 'd1111111-1111-4111-8111-111111111111',
        patient_id: pat1Id,
        icd10_code: 'F41.0',
        description_ar: 'اضطراب الهلع (Panic Disorder)',
        description_en: 'Panic Disorder',
        date_diagnosed: '2026-01-15',
        status: 'active',
        author_id: doctorId,
        created_at: nowIso,
        finalized_at: nowIso,
      },
      {
        diagnosis_id: 'd2222222-2222-4222-8222-222222222222',
        patient_id: pat2Id,
        icd10_code: 'F42',
        description_ar: 'اضطراب الوسواس القهري (OCD)',
        description_en: 'Obsessive-Compulsive Disorder',
        date_diagnosed: '2026-03-05',
        status: 'active',
        author_id: doctorId,
        created_at: nowIso,
        finalized_at: nowIso,
      },
    ],
    medications: [
      {
        medication_id: 'm1111111-1111-4111-8111-111111111111',
        patient_id: pat1Id,
        name_ar: 'سبرالكس (إسيتالوبرام)',
        name_en: 'Cipralex (Escitalopram)',
        dose: '10 mg',
        frequency: 'مرة واحدة صباحاً بعد الإفطار',
        duration: '6 أشهر',
        date: '2026-01-20',
        start_date: '2026-01-20',
        end_date: null,
        route: 'فموي',
        notes: 'متابعة أي أعراض هضمية في أول أسبوعين',
        prescribed_by: doctorId,
        is_active: true,
        created_at: nowIso,
      },
      {
        medication_id: 'm2222222-2222-4222-8222-222222222222',
        patient_id: pat1Id,
        name_ar: 'إندرال (بروبرانولول)',
        name_en: 'Inderal (Propranolol)',
        dose: '10 mg',
        frequency: 'عند اللزوم قبل المواقف المسببة للتوتر بنصف ساعة',
        duration: 'عند الحاجة',
        date: '2026-01-20',
        start_date: '2026-01-20',
        end_date: null,
        route: 'فموي',
        notes: 'لتخفيف الأعراض الجسدية لنوبة الهلع وتسارع النبض',
        prescribed_by: doctorId,
        is_active: true,
        created_at: nowIso,
      },
      {
        medication_id: 'm3333333-3333-4333-8333-333333333333',
        patient_id: pat2Id,
        name_ar: 'فافيرين (فلوفوكسامين)',
        name_en: 'Faverin (Fluvoxamine)',
        dose: '100 mg',
        frequency: 'قرص مساءً قبل النوم',
        duration: '4 أشهر',
        date: '2026-03-10',
        start_date: '2026-03-10',
        end_date: null,
        route: 'فموي',
        notes: 'زيادة تدريجية حسب الاستجابة السريرية',
        prescribed_by: doctorId,
        is_active: true,
        created_at: nowIso,
      },
    ],
    patient_files: [
      {
        file_id: 'f1111111-1111-4111-8111-111111111111',
        patient_id: pat1Id,
        file_name: 'تقرير رسم القلب والتحاليل الشاملة.pdf',
        file_type: 'medical_report',
        file_location: '/uploads/reports/ecg_lab_ahmed.pdf',
        uploaded_at: nowIso,
      },
    ],
    patient_notes: [
      {
        note_id: 'n1111111-1111-4111-8111-111111111111',
        patient_id: pat1Id,
        note_text:
          'تحسن واضح في نوبات الهلع بنسبة 70% بعد 8 جلسات، لم تحدث أي نوبة كاملة خلال آخر أسبوعين.',
        last_modified: nowIso,
      },
      {
        note_id: 'n2222222-2222-4222-8222-222222222222',
        patient_id: pat1Id,
        note_text:
          'يرغب في مناقشة تخفيض الجرعة الدوائية تدريجياً في المتابعة القادمة بعد شهرين.',
        last_modified: nowIso,
      },
    ],
    sessions: [
      {
        session_id: '51111111-1111-4111-8111-111111111111',
        patient_id: pat1Id,
        appointment_id: null,
        started_at: '2026-10-10T14:00:00.000Z',
        ended_at: '2026-10-10T14:45:00.000Z',
        status: 'finalized',
        session_number: 6,
        chief_complaint: 'متابعة دورية ومناقشة تحديات بيئة العمل الجديدة',
        sleep: 'منتظم (7 ساعات ليلاً، بدون استيقاظ متكرر)',
        appetite: 'جيدة ومستقرة',
        mood: 'مستقر وهادئ، قلق طفيف مع مواعيد التسليم',
        anxiety: 'منخفض إلى متوسط (GAD-7 score: 4)',
        suicidal_self_harm_assessment: 'لا توجد أي أفكار سلبية أو ميول إيذاء',
        substance_use: 'لا يوجد',
        mental_status_examination:
          'مظهر مرتب، تفاعل إيجابي، تركيز جيد، استبصار تام بالحالة والتطور العلاجي',
        diagnosis: 'F41.0 - اضطراب الهلع في حالة تحسن مستقر',
        treatment_plan:
          'الاستمرار على Cipralex 10mg ومتابعة تمارين التعرض التدريجي وملاحظة الأفكار التلقائية',
        follow_up: 'جلسة متابعة بعد 4 أسابيع',
        created_by: doctorId,
        finalized_by: doctorId,
        finalized_at: '2026-10-10T15:00:00.000Z',
        created_at: '2026-10-10T14:00:00.000Z',
      },
    ],
    session_notes: [],
    appointments: [
      {
        appointment_id: 'e1111111-1111-4111-8111-111111111111',
        patient_id: pat1Id,
        booking_request_id: null,
        type_id: typeEvalId,
        slot_start: `${todayStr}T14:00:00.000Z`,
        slot_end: `${todayStr}T15:00:00.000Z`,
        status: 'confirmed',
        notes: 'شكوى من نوبات هلع وقلق عام في بيئة العمل',
        created_at: nowIso,
        updated_at: nowIso,
      },
      {
        appointment_id: 'e2222222-2222-4222-8222-222222222222',
        patient_id: pat2Id,
        booking_request_id: null,
        type_id: typeCbtId,
        slot_start: `${todayStr}T16:00:00.000Z`,
        slot_end: `${todayStr}T16:45:00.000Z`,
        status: 'confirmed',
        notes: 'جلسة متابعة أسبوعية للتعرض ومنع الاستجابة (ERP)',
        created_at: nowIso,
        updated_at: nowIso,
      },
    ],
    booking_requests: [
      {
        request_id: 'b1111111-1111-4111-8111-111111111111',
        name: 'كريم عبد العزيز حامد',
        phone: '01055667788',
        email: 'karim.h@example.com',
        type_id: typeEvalId,
        preferred_slot: `${todayStr}T18:00:00+02:00`,
        status: 'pending_match',
        matching_patient_id: null,
        notes: 'أعاني من أرق مزمن منذ شهرين وصعوبة في التركيز',
        created_at: nowIso,
      },
    ],
    audit_log: [],
  };
}

// Global singleton in memory + file persistence (/tmp on Vercel, ./data locally)
const globalForDb = globalThis as unknown as { __marsaDb?: MarsaDatabase };

function getStoreFilePath(): string {
  if (process.env.VERCEL || process.env.AWS_LAMBDA_FUNCTION_NAME) {
    return path.join('/tmp', 'marsa_store.json');
  }
  const dataDir = path.join(process.cwd(), 'data');
  try {
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    return path.join(dataDir, 'marsa_store.json');
  } catch {
    return path.join('/tmp', 'marsa_store.json');
  }
}

export function getDb(): MarsaDatabase {
  if (globalForDb.__marsaDb) {
    return globalForDb.__marsaDb;
  }

  const filePath = getStoreFilePath();
  try {
    if (fs.existsSync(filePath)) {
      const raw = fs.readFileSync(filePath, 'utf8');
      const parsed = JSON.parse(raw) as MarsaDatabase;
      globalForDb.__marsaDb = parsed;
      return parsed;
    }
  } catch {
    // Fallback to initial seed
  }

  const seeded = createInitialSeedData();
  globalForDb.__marsaDb = seeded;
  saveDb(seeded);
  return seeded;
}

export function saveDb(db?: MarsaDatabase): void {
  const target = db || globalForDb.__marsaDb;
  if (!target) return;
  globalForDb.__marsaDb = target;
  try {
    const filePath = getStoreFilePath();
    fs.writeFileSync(filePath, JSON.stringify(target, null, 2), 'utf8');
  } catch {
    // Ignore read-only fs errors in restricted edge environments
  }
}

export function logAuditEvent(
  action: string,
  resourceType: string,
  staffId: string | null = null,
  resourceId: string | null = null
): void {
  const db = getDb();
  db.audit_log.push({
    log_id: crypto.randomUUID(),
    staff_id: staffId,
    action,
    resource_type: resourceType,
    resource_id: resourceId,
    timestamp: new Date().toISOString(),
  });
  saveDb(db);
}

export function buildDoctorPatientResponse(patient: PatientRecord) {
  const db = getDb();
  const clinical = db.patient_clinical.find((c) => c.patient_id === patient.patient_id);
  const diagnoses = db.diagnoses
    .filter((d) => d.patient_id === patient.patient_id)
    .sort((a, b) => b.created_at.localeCompare(a.created_at));
  const medications = db.medications
    .filter((m) => m.patient_id === patient.patient_id)
    .sort((a, b) => b.created_at.localeCompare(a.created_at));
  const sessions = db.sessions
    .filter((s) => s.patient_id === patient.patient_id)
    .sort((a, b) => b.started_at.localeCompare(a.started_at));
  const files = db.patient_files
    .filter((f) => f.patient_id === patient.patient_id)
    .sort((a, b) => b.uploaded_at.localeCompare(a.uploaded_at));
  const notes = db.patient_notes
    .filter((n) => n.patient_id === patient.patient_id)
    .sort((a, b) => b.last_modified.localeCompare(a.last_modified));

  return {
    patient_id: patient.patient_id,
    mrn: patient.mrn,
    name_ar: patient.name_ar,
    name_en: patient.name_en,
    dob: patient.dob,
    sex: patient.sex,
    national_id: decryptField(patient.national_id),
    phone: patient.phone,
    email: patient.email,
    address: patient.address,
    occupation: patient.occupation,
    marital_status: patient.marital_status,
    children: patient.children,
    first_session_date: patient.first_session_date,
    last_session_date: patient.last_session_date,
    emergency_contact: patient.emergency_contact,
    medical_history: clinical ? decryptField(clinical.medical_history) : null,
    psychiatric_history: clinical ? decryptField(clinical.psychiatric_history) : null,
    family_history: clinical ? decryptField(clinical.family_history) : null,
    social_history: clinical ? decryptField(clinical.social_history) : null,
    history: clinical ? decryptField(clinical.history) : null,
    psychiatric_examinations: clinical ? decryptField(clinical.psychiatric_examinations) : null,
    physical_neurological_exam: clinical
      ? decryptField(clinical.physical_neurological_exam)
      : null,
    risk_assessment: clinical ? decryptField(clinical.risk_assessment) : null,
    suicide_attempts: clinical ? decryptField(clinical.suicide_attempts) : null,
    admitted_before: clinical ? decryptField(clinical.admitted_before) : null,
    notes: clinical ? decryptField(clinical.notes) : null,
    allergies: clinical ? clinical.allergies : [],
    diagnoses,
    medications,
    sessions,
    files,
    quick_notes: notes,
    created_by: patient.created_by,
    created_at: patient.created_at,
    updated_at: patient.updated_at,
  };
}

export function buildReceptionistPatientSummary(patient: PatientRecord) {
  return {
    patient_id: patient.patient_id,
    mrn: patient.mrn,
    name_ar: patient.name_ar,
    name_en: patient.name_en,
    phone: patient.phone,
    email: patient.email,
    sex: patient.sex,
  };
}
