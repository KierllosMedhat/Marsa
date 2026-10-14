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
        setState(() => _isLoadingPatients = false);
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
    String? selectedPatientId;
    String? selectedTypeId;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 16, minute: 0);
    List<dynamic> types = [];
    bool loading = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (loading) {
            client.getList('/appointments/types').then((res) {
              if (res.isSuccess && res.data != null) {
                setDialogState(() {
                  types = res.data!;
                  if (types.isNotEmpty) selectedTypeId = types.first['type_id'];
                  loading = false;
                });
              }
            });
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_circle, color: Color(0xFF45632D)),
                SizedBox(width: 8),
                Text('حجز موعد جديد في العيادة'),
              ],
            ),
            content: loading
                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Patient Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'المريض *',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedPatientId,
                          hint: const Text('اختر المريض من السجل'),
                          items: _patients.map((p) {
                            return DropdownMenuItem(
                              value: p.patientId,
                              child: Text('${p.nameAr} (${p.mrn})'),
                            );
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedPatientId = val),
                        ),
                        const SizedBox(height: 12),

                        // Type Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'نوع الجلسة *',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedTypeId,
                          items: types.map((t) {
                            return DropdownMenuItem<String>(
                              value: t['type_id'] as String,
                              child: Text('${t['name_ar']} (${t['price_egp']} ج.م)'),
                            );
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedTypeId = val),
                        ),
                        const SizedBox(height: 12),

                        // Date Selector
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.grey),
                          ),
                          leading: const Icon(Icons.calendar_today, color: Color(0xFF45632D)),
                          title: Text(DateFormat('yyyy/MM/dd').format(selectedDate)),
                          trailing: const Text('تغيير التاريخ'),
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
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
                          leading: const Icon(Icons.access_time, color: Color(0xFF45632D)),
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
                onPressed: (selectedPatientId == null || selectedTypeId == null)
                    ? null
                    : () async {
                        final slotStart = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        final slotEnd = slotStart.add(const Duration(minutes: 45));

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
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('تم حجز الموعد بنجاح.')),
                            );
                          }
                        } else {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(res.errorMessage ?? 'فشل الحجز.')),
                            );
                          }
                        }
                      },
                child: const Text('تأكيد الحجز'),
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 24),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'عيادة مرساة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'بوابة موظف الاستقبال',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Staff Name Pill
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
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Security / Privacy Isolation Banner
          Container(
            color: const Color(0xFFF1F5E9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 20, color: Color(0xFF45632D)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'نظام حماية خصوصية المرضى مفعل: حساب الاستقبال مصرح له بإدارة الحجوزات والحضور وسجلات التواصل فقط. السجلات والتشخيصات الطبية محجوبة برمجياً ومحصورة بالطبيب.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF2F451E), fontWeight: FontWeight.w600),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.event, color: Color(0xFF45632D)),
                    label: Text(
                      dateFormat.format(scheduleState.selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D2619)),
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
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث',
                    onPressed: () => ref.read(scheduleProvider.notifier).loadAppointments(),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('حجز موعد جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF45632D),
                      foregroundColor: Colors.white,
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
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF45632D)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appt.patientName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (appt.patientMrn != null)
                          Text(
                            appt.patientMrn!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                      ],
                    ),
                  ],
                ),
                Chip(
                  label: Text(statusText, style: const TextStyle(fontSize: 11, color: Colors.white)),
                  backgroundColor: statusColor,
                ),
              ],
            ),
            const Divider(height: 20),
            // Attendance Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.check, size: 16, color: Colors.teal),
                  label: const Text('تسجيل وصول', style: TextStyle(color: Colors.teal)),
                  onPressed: () => _updateAppointmentStatus(appt.id, 'confirmed'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_off, size: 16, color: Colors.orange),
                  label: const Text('غائب', style: TextStyle(color: Colors.orange)),
                  onPressed: () => _updateAppointmentStatus(appt.id, 'no_show'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  label: const Text('إلغاء', style: TextStyle(color: Colors.red)),
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
                    hintText: 'ابحث بالاسم، رقم الهاتف، أو كود الملف MRN...',
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
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('مريض جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF45632D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              const Text(
                'طلبات الحجز الواردة من موقع العيادة الإلكتروني',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                        label: const Text('رفض الطلب', style: TextStyle(color: Colors.red)),
                                        onPressed: () => _rejectBookingRequest(req['request_id']),
                                      ),
                                      const SizedBox(width: 8),
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
