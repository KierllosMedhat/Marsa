class AppointmentItem {
  final String appointmentId;
  final String? patientId;
  final String patientName;
  final String? patientMrn;
  final String? patientPhone;
  final String typeName;
  final DateTime slotStart;
  final DateTime slotEnd;
  final String status; // 'available', 'held', 'confirmed', 'completed', 'no_show', 'cancelled'
  final String? notes;

  AppointmentItem({
    required this.appointmentId,
    this.patientId,
    required this.patientName,
    this.patientMrn,
    this.patientPhone,
    required this.typeName,
    required this.slotStart,
    required this.slotEnd,
    required this.status,
    this.notes,
  });

  bool get isConfirmed => status == 'confirmed';
  bool get isCompleted => status == 'completed';
  String get id => appointmentId;
  String get timeFormatted {
    final hour = slotStart.hour.toString().padLeft(2, '0');
    final minute = slotStart.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  factory AppointmentItem.fromJson(Map<String, dynamic> json) {
    return AppointmentItem(
      appointmentId: json['appointment_id'] ?? '',
      patientId: json['patient_id'],
      patientName: json['patient_name'] ?? json['name_ar'] ?? 'مريض بدون اسم',
      patientMrn: json['patient_mrn'] ?? json['mrn'],
      patientPhone: json['patient_phone'] ?? json['phone'],
      typeName: json['type_name'] ?? 'جلسة استشارية أولى',
      slotStart: DateTime.parse(json['slot_start']),
      slotEnd: DateTime.parse(json['slot_end']),
      status: json['status'] ?? 'confirmed',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointment_id': appointmentId,
      'patient_id': patientId,
      'patient_name': patientName,
      'patient_mrn': patientMrn,
      'patient_phone': patientPhone,
      'type_name': typeName,
      'slot_start': slotStart.toIso8601String(),
      'slot_end': slotEnd.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }
}
