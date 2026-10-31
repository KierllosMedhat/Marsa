const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const JWT_SECRET =
  process.env.JWT_SECRET ||
  process.env.JWT_PRIVATE_KEY ||
  'marsa-clinic-jwt-signing-secret-2026-secure';

function getEncryptionKey() {
  const envKey = process.env.ENCRYPTION_KEY;
  if (envKey) {
    try {
      const buf = Buffer.from(envKey, 'base64');
      if (buf.length === 32) return buf;
    } catch (_) {}
    return crypto.createHash('sha256').update(envKey).digest();
  }
  return crypto
    .createHash('sha256')
    .update('marsa-psychiatric-clinic-aes-256-gcm-master-key-2026')
    .digest();
}

function encryptField(plainText) {
  if (!plainText) return null;
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([
    cipher.update(String(plainText), 'utf8'),
    cipher.final(),
  ]);
  const authTag = cipher.getAuthTag();
  return Buffer.concat([iv, authTag, encrypted]).toString('hex');
}

function decryptField(cipherHex) {
  if (!cipherHex) return null;
  try {
    const raw = Buffer.from(String(cipherHex), 'hex');
    if (raw.length < 28) return cipherHex;
    const iv = raw.subarray(0, 12);
    const authTag = raw.subarray(12, 28);
    const encrypted = raw.subarray(28);
    const key = getEncryptionKey();
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(authTag);
    const decrypted = Buffer.concat([
      decipher.update(encrypted),
      decipher.final(),
    ]);
    return decrypted.toString('utf8');
  } catch (_) {
    return cipherHex;
  }
}

function base64UrlEncode(input) {
  const buf = typeof input === 'string' ? Buffer.from(input, 'utf8') : input;
  return buf
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function base64UrlDecode(input) {
  let base64 = String(input).replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4 !== 0) base64 += '=';
  return Buffer.from(base64, 'base64').toString('utf8');
}

