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
  final String? duration;
  final DateTime? date;
  final String? notes;
  final bool isActive;

  MedicationItem({
    required this.medicationId,
    required this.nameAr,
    this.nameEn,
    this.dose,
    this.frequency,
    this.route,
    this.duration,
    this.date,
    this.notes,
    this.isActive = true,
  });

  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    return MedicationItem(
      medicationId: json['medication_id'] ?? '',
      nameAr: json['name_ar'] ?? json['drug'] ?? '',
      nameEn: json['name_en'],
      dose: json['dose'],
      frequency: json['frequency'],
      route: json['route'],
      duration: json['duration'],
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
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
    'duration': duration,
    'date': date?.toIso8601String().substring(0, 10),
    'notes': notes,
    'is_active': isActive,
  };
}

class PatientFileItem {
  final String fileId;
  final String fileName;
  final String fileType;
  final String fileLocation;
  final DateTime createdAt;

  PatientFileItem({
    required this.fileId,
    required this.fileName,
    required this.fileType,
    required this.fileLocation,
    required this.createdAt,
  });

  factory PatientFileItem.fromJson(Map<String, dynamic> json) {
    return PatientFileItem(
      fileId: json['file_id'] ?? '',
      fileName: json['file_name'] ?? '',
      fileType: json['file_type'] ?? '',
      fileLocation: json['file_location'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'file_id': fileId,
    'file_name': fileName,
    'file_type': fileType,
    'file_location': fileLocation,
    'created_at': createdAt.toIso8601String(),
  };
}

class PatientNoteItem {
  final String noteId;
  final String noteText;
  final DateTime lastModified;

  PatientNoteItem({
    required this.noteId,
    required this.noteText,
    required this.lastModified,
  });

  factory PatientNoteItem.fromJson(Map<String, dynamic> json) {
    return PatientNoteItem(
      noteId: json['note_id'] ?? '',
      noteText: json['note_text'] ?? '',
      lastModified: DateTime.tryParse(json['last_modified'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'note_id': noteId,
    'note_text': noteText,
    'last_modified': lastModified.toIso8601String(),
  };
}

class SessionSummaryItem {
  final String sessionId;
  final DateTime startedAt;
  final String status;
  final String? noteSnippet;
  final String? sessionNumber;
  final String? chiefComplaint;
  final String? mood;
  final String? anxiety;
  final String? treatmentPlan;
  final String? followUp;

  SessionSummaryItem({
    required this.sessionId,
    required this.startedAt,
    required this.status,
    this.noteSnippet,
    this.sessionNumber,
    this.chiefComplaint,
    this.mood,
    this.anxiety,
    this.treatmentPlan,
    this.followUp,
  });

  factory SessionSummaryItem.fromJson(Map<String, dynamic> json) {
    return SessionSummaryItem(
      sessionId: json['session_id'] ?? '',
      startedAt: DateTime.tryParse(json['started_at'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'finalized',
      noteSnippet: json['note_snippet'] ?? json['content_typed'],
      sessionNumber: json['session_number'],
      chiefComplaint: json['chief_complaint'],
      mood: json['mood'],
      anxiety: json['anxiety'],
      treatmentPlan: json['treatment_plan'],
      followUp: json['follow_up'],
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

  // Psychiatric & Social Demographics
  final String? occupation;
  final String? maritalStatus;
  final String? children;
  final DateTime? firstSessionDate;
  final DateTime? lastSessionDate;
  
  // Clinical histories (decrypted for Doctor only)
  final String? medicalHistory;
  final String? psychiatricHistory;
  final String? familyHistory;
  final String? socialHistory;
  final String? history;
  final String? psychiatricExaminations;
  final String? physicalNeurologicalExam;
  final String? riskAssessment;
  final String? suicideAttempts;
  final String? admittedBefore;
  final String? notes;
  final List<String> allergies;

  final List<DiagnosisItem> diagnoses;
  final List<MedicationItem> medications;
  final List<SessionSummaryItem> sessionHistory;
  final List<PatientFileItem> files;
  final List<PatientNoteItem> quickNotes;

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
    this.occupation,
    this.maritalStatus,
    this.children,
    this.firstSessionDate,
    this.lastSessionDate,
    this.medicalHistory,
    this.psychiatricHistory,
    this.familyHistory,
    this.socialHistory,
    this.history,
    this.psychiatricExaminations,
    this.physicalNeurologicalExam,
    this.riskAssessment,
    this.suicideAttempts,
    this.admittedBefore,
    this.notes,
    this.allergies = const [],
    this.diagnoses = const [],
    this.medications = const [],
    this.sessionHistory = const [],
    this.files = const [],
    this.quickNotes = const [],
  });

  // Calculate age from dob
  int? get age {
    if (dob == null) return null;
    final now = DateTime.now();
    int a = now.year - dob!.year;
    if (now.month < dob!.month || (now.month == dob!.month && now.day < dob!.day)) {
      a--;
    }
    return a;
  }

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
      occupation: json['occupation'],
      maritalStatus: json['marital_status'],
      children: json['children'],
      firstSessionDate: json['first_session_date'] != null ? DateTime.tryParse(json['first_session_date']) : null,
      lastSessionDate: json['last_session_date'] != null ? DateTime.tryParse(json['last_session_date']) : null,
      medicalHistory: clinical?['medical_history'] ?? json['medical_history'],
      psychiatricHistory: clinical?['psychiatric_history'] ?? json['psychiatric_history'],
      familyHistory: clinical?['family_history'] ?? json['family_history'],
      socialHistory: clinical?['social_history'] ?? json['social_history'],
      history: clinical?['history'] ?? json['history'],
      psychiatricExaminations: clinical?['psychiatric_examinations'] ?? json['psychiatric_examinations'],
      physicalNeurologicalExam: clinical?['physical_neurological_exam'] ?? json['physical_neurological_exam'],
      riskAssessment: clinical?['risk_assessment'] ?? json['risk_assessment'],
      suicideAttempts: clinical?['suicide_attempts'] ?? json['suicide_attempts'],
      admittedBefore: clinical?['admitted_before'] ?? json['admitted_before'],
      notes: clinical?['notes'] ?? json['notes'],
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
      files: (json['files'] as List?)
              ?.map((e) => PatientFileItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      quickNotes: (json['notes'] is List)
          ? (json['notes'] as List)
              .map((e) => PatientNoteItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}
