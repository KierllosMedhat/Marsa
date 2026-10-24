class PrescriptionDraft {
  final String medicationName;
  final String dose;
  final String frequency;
  final String? instructions;
  final String? duration;

  PrescriptionDraft({
    required this.medicationName,
    required this.dose,
    required this.frequency,
    this.instructions,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'medication_name': medicationName,
    'dose': dose,
    'frequency': frequency,
    'instructions': instructions,
    'duration': duration,
  };

  factory PrescriptionDraft.fromJson(Map<String, dynamic> json) => PrescriptionDraft(
    medicationName: json['medication_name'] ?? '',
    dose: json['dose'] ?? '',
    frequency: json['frequency'] ?? '',
    instructions: json['instructions'],
    duration: json['duration'],
  );
}

class ClinicalSession {
  final String sessionId;
  final String patientId;
  final String patientName;
  final String? patientMrn;
  final DateTime startedAt;
  DateTime? finalizedAt;
  String status; // 'draft', 'finalized'
  
  // Psychiatric Assessment Fields from Clinic ER Schema
  String? sessionNumber;
  String chiefComplaint;
  String sleep;
  String appetite;
  String mood;
  String anxiety;
  String suicidalSelfHarmAssessment;
  String substanceUse;
  String mentalStatusExam;
  String diagnosis;
  String treatmentPlan;
  String followUp;
  String generalNotesTyped;
  String? inkStrokeJson; // serialized M-Pencil handwriting strokes

  List<String> activeDiagnoses;
  List<PrescriptionDraft> prescriptions;
  bool isSavedLocally;

  ClinicalSession({
    required this.sessionId,
    required this.patientId,
    required this.patientName,
    this.patientMrn,
    required this.startedAt,
    this.finalizedAt,
    this.status = 'draft',
    this.sessionNumber,
    this.chiefComplaint = '',
    this.sleep = '',
    this.appetite = '',
    this.mood = '',
    this.anxiety = '',
    this.suicidalSelfHarmAssessment = '',
    this.substanceUse = '',
    this.mentalStatusExam = '',
    this.diagnosis = '',
    this.treatmentPlan = '',
    this.followUp = '',
    this.generalNotesTyped = '',
    this.inkStrokeJson,
    List<String>? activeDiagnoses,
    List<PrescriptionDraft>? prescriptions,
    this.isSavedLocally = true,
  })  : activeDiagnoses = activeDiagnoses ?? [],
        prescriptions = prescriptions ?? [];

  bool get isFinalized => status == 'finalized';

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'patient_id': patientId,
      'patient_name': patientName,
      'patient_mrn': patientMrn,
      'started_at': startedAt.toIso8601String(),
      'finalized_at': finalizedAt?.toIso8601String(),
      'status': status,
      'session_number': sessionNumber,
      'chief_complaint': chiefComplaint,
      'sleep': sleep,
      'appetite': appetite,
      'mood': mood,
      'anxiety': anxiety,
      'suicidal_self_harm_assessment': suicidalSelfHarmAssessment,
      'substance_use': substanceUse,
      'mental_status_examination': mentalStatusExam,
      'diagnosis': diagnosis,
      'treatment_plan': treatmentPlan,
      'follow_up': followUp,
      'general_notes_typed': generalNotesTyped,
      'ink_stroke_json': inkStrokeJson,
      'active_diagnoses': activeDiagnoses,
      'prescriptions': prescriptions.map((p) => p.toJson()).toList(),
    };
  }

  factory ClinicalSession.fromJson(Map<String, dynamic> json) {
    return ClinicalSession(
      sessionId: json['session_id'] ?? '',
      patientId: json['patient_id'] ?? '',
      patientName: json['patient_name'] ?? '',
      patientMrn: json['patient_mrn'],
      startedAt: DateTime.tryParse(json['started_at'] ?? '') ?? DateTime.now(),
      finalizedAt: json['finalized_at'] != null ? DateTime.tryParse(json['finalized_at']) : null,
      status: json['status'] ?? 'draft',
      sessionNumber: json['session_number'],
      chiefComplaint: json['chief_complaint'] ?? '',
      sleep: json['sleep'] ?? '',
      appetite: json['appetite'] ?? '',
      mood: json['mood'] ?? '',
      anxiety: json['anxiety'] ?? '',
      suicidalSelfHarmAssessment: json['suicidal_self_harm_assessment'] ?? '',
      substanceUse: json['substance_use'] ?? '',
      mentalStatusExam: json['mental_status_examination'] ?? json['mental_status_exam'] ?? '',
      diagnosis: json['diagnosis'] ?? '',
      treatmentPlan: json['treatment_plan'] ?? json['assessment_and_plan'] ?? '',
      followUp: json['follow_up'] ?? '',
      generalNotesTyped: json['general_notes_typed'] ?? '',
      inkStrokeJson: json['ink_stroke_json'],
      activeDiagnoses: List<String>.from(json['active_diagnoses'] ?? []),
      prescriptions: (json['prescriptions'] as List?)
              ?.map((e) => PrescriptionDraft.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isSavedLocally: true,
    );
  }
}
