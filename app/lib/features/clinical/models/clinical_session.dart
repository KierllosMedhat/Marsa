class PrescriptionDraft {
  final String medicationName;
  final String dose;
  final String frequency;
  final String? instructions;

  PrescriptionDraft({
    required this.medicationName,
    required this.dose,
    required this.frequency,
    this.instructions,
  });

  Map<String, dynamic> toJson() => {
    'medication_name': medicationName,
    'dose': dose,
    'frequency': frequency,
    'instructions': instructions,
  };

  factory PrescriptionDraft.fromJson(Map<String, dynamic> json) => PrescriptionDraft(
    medicationName: json['medication_name'] ?? '',
    dose: json['dose'] ?? '',
    frequency: json['frequency'] ?? '',
    instructions: json['instructions'],
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
  
  // Clinical notes
  String chiefComplaint;
  String mentalStatusExam;
  String assessmentAndPlan;
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
    this.chiefComplaint = '',
    this.mentalStatusExam = '',
    this.assessmentAndPlan = '',
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
      'chief_complaint': chiefComplaint,
      'mental_status_exam': mentalStatusExam,
      'assessment_and_plan': assessmentAndPlan,
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
      chiefComplaint: json['chief_complaint'] ?? '',
      mentalStatusExam: json['mental_status_exam'] ?? '',
      assessmentAndPlan: json['assessment_and_plan'] ?? '',
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
