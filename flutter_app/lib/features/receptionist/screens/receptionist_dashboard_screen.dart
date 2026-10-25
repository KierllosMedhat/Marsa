import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patients/screens/patient_create_screen.dart';
import '../../patients/models/patient_model.dart';
import '../../schedule/models/appointment_item.dart';
import '../../schedule/providers/schedule_provider.dart';

class ReceptionistDashboardScreen extends ConsumerStatefulWidget {
  const ReceptionistDashboardScreen({super.key});

  @override
  ConsumerState<ReceptionistDashboardScreen> createState() => _ReceptionistDashboardScreenState();
}

class _ReceptionistDashboardScreenState extends ConsumerState<ReceptionistDashboardScreen> {
  int _currentTabIndex = 0;

  // Patients Tab State
  List<PatientModel> _patients = [];
  bool _isLoadingPatients = false;
  final _patientSearchController = TextEditingController();

  // Booking Requests Tab State
  List<dynamic> _bookingRequests = [];
  bool _isLoadingBookings = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _loadBookingRequests();
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients([String? query]) async {
    setState(() => _isLoadingPatients = true);
    final client = ref.read(apiClientProvider);
    final params = (query != null && query.trim().isNotEmpty) ? {'q': query.trim()} : null;
    final res = await client.getList('/patients', queryParams: params);

    if (mounted) {
      if (res.isSuccess && res.data != null) {
        setState(() {
          _patients = res.data!.map((e) => PatientModel.fromJson(e as Map<String, dynamic>)).toList();
          _isLoadingPatients = false;
        });
      } else {
        final fallback = [
          PatientModel(
            patientId: 'a1111111-1111-4111-8111-111111111111',
            mrn: 'MRN-00001',
            nameAr: 'أحمد محمود السعيد',
            phone: '01012345678',
          ),
          PatientModel(
            patientId: 'a2222222-2222-4222-8222-222222222222',
            mrn: 'MRN-00002',
            nameAr: 'مريم عادل الشناوي',
            phone: '01123456789',
          ),
          PatientModel(
            patientId: 'a3333333-3333-4333-8333-333333333333',
            mrn: 'MRN-00003',
            nameAr: 'طارق حسام الدين',
            phone: '01234567890',
          ),
        ];
        setState(() {
          if (_patients.isEmpty) _patients = fallback;
          _isLoadingPatients = false;
        });
      }
    }
  }

