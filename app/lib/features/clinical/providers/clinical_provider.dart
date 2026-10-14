import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../models/clinical_session.dart';

class ClinicalSessionState {
  final ClinicalSession? currentSession;
  final bool isSaving;
  final bool isFinalizing;
  final String? lastSavedMessage;
  final String? errorMessage;

  ClinicalSessionState({
    this.currentSession,
    this.isSaving = false,
    this.isFinalizing = false,
    this.lastSavedMessage,
    this.errorMessage,
  });

  ClinicalSessionState copyWith({
    ClinicalSession? currentSession,
    bool? isSaving,
    bool? isFinalizing,
    String? lastSavedMessage,
    String? errorMessage,
  }) {
    return ClinicalSessionState(
      currentSession: currentSession ?? this.currentSession,
      isSaving: isSaving ?? this.isSaving,
      isFinalizing: isFinalizing ?? this.isFinalizing,
      lastSavedMessage: lastSavedMessage ?? this.lastSavedMessage,
      errorMessage: errorMessage,
    );
  }
}

final clinicalSessionProvider =
    StateNotifierProvider<ClinicalSessionNotifier, ClinicalSessionState>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final localStore = ref.read(localStoreProvider);
  return ClinicalSessionNotifier(apiClient, localStore);
});

class ClinicalSessionNotifier extends StateNotifier<ClinicalSessionState> {
  final ApiClient _apiClient;
  final LocalStore _localStore;
  final _uuid = const Uuid();

  ClinicalSessionNotifier(this._apiClient, this._localStore)
      : super(ClinicalSessionState());

  void startNewSession({
    required String patientId,
    required String patientName,
    String? patientMrn,
  }) {
    final newSession = ClinicalSession(
      sessionId: _uuid.v4(),
      patientId: patientId,
      patientName: patientName,
      patientMrn: patientMrn,
      startedAt: DateTime.now(),
      status: 'draft',
      activeDiagnoses: [],
      prescriptions: [],
    );

    state = state.copyWith(
      currentSession: newSession,
      lastSavedMessage: 'جلسة جديدة بدأت',
    );
  }

  void updateTypedNotes({
    String? chiefComplaint,
    String? mentalStatusExam,
    String? assessmentAndPlan,
    String? generalNotesTyped,
  }) {
    final session = state.currentSession;
    if (session == null || session.isFinalized) return;

    if (chiefComplaint != null) session.chiefComplaint = chiefComplaint;
    if (mentalStatusExam != null) session.mentalStatusExam = mentalStatusExam;
    if (assessmentAndPlan != null) session.assessmentAndPlan = assessmentAndPlan;
    if (generalNotesTyped != null) session.generalNotesTyped = generalNotesTyped;

    state = state.copyWith(currentSession: session);
    autoSaveDraft();
  }

  void setHandwritingInk(String inkJson) {
    final session = state.currentSession;
    if (session == null || session.isFinalized) return;

    session.inkStrokeJson = inkJson;
    state = state.copyWith(currentSession: session);
    autoSaveDraft();
  }

  void addPrescription(PrescriptionDraft prescription) {
    final session = state.currentSession;
    if (session == null || session.isFinalized) return;

    session.prescriptions.add(prescription);
    state = state.copyWith(currentSession: session);
    autoSaveDraft();
  }

  void removePrescription(int index) {
    final session = state.currentSession;
    if (session == null || session.isFinalized) return;

    session.prescriptions.removeAt(index);
    state = state.copyWith(currentSession: session);
    autoSaveDraft();
  }

  void addDiagnosis(String diagnosis) {
    final session = state.currentSession;
    if (session == null || session.isFinalized) return;

    if (!session.activeDiagnoses.contains(diagnosis)) {
      session.activeDiagnoses.add(diagnosis);
      state = state.copyWith(currentSession: session);
      autoSaveDraft();
    }
  }

  Future<void> autoSaveDraft() async {
    final session = state.currentSession;
    if (session == null || session.isFinalized) return;

    state = state.copyWith(isSaving: true);

    // 1. Always save to local encrypted tablet storage first
    await _localStore.saveDraftNote(session.sessionId, session.toJson());

    // 2. Attempt background push to backend API
    final notePayload = {
      'note_type': session.inkStrokeJson != null ? 'mixed' : 'typed',
      'content_typed': [
        if (session.chiefComplaint.isNotEmpty) 'الشكوى: ${session.chiefComplaint}',
        if (session.mentalStatusExam.isNotEmpty) 'فحص الحالة العقلية: ${session.mentalStatusExam}',
        if (session.assessmentAndPlan.isNotEmpty) 'التقييم والخطة: ${session.assessmentAndPlan}',
        if (session.generalNotesTyped.isNotEmpty) 'ملاحظات: ${session.generalNotesTyped}',
      ].join('\n\n'),
      'is_draft': true,
    };

    final res = await _apiClient.post(
      '/clinical/sessions/${session.sessionId}/notes',
      body: notePayload,
    );

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    state = state.copyWith(
      isSaving: false,
      lastSavedMessage: res.isSuccess
          ? 'تم الحفظ في الخادم ($timeStr)'
          : 'محفوظ محلياً على التابلت ($timeStr)',
    );
  }

  Future<bool> finalizeSession() async {
    final session = state.currentSession;
    if (session == null) return false;

    state = state.copyWith(isFinalizing: true, errorMessage: null);

    session.status = 'finalized';
    session.finalizedAt = DateTime.now();

    // 1. Update local storage
    await _localStore.saveDraftNote(session.sessionId, session.toJson());

    // 2. Post finalized note to backend
    final notePayload = {
      'note_type': session.inkStrokeJson != null ? 'mixed' : 'typed',
      'content_typed': [
        if (session.chiefComplaint.isNotEmpty) 'الشكوى الرئيسية:\n${session.chiefComplaint}',
        if (session.mentalStatusExam.isNotEmpty) 'فحص الحالة العقلية (MSE):\n${session.mentalStatusExam}',
        if (session.assessmentAndPlan.isNotEmpty) 'التقييم والخطة العلاجية:\n${session.assessmentAndPlan}',
        if (session.generalNotesTyped.isNotEmpty) 'ملاحظات الطبيب:\n${session.generalNotesTyped}',
        if (session.activeDiagnoses.isNotEmpty) 'التشخيصات المسجلة: ${session.activeDiagnoses.join('، ')}',
      ].join('\n\n---\n\n'),
      'is_draft': false,
    };

    final res = await _apiClient.post(
      '/clinical/sessions/${session.sessionId}/notes',
      body: notePayload,
    );

    state = state.copyWith(
      isFinalizing: false,
      currentSession: session,
      lastSavedMessage: res.isSuccess
          ? 'تم اعتماد وقفل الملاحظة السريرية في السجل المركزي'
          : 'تم اعتماد الملاحظة محلياً (في انتظار الاتصال بالخادم المركزي)',
    );

    return true;
  }
}