function signToken(staffId, role, type = 'access', expiresInSeconds = 604800) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub: staffId,
    role,
    type,
    iat: now,
    exp: now + expiresInSeconds,
  };
  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(
    JSON.stringify(payload)
  )}`;
  const signature = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(unsigned)
    .digest();
  return `${unsigned}.${base64UrlEncode(signature)}`;
}

function verifyToken(token) {
  try {
    if (!token || typeof token !== 'string') return null;
    const parts = token.trim().split('.');
    if (parts.length !== 3) return null;
    const [headerB64, payloadB64, sigB64] = parts;
    const payload = JSON.parse(base64UrlDecode(payloadB64));
    const unsigned = `${headerB64}.${payloadB64}`;
    const expectedSig = base64UrlEncode(
      crypto.createHmac('sha256', JWT_SECRET).update(unsigned).digest()
    );
    if (sigB64 !== expectedSig) return null;
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) return null;
    return payload;
  } catch (_) {
    return null;
  }
}

function hashPwd(pwd) {
  const salt = 'marsa_argon_salt_v1';
  const derived = crypto.scryptSync(pwd, salt, 64).toString('hex');
  return `scrypt$${salt}$${derived}`;
}

function verifyPassword(password, storedHash) {
  if (!password || !storedHash) return false;
  if (storedHash.startsWith('scrypt$')) {
    const parts = storedHash.split('$');
    const salt = parts[1] || 'marsa_argon_salt_v1';
    const expected = parts[2] || '';
    const derived = crypto.scryptSync(password, salt, 64).toString('hex');
    return derived === expected;
  }
  return password === storedHash;
}

function createInitialSeedData() {
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
        emergency_contact: {
          name: 'منى السعيد',
          phone: '01099887766',
          relation: 'زوجة',
        },
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
        medical_history: encryptField(
          'لا توجد أمراض باطنية مزمنة؛ ضغط الدم والسكر في المعدل الطبيعي.'
        ),
        psychiatric_history: encryptField(
          'بدأت نوبات الهلع منذ 8 أشهر إثر ضغوط عمل حادة.'
        ),
        family_history: encryptField('والدة المريض تعاني من اضطراب قلق معمم.'),
        social_history: encryptField(
          'يعمل مهندس برمجيات، متزوج، غير مدخن.'
        ),
        history: encryptField('تاريخ مرضي مستقر مع التزام علاجي جيد.'),
        psychiatric_examinations: encryptField(
          'المريض واعي، متعاون، المزاج قلق قليلاً.'
        ),
        physical_neurological_exam: encryptField('الفحص العصبي سليم تماماً.'),
        risk_assessment: encryptField(
          'منخفض — لا توجد أفكار أو نوايا إيذاء الذات.'
        ),
        suicide_attempts: encryptField('لا يوجد'),
        admitted_before: encryptField('لا'),
        notes: encryptField(
          'يستجيب بشكل ملحوظ لتمارين التنفس وإعادة الهيكلة المعرفية.'
        ),
        allergies: ['Penicillin'],
        updated_at: nowIso,
        updated_by: doctorId,
      },
    ],
    diagnoses: [
      {
        diagnosis_id: 'd1111111-1111-4111-8111-111111111111',
        patient_id: pat1Id,
        icd10_code: 'F41.0',
        description_ar: 'اضطراب الهلع (نوبات هلع متكررة)',
        description_en: 'Panic disorder [episodic paroxysmal anxiety]',
        date_diagnosed: '2026-01-15',
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
        name_ar: 'إسيتالوبرام (سبرالكس)',
        name_en: 'Escitalopram (Cipralex)',
        dose: '10 مجم',
        frequency: 'قرص واحد يومياً بعد الإفطار',
        route: 'فموي (Oral)',
        duration: '6 أشهر',
        date: '2026-01-15',
        start_date: '2026-01-15',
        end_date: null,
        notes: 'الالتزام بالجرعة الصباحية بانتظام',
        prescribed_by: doctorId,
        is_active: true,
        created_at: nowIso,
      },
    ],
    sessions: [],
    session_notes: [],
    patient_files: [],
    patient_notes: [],
    appointments: [
      {
        appointment_id: 'apt-0001-4111-8111-111111111111',
        patient_id: pat1Id,
        booking_request_id: null,
        type_id: typeCbtId,
        slot_start: `${todayStr}T14:00:00+02:00`,
        slot_end: `${todayStr}T14:45:00+02:00`,
        status: 'confirmed',
        notes: 'جلسة متابعة CBT — مراجعة سجل الأفكار الأسبوعي',
        created_at: nowIso,
        updated_at: nowIso,
      },
      {
        appointment_id: 'apt-0002-4222-8222-222222222222',
        patient_id: pat2Id,
        booking_request_id: null,
        type_id: typeCbtId,
        slot_start: `${todayStr}T15:00:00+02:00`,
        slot_end: `${todayStr}T15:45:00+02:00`,
        status: 'confirmed',
        notes: 'جلسة التعرض ومنع الاستجابة (ERP)',
        created_at: nowIso,
        updated_at: nowIso,
      },
    ],
    booking_requests: [],
    audit_log: [],
  };
}

const STORE_FILE = '/tmp/marsa_store.json';

function getDb() {
  if (globalThis.__marsaDb) {
    return globalThis.__marsaDb;
  }
  try {
    if (fs.existsSync(STORE_FILE)) {
      const parsed = JSON.parse(fs.readFileSync(STORE_FILE, 'utf8'));
      if (parsed && Array.isArray(parsed.staff) && parsed.staff.length > 0) {
        globalThis.__marsaDb = parsed;
        return parsed;
      }
    }
  } catch (_) {}
  const seeded = createInitialSeedData();
  globalThis.__marsaDb = seeded;
  saveDb(seeded);
  return seeded;
}

function saveDb(db) {
  const target = db || globalThis.__marsaDb;
  if (!target) return;
  globalThis.__marsaDb = target;
  try {
    fs.writeFileSync(STORE_FILE, JSON.stringify(target), 'utf8');
  } catch (_) {}
}

function formatStaffUser(staff) {
  return {
    staff_id: staff.staff_id,
    role: staff.role,
    name_ar: staff.name_ar,
    name_en: staff.name_en,
    email: staff.email,
    phone: staff.phone,
    mfa_enabled: staff.mfa_enabled,
    is_active: staff.is_active,
    created_at: staff.created_at,
  };
}

function getStaffFromRequest(req) {
  const authHeader =
    req.headers['authorization'] || req.headers['Authorization'] || '';
  if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
    return null;
  }
  const token = authHeader.slice(7).trim();
  const payload = verifyToken(token);
  if (!payload || payload.type !== 'access') return null;
  const db = getDb();
  let staff = db.staff.find((s) => s.staff_id === payload.sub && s.is_active);
  if (!staff && payload.role) {
    staff = db.staff.find((s) => s.role === payload.role && s.is_active);
  }
  return staff || null;
}

function buildDoctorPatientResponse(patient) {
  const db = getDb();
  const clinical = db.patient_clinical.find(
    (c) => c.patient_id === patient.patient_id
  );
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
    psychiatric_history: clinical
      ? decryptField(clinical.psychiatric_history)
      : null,
    family_history: clinical ? decryptField(clinical.family_history) : null,
    social_history: clinical ? decryptField(clinical.social_history) : null,
    history: clinical ? decryptField(clinical.history) : null,
    psychiatric_examinations: clinical
      ? decryptField(clinical.psychiatric_examinations)
      : null,
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

function buildReceptionistPatientSummary(patient) {
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

function sendJson(res, status, data) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(JSON.stringify(data));
}

function parseBody(req) {
  return new Promise((resolve) => {
    if (req.body && typeof req.body === 'object') {
      return resolve(req.body);
    }
    if (typeof req.body === 'string' && req.body.trim()) {
      try {
        return resolve(JSON.parse(req.body));
      } catch (_) {
        return resolve({});
      }
    }
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
    });
    req.on('end', () => {
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch (_) {
        resolve({});
      }
    });
    req.on('error', () => resolve({}));
  });
}

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader(
    'Access-Control-Allow-Methods',
    'GET, POST, PUT, PATCH, DELETE, OPTIONS'
  );
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, Accept, X-Requested-With'
  );

  if (req.method === 'OPTIONS') {
    res.statusCode = 204;
    return res.end();
  }

  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  let pathname = parsedUrl.pathname;
  if (pathname.startsWith('/api')) {
    pathname = pathname.slice(4) || '/';
  }
  if (pathname.length > 1 && pathname.endsWith('/')) {
    pathname = pathname.slice(0, -1);
  }
  const method = req.method.toUpperCase();
  const db = getDb();

  // 1. GET /health
  if (pathname === '/health' && method === 'GET') {
    return sendJson(res, 200, {
      status: 'ok',
      db: true,
      redis: true,
      appVersion: (db.app_update && db.app_update.version) || '1.2.0',
      buildNumber: (db.app_update && db.app_update.buildNumber) || 3,
      timestamp: new Date().toISOString(),
    });
  }

  // 1b. GET & POST /app-update (Online OTA App Update & Live Cloud Manifest)
  if (pathname === '/app-update') {
    res.setHeader(
      'Cache-Control',
      'no-store, no-cache, must-revalidate, proxy-revalidate'
    );
    const defaultManifest = {
      version: '1.2.1',
      buildNumber: 4,
      releasedAt: '2026-10-27T23:15:00.000Z',
      mandatory: false,
      minSupportedBuild: 1,
      channel: 'stable',
      titleAr: 'تحديث هوائي مباشر (OTA v1.2.0)',
      changelogAr: [
        'تفعيل نظام التحديث الهوائي التلقائي (OTA) دون الحاجة لإعادة تثبيت ملف APK يدوياً عند كل تعديل.',
        'إضافة وضع المزامنة السحابية الفورية (Live Cloud OTA) لتشغيل أحدث التعديلات والواجهات لحظياً فور نشرها.',
        'دعم التنزيل والتثبيت المباشر من داخل التطبيق مع شريط تقدم وفحص سلامة الحزمة.',
        'تحسين استجابة قلم Huawei M-Pencil ومزامنة الجلسات السريرية.',
      ],
      apkDownloadUrl:
        'https://raw.githubusercontent.com/KierllosMedhat/Marsa/main/Marsa-Clinic-Android.apk',
      apkMirrorUrl:
        'https://marsa-clinic-xi.vercel.app/ota/Marsa-Clinic-Android.apk',
      liveWebBundleUrl:
        'https://marsa-clinic-xi.vercel.app/ota-bundle/index.html',
      remoteConfig: {
        enableLiveCloudOta: true,
        autoCheckOnStartup: true,
        checkIntervalMinutes: 15,
        clinicAnnouncementAr: null,
        apiBaseUrlOverride: null,
      },
    };

    let diskManifest = { ...defaultManifest };
    try {
      const versionFile = path.join(__dirname, '..', 'ota', 'version.json');
      if (fs.existsSync(versionFile)) {
        const parsed = JSON.parse(fs.readFileSync(versionFile, 'utf8'));
        diskManifest = { ...diskManifest, ...parsed };
      }
    } catch (_) {}

    if (method === 'GET') {
      const merged = db.app_update
        ? {
            ...diskManifest,
            ...db.app_update,
            remoteConfig: {
              ...(diskManifest.remoteConfig || {}),
              ...((db.app_update && db.app_update.remoteConfig) || {}),
            },
          }
        : diskManifest;
      return sendJson(res, 200, merged);
    }

    if (method === 'POST') {
      const body = await parseBody(req);
      const current = db.app_update
        ? { ...diskManifest, ...db.app_update }
        : diskManifest;
      const updated = {
        ...current,
        ...body,
        releasedAt: new Date().toISOString(),
        remoteConfig: {
          ...(current.remoteConfig || {}),
          ...(body.remoteConfig || {}),
        },
      };
      db.app_update = updated;
      saveDb(db);
      return sendJson(res, 200, { status: 'published', manifest: updated });
    }
  }

  // 2. POST /auth/login
  if (pathname === '/auth/login' && method === 'POST') {
    const body = await parseBody(req);
    const rawEmail = String(body.email || '').trim().toLowerCase();
    const password = String(body.password || '').trim();

    if (!rawEmail || !password) {
      return sendJson(res, 400, {
        detail: 'يرجى إدخال البريد الإلكتروني وكلمة المرور',
      });
    }

    const staff = db.staff.find(
      (s) =>
        s.email.toLowerCase() === rawEmail ||
        (rawEmail === 'doctor' && s.role === 'doctor') ||
        ((rawEmail === 'receptionist' || rawEmail === 'reception') &&
          s.role === 'receptionist')
    );

    if (!staff || !verifyPassword(password, staff.password_hash)) {
      return sendJson(res, 401, {
        detail: 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
      });
    }

    const accessToken = signToken(staff.staff_id, staff.role, 'access', 604800);
    const refreshToken = signToken(
      staff.staff_id,
      staff.role,
      'refresh',
      2592000
    );

    return sendJson(res, 200, {
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: 'bearer',
      requires_mfa: false,
      user: formatStaffUser(staff),
    });
  }

  // 3. GET /auth/me
  if (pathname === '/auth/me' && method === 'GET') {
    const staff = getStaffFromRequest(req);
    if (!staff) {
      return sendJson(res, 401, { detail: 'غير مصرح بالدخول' });
    }
    return sendJson(res, 200, formatStaffUser(staff));
  }

  // 4. POST /auth/refresh
  if (pathname === '/auth/refresh' && method === 'POST') {
    const body = await parseBody(req);
    const payload = verifyToken(body.refresh_token || '');
    if (!payload || payload.type !== 'refresh') {
      return sendJson(res, 401, { detail: 'انتهت صلاحية الجلسة' });
    }
    const staff = db.staff.find(
      (s) => s.staff_id === payload.sub && s.is_active
    );
    if (!staff) {
      return sendJson(res, 401, { detail: 'المستخدم غير موجود' });
    }
    return sendJson(res, 200, {
      access_token: signToken(staff.staff_id, staff.role, 'access', 604800),
      refresh_token: signToken(staff.staff_id, staff.role, 'refresh', 2592000),
      token_type: 'bearer',
      requires_mfa: false,
      user: formatStaffUser(staff),
    });
  }

  // 5. POST /auth/logout
  if (pathname === '/auth/logout' && method === 'POST') {
    res.statusCode = 204;
    return res.end();
  }

  // 6. GET / POST /appointments/types
  if (pathname === '/appointments/types') {
    if (method === 'GET') {
      return sendJson(
        res,
        200,
        db.appointment_types.filter((t) => t.is_active)
      );
    }
    if (method === 'POST') {
      const body = await parseBody(req);
      const newType = {
        type_id: crypto.randomUUID(),
        name_ar: body.name_ar || 'جلسة علاجية',
        name_en: body.name_en || null,
        duration_minutes: Number(body.duration_minutes) || 45,
        price_egp: Number(body.price_egp) || 600,
        is_active: true,
      };
      db.appointment_types.push(newType);
      saveDb(db);
      return sendJson(res, 201, newType);
    }
  }

  // 7. GET / POST /appointments/booking-requests
  if (pathname === '/appointments/booking-requests') {
    if (method === 'GET') {
      const sorted = [...db.booking_requests].sort((a, b) =>
        b.created_at.localeCompare(a.created_at)
      );
      return sendJson(res, 200, sorted);
    }
    if (method === 'POST') {
      const body = await parseBody(req);
      const name = String(body.name || '').trim();
      const phone = String(body.phone || '').trim();
      const email = body.email ? String(body.email).trim() : null;

      if (!name || !phone) {
        return sendJson(res, 422, {
          detail: 'يرجى إدخال الاسم ورقم الهاتف.',
        });
      }

      const typeObj =
        db.appointment_types.find((t) => t.type_id === body.type_id) ||
        db.appointment_types[0];
      const nowIso = new Date().toISOString();

      let patient = db.patients.find(
        (p) => !p.deleted_at && (p.phone === phone || p.name_ar === name)
      );

      if (!patient) {
        const nextNum = db.patients.length + 1;
        const mrn = `MRN-${String(nextNum).padStart(5, '0')}`;
        const doctorId =
          (db.staff.find((s) => s.role === 'doctor') || {}).staff_id || 'system';
        patient = {
          patient_id: crypto.randomUUID(),
          mrn,
          name_ar: name,
          name_en: null,
          dob: null,
          sex: null,
          national_id: null,
          phone,
          email,
          address: null,
          occupation: null,
          marital_status: null,
          children: null,
          first_session_date: String(body.preferred_slot || nowIso).slice(0, 10),
          last_session_date: null,
          emergency_contact: null,
          created_by: doctorId,
          created_at: nowIso,
          updated_at: nowIso,
          deleted_at: null,
        };
        db.patients.unshift(patient);
      }

      const requestId = crypto.randomUUID();
      const bookingReq = {
        request_id: requestId,
        name,
        phone,
        email,
        type_id: typeObj.type_id,
        preferred_slot: body.preferred_slot || nowIso,
        status: 'pending_match',
        matching_patient_id: patient.patient_id,
        notes: body.notes || null,
        created_at: nowIso,
      };
      db.booking_requests.unshift(bookingReq);

      let slotStartIso = nowIso;
      if (body.preferred_slot) {
        const parsed = new Date(body.preferred_slot);
        if (!isNaN(parsed.getTime())) {
          slotStartIso = parsed.toISOString();
        }
      }
      const durationMs = (typeObj.duration_minutes || 45) * 60 * 1000;
      const slotEndIso = new Date(
        new Date(slotStartIso).getTime() + durationMs
      ).toISOString();

      const newAppt = {
        appointment_id: crypto.randomUUID(),
        patient_id: patient.patient_id,
        booking_request_id: requestId,
        type_id: typeObj.type_id,
        slot_start: slotStartIso,
        slot_end: slotEndIso,
        status: 'confirmed',
        notes: body.notes
          ? `${body.notes} (حجز من الموقع الإلكتروني)`
          : 'حجز من الموقع الإلكتروني',
        created_at: nowIso,
        updated_at: nowIso,
      };
      db.appointments.unshift(newAppt);
      saveDb(db);

      return sendJson(res, 201, {
        ...bookingReq,
        appointment_id: newAppt.appointment_id,
        patient_id: patient.patient_id,
        patient_mrn: patient.mrn,
      });
    }
  }

  // 8. POST /appointments/booking-requests/:id/match or /reject
  const bookingActionMatch = pathname.match(
    /^\/appointments\/booking-requests\/([^/]+)\/(match|reject)$/
  );
  if (bookingActionMatch && method === 'POST') {
    const reqId = bookingActionMatch[1];
    const action = bookingActionMatch[2];
    const reqItem = db.booking_requests.find((r) => r.request_id === reqId);
    if (!reqItem) {
      return sendJson(res, 404, { detail: 'Booking request not found' });
    }
    if (action === 'reject') {
      reqItem.status = 'rejected';
      saveDb(db);
      return sendJson(res, 200, reqItem);
    }
    const body = await parseBody(req);
    reqItem.status = 'matched';
    if (body.patient_id) reqItem.matching_patient_id = body.patient_id;
    const existingAppt = db.appointments.find(
      (a) => a.booking_request_id === reqId
    );
    if (existingAppt && body.patient_id) {
      existingAppt.patient_id = body.patient_id;
    }
    saveDb(db);
    return sendJson(res, 200, reqItem);
  }

  // 9. GET / POST /appointments
  if (pathname === '/appointments') {
    if (method === 'GET') {
      const dateParam = parsedUrl.searchParams.get('date');
      const list = db.appointments.filter((a) => a.status !== 'cancelled');
      list.sort((a, b) => {
        const createdDiff = b.created_at.localeCompare(a.created_at);
        if (createdDiff !== 0) return createdDiff;
        if (dateParam) {
          const aMatches = a.slot_start.slice(0, 10) === dateParam ? 0 : 1;
          const bMatches = b.slot_start.slice(0, 10) === dateParam ? 0 : 1;
          if (aMatches !== bMatches) return aMatches - bMatches;
        }
        return 0;
      });
      const enriched = list.map((a) => {
        const pat = db.patients.find((p) => p.patient_id === a.patient_id);
        const bookReq = db.booking_requests.find(
          (r) => r.request_id === a.booking_request_id
        );
        const typeObj = db.appointment_types.find((t) => t.type_id === a.type_id);
        return {
          ...a,
          patient_name: pat
            ? pat.name_ar
            : bookReq
            ? `${bookReq.name} (حجز إلكتروني)`
            : 'مريض جديد',
          patient_mrn: pat ? pat.mrn : 'حجز موقع',
          patient_phone: pat ? pat.phone : bookReq ? bookReq.phone : null,
          type_name: typeObj ? typeObj.name_ar : 'جلسة علاجية',
        };
      });
      return sendJson(res, 200, enriched);
    }

    if (method === 'POST') {
      const body = await parseBody(req);
      const nowIso = new Date().toISOString();
      const typeId =
        body.type_id ||
        (db.appointment_types[0] ? db.appointment_types[0].type_id : '');
      const newAppt = {
        appointment_id: crypto.randomUUID(),
        patient_id: body.patient_id || null,
        booking_request_id: body.booking_request_id || null,
        type_id: typeId,
        slot_start: body.slot_start || nowIso,
        slot_end:
          body.slot_end ||
          new Date(Date.now() + 45 * 60 * 1000).toISOString(),
        status: 'confirmed',
        notes: body.notes || null,
        created_at: nowIso,
        updated_at: nowIso,
      };
      db.appointments.unshift(newAppt);
      saveDb(db);
      return sendJson(res, 201, newAppt);
    }
  }

  // 10. PATCH /appointments/:id/status
  const apptStatusMatch = pathname.match(/^\/appointments\/([^/]+)\/status$/);
  if (apptStatusMatch && method === 'PATCH') {
    const apptId = apptStatusMatch[1];
    const body = await parseBody(req);
    const appt = db.appointments.find((a) => a.appointment_id === apptId);
    if (!appt) {
      return sendJson(res, 404, { detail: 'Appointment not found' });
    }
    appt.status = body.status || appt.status;
    appt.updated_at = new Date().toISOString();
    saveDb(db);
    return sendJson(res, 200, appt);
  }

  // 11. GET / POST /patients
  if (pathname === '/patients') {
    const staff = getStaffFromRequest(req);
    if (method === 'GET') {
      const q = (parsedUrl.searchParams.get('q') || '').trim().toLowerCase();
      let activePatients = db.patients.filter((p) => !p.deleted_at);
      if (q) {
        activePatients = activePatients.filter(
          (p) =>
            p.name_ar.toLowerCase().includes(q) ||
            (p.name_en && p.name_en.toLowerCase().includes(q)) ||
            p.mrn.toLowerCase().includes(q) ||
            (p.phone && p.phone.includes(q))
        );
      }
      if (staff && staff.role === 'receptionist') {
        return sendJson(
          res,
          200,
          activePatients.map((p) => buildReceptionistPatientSummary(p))
        );
      }
      return sendJson(
        res,
        200,
        activePatients.map((p) => buildDoctorPatientResponse(p))
      );
    }

    if (method === 'POST') {
      const body = await parseBody(req);
      const nameAr = String(body.name_ar || '').trim();
      if (!nameAr) {
        return sendJson(res, 422, { detail: 'name_ar is required' });
      }
      const nextNum = db.patients.length + 1;
      const mrn = `MRN-${String(nextNum).padStart(5, '0')}`;
      const nowIso = new Date().toISOString();
      const newPatient = {
        patient_id: crypto.randomUUID(),
        mrn,
        name_ar: nameAr,
        name_en: body.name_en || null,
        dob: body.dob || null,
        sex: body.sex || null,
        national_id: body.national_id ? encryptField(body.national_id) : null,
        phone: body.phone || null,
        email: body.email || null,
        address: body.address || null,
        occupation: body.occupation || null,
        marital_status: body.marital_status || null,
        children: body.children || null,
        first_session_date: body.first_session_date || nowIso.slice(0, 10),
        last_session_date: body.last_session_date || null,
        emergency_contact: body.emergency_contact || null,
        created_by: staff ? staff.staff_id : 'system',
        created_at: nowIso,
        updated_at: nowIso,
        deleted_at: null,
      };
      db.patients.unshift(newPatient);
      saveDb(db);
      return sendJson(res, 201, {
        ...buildDoctorPatientResponse(newPatient),
        duplicate_warnings: [],
      });
    }
  }

  // 12. GET / PUT / DELETE /patients/:id
  const patDetailMatch = pathname.match(/^\/patients\/([^/]+)$/);
  if (patDetailMatch) {
    const patientId = patDetailMatch[1];
    const patient = db.patients.find(
      (p) => p.patient_id === patientId && !p.deleted_at
    );
    if (!patient) {
      return sendJson(res, 404, { detail: 'Patient not found' });
    }
    if (method === 'GET') {
      return sendJson(res, 200, buildDoctorPatientResponse(patient));
    }
    if (method === 'PUT') {
      const body = await parseBody(req);
      if (body.name_ar !== undefined) patient.name_ar = body.name_ar;
      if (body.name_en !== undefined) patient.name_en = body.name_en;
      if (body.phone !== undefined) patient.phone = body.phone;
      if (body.email !== undefined) patient.email = body.email;
      if (body.dob !== undefined) patient.dob = body.dob;
      if (body.sex !== undefined) patient.sex = body.sex;
      if (body.national_id !== undefined) {
        patient.national_id = body.national_id
          ? encryptField(body.national_id)
          : null;
      }
      if (body.address !== undefined) patient.address = body.address;
      if (body.occupation !== undefined) patient.occupation = body.occupation;
      if (body.marital_status !== undefined) {
        patient.marital_status = body.marital_status;
      }
      if (body.children !== undefined) patient.children = body.children;
      patient.updated_at = new Date().toISOString();
      saveDb(db);
      return sendJson(res, 200, buildDoctorPatientResponse(patient));
    }
    if (method === 'DELETE') {
      patient.deleted_at = new Date().toISOString();
      saveDb(db);
      res.statusCode = 204;
      return res.end();
    }
  }

  // 13. Clinical endpoints (/clinical/patients/:id/...)
  const clinicalSubMatch = pathname.match(
    /^\/clinical\/patients\/([^/]+)\/(clinical|diagnoses|medications|files|notes)(?:\/([^/]+))?$/
  );
  if (clinicalSubMatch) {
    const patientId = clinicalSubMatch[1];
    const resource = clinicalSubMatch[2];
    const subId = clinicalSubMatch[3];
    const nowIso = new Date().toISOString();

    if (resource === 'clinical' && method === 'POST') {
      const body = await parseBody(req);
      let rec = db.patient_clinical.find((c) => c.patient_id === patientId);
      if (!rec) {
        rec = {
          patient_id: patientId,
          medical_history: null,
          psychiatric_history: null,
          family_history: null,
          social_history: null,
          history: null,
          psychiatric_examinations: null,
          physical_neurological_exam: null,
          risk_assessment: null,
          suicide_attempts: null,
          admitted_before: null,
          notes: null,
          allergies: [],
          updated_at: nowIso,
          updated_by: 'doctor',
        };
        db.patient_clinical.push(rec);
      }
      const encFields = [
        'medical_history',
        'psychiatric_history',
        'family_history',
        'social_history',
        'history',
        'psychiatric_examinations',
        'physical_neurological_exam',
        'risk_assessment',
        'suicide_attempts',
        'admitted_before',
        'notes',
      ];
      for (const f of encFields) {
        if (body[f] !== undefined) {
          rec[f] = body[f] ? encryptField(body[f]) : null;
        }
      }
      if (Array.isArray(body.allergies)) rec.allergies = body.allergies;
      rec.updated_at = nowIso;
      saveDb(db);
      return sendJson(res, 200, { status: 'updated' });
    }

    if (resource === 'diagnoses' && method === 'POST') {
      const body = await parseBody(req);
      const diag = {
        diagnosis_id: crypto.randomUUID(),
        patient_id: patientId,
        icd10_code: body.icd10_code || null,
        description_ar: body.description_ar || '',
        description_en: body.description_en || null,
        date_diagnosed: body.date_diagnosed || nowIso.slice(0, 10),
        status: body.status || 'active',
        author_id: 'doctor',
        created_at: nowIso,
        finalized_at: nowIso,
      };
      db.diagnoses.unshift(diag);
      saveDb(db);
      return sendJson(res, 201, diag);
    }

    if (resource === 'medications' && method === 'POST') {
      const body = await parseBody(req);
      const med = {
        medication_id: crypto.randomUUID(),
        patient_id: patientId,
        name_ar: body.name_ar || '',
        name_en: body.name_en || null,
        dose: body.dose || null,
        frequency: body.frequency || null,
        route: body.route || null,
        duration: body.duration || null,
        date: body.date || nowIso.slice(0, 10),
        start_date: body.start_date || nowIso.slice(0, 10),
        end_date: body.end_date || null,
        notes: body.notes || null,
        prescribed_by: 'doctor',
        is_active: true,
        created_at: nowIso,
      };
      db.medications.unshift(med);
      saveDb(db);
      return sendJson(res, 201, med);
    }

    if (resource === 'files' && method === 'POST') {
      const body = await parseBody(req);
      const fileRec = {
        file_id: crypto.randomUUID(),
        patient_id: patientId,
        file_name: body.file_name || 'ملف مرفق',
        file_type: body.file_type || 'document',
        file_location: body.file_location || '',
        uploaded_at: nowIso,
      };
      db.patient_files.unshift(fileRec);
      saveDb(db);
      return sendJson(res, 201, fileRec);
    }

    if (resource === 'notes') {
      if (method === 'POST') {
        const body = await parseBody(req);
        const noteRec = {
          note_id: crypto.randomUUID(),
          patient_id: patientId,
          note_text: body.note_text || '',
          last_modified: nowIso,
        };
        db.patient_notes.unshift(noteRec);
        saveDb(db);
        return sendJson(res, 201, noteRec);
      }
      if (method === 'DELETE' && subId) {
        db.patient_notes = db.patient_notes.filter((n) => n.note_id !== subId);
        saveDb(db);
        res.statusCode = 204;
        return res.end();
      }
    }
  }

  // 14. Clinical Sessions (/clinical/sessions/...)
  const sessionMatch = pathname.match(
    /^\/clinical\/sessions(?:\/([^/]+))?(?:\/(notes))?$/
  );
  if (sessionMatch) {
    const sessionId = sessionMatch[1] || crypto.randomUUID();
    const isNotes = sessionMatch[2] === 'notes';
    const nowIso = new Date().toISOString();
    const body = await parseBody(req);

    if (isNotes && method === 'POST') {
      const note = {
        note_id: crypto.randomUUID(),
        session_id: sessionId,
        note_type: body.note_type || 'typed',
        content_typed: body.content_typed
          ? encryptField(body.content_typed)
          : null,
        content_ink_ref: null,
        version: 1,
        is_draft: Boolean(body.is_draft),
        amended_from: null,
        edited_at: nowIso,
        edited_by: 'doctor',
      };
      db.session_notes.push(note);
      saveDb(db);
      return sendJson(res, 201, note);
    }

    let session = db.sessions.find((s) => s.session_id === sessionId);
    if (!session) {
      session = {
        session_id: sessionId,
        patient_id: body.patient_id || '',
        appointment_id: body.appointment_id || null,
        started_at: nowIso,
        ended_at: null,
        status: body.status || 'draft',
        session_number: Number(body.session_number) || 1,
        chief_complaint: body.chief_complaint || null,
        sleep: body.sleep || null,
        appetite: body.appetite || null,
        mood: body.mood || null,
        anxiety: body.anxiety || null,
        suicidal_self_harm_assessment:
          body.suicidal_self_harm_assessment || null,
        substance_use: body.substance_use || null,
        mental_status_examination: body.mental_status_examination || null,
        diagnosis: body.diagnosis || null,
        treatment_plan: body.treatment_plan || null,
        follow_up: body.follow_up || null,
        created_by: 'doctor',
        finalized_by: body.status === 'finalized' ? 'doctor' : null,
        finalized_at: body.status === 'finalized' ? nowIso : null,
        created_at: nowIso,
      };
      db.sessions.unshift(session);
    } else {
      Object.assign(session, body);
      if (body.status === 'finalized') {
        session.finalized_at = nowIso;
      }
    }
    saveDb(db);
    return sendJson(res, 200, session);
  }

  return sendJson(res, 404, { detail: `Endpoint not found: ${pathname}` });
};
