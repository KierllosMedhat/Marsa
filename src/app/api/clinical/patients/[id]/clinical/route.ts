import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { getDb, logAuditEvent, PatientClinicalRecord, saveDb } from '@/lib/db';
import { decryptField, encryptField } from '@/lib/encryption';

async function handleUpsertClinical(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const patient = db.patients.find(
    (p) => p.patient_id === params.id && !p.deleted_at
  );
  if (!patient) {
    return NextResponse.json({ detail: 'Patient not found' }, { status: 404 });
  }

  try {
    const body = await req.json();
    const nowIso = new Date().toISOString();

    let clinical = db.patient_clinical.find((c) => c.patient_id === params.id);
    if (!clinical) {
      clinical = {
        patient_id: params.id,
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
        updated_by: auth.staff.staff_id,
      };
      db.patient_clinical.push(clinical);
    }

    if (body.medical_history !== undefined) {
      clinical.medical_history = encryptField(body.medical_history);
    }
    if (body.psychiatric_history !== undefined) {
      clinical.psychiatric_history = encryptField(body.psychiatric_history);
    }
    if (body.family_history !== undefined) {
      clinical.family_history = encryptField(body.family_history);
    }
    if (body.social_history !== undefined) {
      clinical.social_history = encryptField(body.social_history);
    }
    if (body.history !== undefined) {
      clinical.history = encryptField(body.history);
    }
    if (body.psychiatric_examinations !== undefined) {
      clinical.psychiatric_examinations = encryptField(body.psychiatric_examinations);
    }
    if (body.physical_neurological_exam !== undefined) {
      clinical.physical_neurological_exam = encryptField(body.physical_neurological_exam);
    }
    if (body.risk_assessment !== undefined) {
      clinical.risk_assessment = encryptField(body.risk_assessment);
    }
    if (body.suicide_attempts !== undefined) {
      clinical.suicide_attempts = encryptField(body.suicide_attempts);
    }
    if (body.admitted_before !== undefined) {
      clinical.admitted_before = encryptField(body.admitted_before);
    }
    if (body.notes !== undefined) {
      clinical.notes = encryptField(body.notes);
    }
    if (Array.isArray(body.allergies)) {
      clinical.allergies = body.allergies;
    }

    clinical.updated_at = nowIso;
    clinical.updated_by = auth.staff.staff_id;
    saveDb(db);

    logAuditEvent(
      'update_clinical_history',
      'patient_clinical',
      auth.staff.staff_id,
      params.id
    );

    return NextResponse.json({
      patient_id: clinical.patient_id,
      medical_history: decryptField(clinical.medical_history),
      psychiatric_history: decryptField(clinical.psychiatric_history),
      family_history: decryptField(clinical.family_history),
      social_history: decryptField(clinical.social_history),
      history: decryptField(clinical.history),
      psychiatric_examinations: decryptField(clinical.psychiatric_examinations),
      physical_neurological_exam: decryptField(clinical.physical_neurological_exam),
      risk_assessment: decryptField(clinical.risk_assessment),
      suicide_attempts: decryptField(clinical.suicide_attempts),
      admitted_before: decryptField(clinical.admitted_before),
      notes: decryptField(clinical.notes),
      allergies: clinical.allergies,
      updated_at: clinical.updated_at,
      updated_by: clinical.updated_by,
    });
  } catch {
    return NextResponse.json({ detail: 'Invalid clinical payload' }, { status: 400 });
  }
}

export const POST = handleUpsertClinical;
export const PUT = handleUpsertClinical;
export const PATCH = handleUpsertClinical;
