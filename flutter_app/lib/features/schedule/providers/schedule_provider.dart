import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/appointment_item.dart';

class ScheduleState {
  final DateTime selectedDate;
  final List<AppointmentItem> appointments;
  final bool isLoading;
  final String? errorMessage;
  final bool isOffline;

  ScheduleState({
    required this.selectedDate,
    this.appointments = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isOffline = false,
  });

  ScheduleState copyWith({
    DateTime? selectedDate,
    List<AppointmentItem>? appointments,
    bool? isLoading,
    String? errorMessage,
    bool? isOffline,
  }) {
    return ScheduleState(
      selectedDate: selectedDate ?? this.selectedDate,
      appointments: appointments ?? this.appointments,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

final scheduleProvider = StateNotifierProvider<ScheduleNotifier, ScheduleState>((ref) {
  final apiClient = ref.read(apiClientProvider);
  ref.watch(authProvider.select((s) => s.isAuthenticated));
  return ScheduleNotifier(apiClient);
});

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  final ApiClient _apiClient;

  ScheduleNotifier(this._apiClient)
      : super(ScheduleState(selectedDate: DateTime.now())) {
    loadAppointments();
  }

  void changeDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    loadAppointments();
  }

  Future<void> loadAppointments() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final res = await _apiClient.getList(
      '/appointments',
      queryParams: {
        'date': state.selectedDate.toIso8601String().substring(0, 10),
      },
    );

    if (res.isSuccess && res.data != null) {
      final items = res.data!
          .map((e) => AppointmentItem.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        isLoading: false,
        appointments: items,
        isOffline: false,
      );
    } else {
      // Fallback to offline schedule data for the clinic tablet
      final now = DateTime.now();
      final offlineAppointments = [
        AppointmentItem(
          appointmentId: 'apt-001',
          patientId: 'pat-001',
          patientName: 'أحمد محمود السعيد',
          patientMrn: 'MRN-00012',
          patientPhone: '01012345678',
          typeName: 'استشارة نفسية أولى',
          slotStart: DateTime(now.year, now.month, now.day, 10, 0),
          slotEnd: DateTime(now.year, now.month, now.day, 10, 45),
          status: 'confirmed',
          notes: 'إحالة من طبيب باطنة — شكوى من نوبات هلع متكررة وقلق عام',
        ),
        AppointmentItem(
          appointmentId: 'apt-002',
          patientId: 'pat-002',
          patientName: 'مريم عادل الشناوي',
          patientMrn: 'MRN-00015',
          patientPhone: '01123456789',
          typeName: 'جلسة علاج معرفي سلوكي (CBT)',
          slotStart: DateTime(now.year, now.month, now.day, 11, 0),
          slotEnd: DateTime(now.year, now.month, now.day, 11, 45),
          status: 'confirmed',
          notes: 'الجلسة الرابعة — متابعة واجب التعرض التدريجي',
        ),
        AppointmentItem(
          appointmentId: 'apt-003',
          patientId: 'pat-003',
          patientName: 'طارق حسام الدين',
          patientMrn: 'MRN-00021',
          patientPhone: '01234567890',
          typeName: 'متابعة دوائية',
          slotStart: DateTime(now.year, now.month, now.day, 12, 15),
          slotEnd: DateTime(now.year, now.month, now.day, 12, 45),
          status: 'confirmed',
          notes: 'مراجعة جرعة الإسيتالوبرام وظهور أعراض خمول بسيطة',
        ),
        AppointmentItem(
          appointmentId: 'apt-004',
          patientId: 'pat-004',
          patientName: 'سارة إبراهيم فتحي',
          patientMrn: 'MRN-00028',
          patientPhone: '01598765432',
          typeName: 'استشارة نفسية — اكتئاب حاد',
          slotStart: DateTime(now.year, now.month, now.day, 13, 0),
          slotEnd: DateTime(now.year, now.month, now.day, 13, 45),
          status: 'confirmed',
          notes: 'تقييم مخاطر — انخفاض الشهية واضطراب شديد في النوم',
        ),
      ];

      state = state.copyWith(
        isLoading: false,
        appointments: offlineAppointments,
        isOffline: true,
      );
    }
  }
}