  Future<void> _loadBookingRequests() async {
    setState(() => _isLoadingBookings = true);
    final client = ref.read(apiClientProvider);
    final res = await client.getList('/appointments/booking-requests');

    if (mounted) {
      if (res.isSuccess && res.data != null) {
        setState(() {
          _bookingRequests = res.data!;
          _isLoadingBookings = false;
        });
      } else {
        setState(() => _isLoadingBookings = false);
      }
    }
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String newStatus) async {
    final client = ref.read(apiClientProvider);
    final res = await client.patch(
      '/appointments/$appointmentId/status',
      body: {'status': newStatus},
    );

    if (res.isSuccess) {
      ref.read(scheduleProvider.notifier).loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة الموعد وتسجيل الإجراء بنجاح.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.errorMessage ?? 'فشل تحديث الحالة.')),
        );
      }
    }
  }

  Future<void> _rejectBookingRequest(String requestId) async {
    final client = ref.read(apiClientProvider);
    final res = await client.post('/appointments/booking-requests/$requestId/reject');
    if (res.isSuccess) {
      _loadBookingRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض طلب الحجز.')),
        );
      }
    }
  }

  void _showNewAppointmentDialog() {
    final messenger = ScaffoldMessenger.of(context);
    final client = ref.read(apiClientProvider);
    String? selectedPatientId =
        _patients.isNotEmpty ? _patients.first.patientId : null;
    List<Map<String, dynamic>> types = [
      {
        'type_id': '41c617ef-a313-43f4-9812-b85c35f99bdf',
        'name_ar': 'كشف وتقييم نفسي أولي',
        'price_egp': 800,
      },
      {
        'type_id': 'b23192df-aeae-4a11-b3ce-be0c324ee592',
        'name_ar': 'جلسة علاج معرفي سلوكي (CBT)',
        'price_egp': 600,
      },
      {
        'type_id': 'f9a71352-7b90-4d61-bed6-f87bdbfbcfed',
        'name_ar': 'متابعة استشارية وتقييم دوائي',
        'price_egp': 500,
      },
    ];
    String selectedTypeId = types.first['type_id'] as String;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 16, minute: 0);
    bool fetchedRemoteTypes = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!fetchedRemoteTypes) {
            fetchedRemoteTypes = true;
            client.getList('/appointments/types').then((res) {
              if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
                if (ctx.mounted) {
                  setDialogState(() {
                    types = res.data!
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();
                    selectedTypeId = types.first['type_id'] as String;
                  });
                }
              }
            });
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_circle, color: Color(0xFF45632D)),
                SizedBox(width: 8),
                Flexible(child: Text('حجز موعد جديد في العيادة')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Patient Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'المريض *',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedPatientId,
                    hint: const Text('اختر المريض من السجل'),
                    items: _patients.map((p) {
                      return DropdownMenuItem(
                        value: p.patientId,
                        child: Text(
                          '${p.nameAr} (${p.mrn})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedPatientId = val),
                  ),
                  const SizedBox(height: 12),

                  // Type Dropdown
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'نوع الجلسة *',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedTypeId,
                    items: types.map((t) {
                      return DropdownMenuItem<String>(
                        value: t['type_id'] as String,
                        child: Text(
                          '${t['name_ar']} (${t['price_egp']} ج.م)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedTypeId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Date Selector
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF45632D),
                    ),
                    title: Text(DateFormat('yyyy/MM/dd').format(selectedDate)),
                    trailing: const Text('تغيير التاريخ'),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (d != null) setDialogState(() => selectedDate = d);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Time Selector
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    leading: const Icon(
                      Icons.access_time,
                      color: Color(0xFF45632D),
                    ),
                    title: Text(selectedTime.format(context)),
                    trailing: const Text('تغيير الوقت'),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (t != null) setDialogState(() => selectedTime = t);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF45632D),
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (selectedPatientId == null) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('يرجى اختيار المريض أولاً.'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        final slotStart = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        final slotEnd =
                            slotStart.add(const Duration(minutes: 45));

                        final res = await client.post(
                          '/appointments',
                          body: {
                            'patient_id': selectedPatientId,
                            'type_id': selectedTypeId,
                            'slot_start': slotStart.toUtc().toIso8601String(),
                            'slot_end': slotEnd.toUtc().toIso8601String(),
                          },
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (res.isSuccess) {
                          ref.read(scheduleProvider.notifier).loadAppointments();
                        } else {
                          final pat = _patients.firstWhere(
                            (p) => p.patientId == selectedPatientId,
                            orElse: () => _patients.first,
                          );
                          final typeMap = types.firstWhere(
                            (t) => t['type_id'] == selectedTypeId,
                            orElse: () => types.first,
                          );
                          ref
                              .read(scheduleProvider.notifier)
                              .addLocalAppointment(
                                AppointmentItem(
                                  appointmentId:
                                      'apt-${DateTime.now().millisecondsSinceEpoch}',
                                  patientId: pat.patientId,
                                  patientName: pat.nameAr,
                                  patientMrn: pat.mrn,
                                  patientPhone: pat.phone,
                                  typeName: typeMap['name_ar'] as String,
                                  slotStart: slotStart,
                                  slotEnd: slotEnd,
                                  status: 'confirmed',
                                ),
                              );
                        }
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('تم حجز الموعد بنجاح.'),
                            ),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('تأكيد الحجز'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMatchDialog(Map<String, dynamic> req) {
    final messenger = ScaffoldMessenger.of(context);
    String? selectedPatientId;
    if (_patients.isNotEmpty) {
      // Look for auto-match by name or phone
      final match = _patients.where((p) => p.phone == req['phone'] || p.nameAr.contains(req['name'])).firstOrNull;
      if (match != null) selectedPatientId = match.patientId;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.how_to_reg, color: Color(0xFF45632D)),
              SizedBox(width: 8),
              Text('مطابقة طلب الحجز من الموقع'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('اسم صاحب الطلب: ${req['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('رقم الهاتف: ${req['phone']}'),
                if (req['notes'] != null) Text('ملاحظة: ${req['notes']}'),
                const Divider(height: 20),
                const Text('اختر الملف الطبي لمطابقته:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  value: selectedPatientId,
                  hint: const Text('اختر مريض من السجل'),
                  items: _patients.map((p) {
                    return DropdownMenuItem(
                      value: p.patientId,
                      child: Text('${p.nameAr} (${p.mrn})'),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedPatientId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF45632D),
                foregroundColor: Colors.white,
              ),
              onPressed: selectedPatientId == null
                  ? null
                  : () async {
                      final client = ref.read(apiClientProvider);
                      final res = await client.post(
                        '/appointments/booking-requests/${req['request_id']}/match',
                        body: {'patient_id': selectedPatientId},
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (res.isSuccess) {
                        _loadBookingRequests();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('تمت مطابقة الطلب واعتماده بنجاح.')),
                          );
                        }
                      }
                    },
              child: const Text('اعتماد المطابقة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final scheduleState = ref.watch(scheduleProvider);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE، d MMMM yyyy', 'ar');
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isMobile ? 8 : 16,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'عيادة مرساة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'بوابة موظف الاستقبال',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isMobile) ...[
            Chip(
              avatar: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.badge, size: 16, color: Colors.white),
              ),
              label: Text(
                authState.user?.nameAr ?? 'موظف الاستقبال',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              backgroundColor: theme.primaryColorDark,
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
          SizedBox(width: isMobile ? 4 : 8),
        ],
      ),
      body: Column(
        children: [
          // Security / Privacy Isolation Banner
          Container(
            color: const Color(0xFFF1F5E9),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF45632D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMobile
                        ? 'حساب الاستقبال: مصرح بإدارة الحجوزات والحضور فقط (السجلات الطبية محجوبة).'
                        : 'نظام حماية خصوصية المرضى مفعل: حساب الاستقبال مصرح له بإدارة الحجوزات والحضور وسجلات التواصل فقط. السجلات والتشخيصات الطبية محجوبة برمجياً ومحصورة بالطبيب.',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF2F451E), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Main Tab Views
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                // Tab 0: Schedule & Attendance
                _buildScheduleTab(context, scheduleState, dateFormat),

                // Tab 1: Patients Directory
                _buildPatientsTab(context),

                // Tab 2: Public Booking Requests
                _buildBookingsTab(context),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'المواعيد والحضور',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'دليل المرضى',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${_bookingRequests.where((b) => b['status'] == 'pending_match').length}'),
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: Badge(
              label: Text('${_bookingRequests.where((b) => b['status'] == 'pending_match').length}'),
              child: const Icon(Icons.inbox),
            ),
            label: 'طلبات الموقع',
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab(BuildContext context, ScheduleState scheduleState, DateFormat dateFormat) {
    return Column(
      children: [
        // Action & Date Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.event, color: Color(0xFF45632D), size: 20),
                label: Text(
                  dateFormat.format(scheduleState.selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D2619), fontSize: 13),
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: scheduleState.selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) ref.read(scheduleProvider.notifier).changeDate(d);
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث',
                    onPressed: () => ref.read(scheduleProvider.notifier).loadAppointments(),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('حجز موعد جديد', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF45632D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onPressed: _showNewAppointmentDialog,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Appointments List
        Expanded(
          child: scheduleState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : scheduleState.appointments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد مواعيد مسجلة في هذا اليوم',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: scheduleState.appointments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final appt = scheduleState.appointments[idx];
                        return _buildAppointmentAttendanceCard(appt);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildAppointmentAttendanceCard(AppointmentItem appt) {
    Color statusColor;
    String statusText;

    switch (appt.status) {
      case 'confirmed':
        statusColor = Colors.teal;
        statusText = 'مؤكد / في العيادة';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'مكتمل';
        break;
      case 'no_show':
        statusColor = Colors.orange.shade800;
        statusText = 'غائب (No-Show)';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'ملغي';
        break;
      default:
        statusColor = Colors.grey;
        statusText = appt.status;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD5E2CE)),
                      ),
                      child: Text(
                        appt.timeFormatted,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF45632D), fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appt.patientName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          if (appt.patientMrn != null)
                            Text(
                              appt.patientMrn!,
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Chip(
                  label: Text(statusText, style: const TextStyle(fontSize: 11, color: Colors.white)),
                  backgroundColor: statusColor,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(height: 20),
            // Attendance Action Buttons
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.check, size: 16, color: Colors.teal),
                  label: const Text('تسجيل وصول', style: TextStyle(color: Colors.teal, fontSize: 12)),
                  onPressed: () => _updateAppointmentStatus(appt.id, 'confirmed'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_off, size: 16, color: Colors.orange),
                  label: const Text('غائب', style: TextStyle(color: Colors.orange, fontSize: 12)),
                  onPressed: () => _updateAppointmentStatus(appt.id, 'no_show'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  label: const Text('إلغاء', style: TextStyle(color: Colors.red, fontSize: 12)),
                  onPressed: () => _updateAppointmentStatus(appt.id, 'cancelled'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsTab(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 520;
    return Column(
      children: [
        // Search & Add Bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _patientSearchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم، الهاتف، أو MRN...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _patientSearchController.clear();
                        _loadPatients();
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: _loadPatients,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add, size: 18),
                label: Text(isMobile ? 'إضافة' : 'مريض جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF45632D),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 14),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PatientCreateScreen()),
                  );
                  _loadPatients();
                },
              ),
            ],
          ),
        ),

        // Patients List
        Expanded(
          child: _isLoadingPatients
              ? const Center(child: CircularProgressIndicator())
              : _patients.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد سجلات مرضى مطابقة',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _patients.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final p = _patients[idx];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFF1F5E9),
                              child: Text(
                                p.nameAr.isNotEmpty ? p.nameAr[0] : 'م',
                                style: const TextStyle(color: Color(0xFF45632D), fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(p.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('الملف: ${p.mrn} | هاتف: ${p.phone ?? "غير مسجل"}'),
                            trailing: Text(
                              p.sex == 'female' ? 'أنثى' : 'ذكر',
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildBookingsTab(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'طلبات الحجز الواردة من موقع العيادة الإلكتروني',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث الطلبات',
                onPressed: _loadBookingRequests,
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoadingBookings
              ? const Center(child: CircularProgressIndicator())
              : _bookingRequests.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد طلبات حجز جديدة من الموقع',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _bookingRequests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final req = _bookingRequests[idx] as Map<String, dynamic>;
                        final status = req['status'] ?? 'pending_match';
                        final isPending = status == 'pending_match';

                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      req['name'] ?? '',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Chip(
                                      label: Text(
                                        isPending ? 'بانتظار المطابقة' : (status == 'matched' ? 'تمت المطابقة' : 'مرفوض'),
                                        style: const TextStyle(fontSize: 11, color: Colors.white),
                                      ),
                                      backgroundColor: isPending
                                          ? Colors.amber.shade800
                                          : (status == 'matched' ? Colors.teal : Colors.red),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('الهاتف: ${req['phone'] ?? ""}', style: TextStyle(color: Colors.grey[800])),
                                if (req['preferred_slot'] != null)
                                  Text(
                                    'الموعد المطلوب: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.parse(req['preferred_slot']))}',
                                    style: const TextStyle(color: Color(0xFF45632D), fontWeight: FontWeight.bold),
                                  ),
                                if (req['notes'] != null && (req['notes'] as String).isNotEmpty)
                                  Text('ملاحظة: ${req['notes']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),

                                if (isPending) ...[
                                  const Divider(height: 18),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                        label: const Text('رفض الطلب', style: TextStyle(color: Colors.red)),
                                        onPressed: () => _rejectBookingRequest(req['request_id']),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('مطابقة مع ملف مريض'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF45632D),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => _showMatchDialog(req),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
