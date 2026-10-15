class DiagnosisItem {
  final String diagnosisId;
  final String? icd10Code;
  final String descriptionAr;
  final String? descriptionEn;
  final DateTime dateDiagnosed;
  final String status; // active, resolved, in_remission

  DiagnosisItem({
    required this.diagnosisId,
    this.icd10Code,
    required this.descriptionAr,
    this.descriptionEn,
    required this.dateDiagnosed,
    required this.status,
  });

  factory DiagnosisItem.fromJson(Map<String, dynamic> json) {
    return DiagnosisItem(
      diagnosisId: json['diagnosis_id'] ?? '',
      icd10Code: json['icd10_code'],
      descriptionAr: json['description_ar'] ?? '',
      descriptionEn: json['description_en'],
      dateDiagnosed: DateTime.tryParse(json['date_diagnosed'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
    'diagnosis_id': diagnosisId,
    'icd10_code': icd10Code,
    'description_ar': descriptionAr,
    'description_en': descriptionEn,
    'date_diagnosed': dateDiagnosed.toIso8601String().substring(0, 10),
    'status': status,
  };
}

class MedicationItem {
  final String medicationId;
  final String nameAr;
  final String? nameEn;
  final String? dose;
  final String? frequency;
  final String? route;
  final String? notes;
  final bool isActive;

  MedicationItem({
    required this.medicationId,
    required this.nameAr,
    this.nameEn,
    this.dose,
    this.frequency,
    this.route,
    this.notes,
    this.isActive = true,
  });

  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    return MedicationItem(
      medicationId: json['medication_id'] ?? '',
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'],
      dose: json['dose'],
      frequency: json['frequency'],
      route: json['route'],
      notes: json['notes'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'medication_id': medicationId,
    'name_ar': nameAr,
    'name_en': nameEn,
    'dose': dose,
    'frequency': frequency,
    'route': route,
    'notes': notes,
    'is_active': isActive,
  };
}

class SessionSummaryItem {
  final String sessionId;
  final DateTime startedAt;
  final String status;
  final String? noteSnippet;

  SessionSummaryItem({
    required this.sessionId,
    required this.startedAt,
    required this.status,
    this.noteSnippet,
  });

  factory SessionSummaryItem.fromJson(Map<String, dynamic> json) {
    return SessionSummaryItem(
      sessionId: json['session_id'] ?? '',
      startedAt: DateTime.tryParse(json['started_at'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'finalized',
      noteSnippet: json['note_snippet'] ?? json['content_typed'],
    );
  }
}

class PatientModel {
  final String patientId;
  final String mrn;
  final String nameAr;
  final String? nameEn;
  final String? phone;
  final String? email;
  final DateTime? dob;
  final String? sex;
  final String? nationalId;
  final String? address;
  
  // Clinical histories (decrypted for Doctor only)
  final String? medicalHistory;
  final String? psychiatricHistory;
  final String? familyHistory;
  final String? socialHistory;
  final List<String> allergies;

  final List<DiagnosisItem> diagnoses;
  final List<MedicationItem> medications;
  final List<SessionSummaryItem> sessionHistory;

  PatientModel({
    required this.patientId,
    required this.mrn,
    required this.nameAr,
    this.nameEn,
    this.phone,
    this.email,
    this.dob,
    this.sex,
    this.nationalId,
    this.address,
    this.medicalHistory,
    this.psychiatricHistory,
    this.familyHistory,
    this.socialHistory,
    this.allergies = const [],
    this.diagnoses = const [],
    this.medications = const [],
    this.sessionHistory = const [],
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    final clinical = (json['clinical_record'] ?? json['clinical']) as Map<String, dynamic>?;

    return PatientModel(
      patientId: json['patient_id'] ?? '',
      mrn: json['mrn'] ?? '',
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'],
      phone: json['phone'],
      email: json['email'],
      dob: json['dob'] != null ? DateTime.tryParse(json['dob']) : null,
      sex: json['sex'],
      nationalId: json['national_id'],
      address: json['address'],
      medicalHistory: clinical?['medical_history'] ?? json['medical_history'],
      psychiatricHistory: clinical?['psychiatric_history'] ?? json['psychiatric_history'],
      familyHistory: clinical?['family_history'] ?? json['family_history'],
      socialHistory: clinical?['social_history'] ?? json['social_history'],
      allergies: List<String>.from(clinical?['allergies'] ?? json['allergies'] ?? []),
      diagnoses: (json['diagnoses'] as List?)
              ?.map((e) => DiagnosisItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      medications: (json['medications'] as List?)
              ?.map((e) => MedicationItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sessionHistory: (json['session_history'] as List?)
              ?.map((e) => SessionSummaryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
