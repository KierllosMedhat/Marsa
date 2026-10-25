import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/appointment_item.dart';
import '../providers/schedule_provider.dart';
import '../../patients/screens/patient_search_screen.dart';
import '../../patients/screens/patient_create_screen.dart';
import '../../patients/screens/patient_detail_screen.dart';
import '../../patients/providers/patient_provider.dart';
import '../../clinical/providers/clinical_provider.dart';
import '../../clinical/screens/session_workspace_screen.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final scheduleState = ref.watch(scheduleProvider);
    final theme = Theme.of(context);
    final DateFormat dateFormat = () {
      try {
        return DateFormat('EEEE، d MMMM yyyy', 'ar');
      } catch (_) {
        return DateFormat('yyyy/MM/dd');
      }
    }();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 680;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isMobile ? 8 : 16,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'عيادة مرساة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Connection/Sync Status Badge
            Tooltip(
              message: scheduleState.isOffline ? 'وضع التابلت المحلي' : 'متصل بالخادم المركزي',
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheduleState.isOffline
                      ? Colors.amber.shade800
                      : Colors.teal.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      scheduleState.isOffline
                          ? Icons.cloud_off_rounded
                          : Icons.cloud_done_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 5),
                      Text(
                        scheduleState.isOffline ? 'وضع التابلت المحلي' : 'متصل بالخادم المركزي',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!isMobile) ...[
            Chip(
              avatar: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
              label: Text(
                authState.user?.nameAr ?? 'د. مارينا نبيه نمر',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: theme.primaryColorDark,
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'البحث في سجلات المرضى',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'تسجيل مريض جديد',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientCreateScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
          SizedBox(width: isMobile ? 4 : 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 860;
          final calendarWidget = Card(
            margin: EdgeInsets.all(isNarrow ? 0 : 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تقويم العيادة (توقيت القاهرة)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CalendarDatePicker(
                    initialDate: scheduleState.selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                    onDateChanged: (newDate) {
                      ref.read(scheduleProvider.notifier).changeDate(newDate);
                    },
                  ),
                  const Divider(height: 24),
                  Text(
                    'إحصائيات اليوم:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow('إجمالي المواعيد المحجوزة', '${scheduleState.appointments.length}'),
                  _buildStatRow(
                    'المؤكدة',
                    '${scheduleState.appointments.where((a) => a.isConfirmed).length}',
                    color: Colors.teal.shade700,
                  ),
                  _buildStatRow(
                    'المكتملة',
                    '${scheduleState.appointments.where((a) => a.isCompleted).length}',
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          );

          if (isNarrow) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Collapsible Calendar & Quick Stats on Mobile
                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: Icon(Icons.calendar_month, color: theme.primaryColor),
                        title: Text(
                          dateFormat.format(scheduleState.selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'إجمالي: ${scheduleState.appointments.length} | مؤكدة: ${scheduleState.appointments.where((a) => a.isConfirmed).length} | مكتملة: ${scheduleState.appointments.where((a) => a.isCompleted).length}',
                          style: TextStyle(fontSize: 12, color: Colors.teal.shade800),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: CalendarDatePicker(
                              initialDate: scheduleState.selectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                              onDateChanged: (newDate) {
                                ref.read(scheduleProvider.notifier).changeDate(newDate);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'جدول المواعيد والجلسات (${scheduleState.appointments.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'تحديث المواعيد',
                        onPressed: () => ref.read(scheduleProvider.notifier).loadAppointments(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (scheduleState.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (scheduleState.appointments.isEmpty)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.event_available, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'لا توجد مواعيد مسجلة لهذا اليوم',
                              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...scheduleState.appointments.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildAppointmentCard(context, ref, item),
                      ),
                    ),
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 340,
                child: SingleChildScrollView(child: calendarWidget),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'جدول المواعيد والجلسات اليومية',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateFormat.format(scheduleState.selectedDate),
                                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('تحديث المواعيد'),
                            onPressed: () => ref.read(scheduleProvider.notifier).loadAppointments(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                                          'لا توجد مواعيد مسجلة لهذا اليوم',
                                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: scheduleState.appointments.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (ctx, idx) {
                                      final item = scheduleState.appointments[idx];
                                      return _buildAppointmentCard(context, ref, item);
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    WidgetRef ref,
    AppointmentItem apt,
  ) {
    final timeFormat = DateFormat('hh:mm a', 'ar');
    final startTime = timeFormat.format(apt.slotStart);
    final endTime = timeFormat.format(apt.slotEnd);
    final isMobileCard = MediaQuery.sizeOf(context).width < 640;

    final timeBadge = Container(
      padding: EdgeInsets.symmetric(horizontal: isMobileCard ? 10 : 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B4F72).withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1B4F72).withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(
            apt.dateFormatted,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B4F72),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            startTime,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobileCard ? 13 : 15),
          ),
          Text(
            endTime,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );

    final patientInfo = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                apt.patientName,
                style: TextStyle(
                  fontSize: isMobileCard ? 15 : 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (apt.patientMrn != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    apt.patientMrn!,
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
                  ),
                ),
              // Status Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: apt.isConfirmed ? Colors.teal.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: apt.isConfirmed ? Colors.teal.shade300 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  apt.isConfirmed ? 'مؤكد' : apt.status,
                  style: TextStyle(
                    fontSize: 11,
                    color: apt.isConfirmed ? Colors.teal.shade800 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            apt.typeName,
            style: const TextStyle(
              color: Color(0xFF2E86AB),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (apt.notes != null && apt.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              apt.notes!,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    void openProfile() {
      if (apt.patientId != null) {
        ref.read(patientProvider.notifier).selectPatient(apt.patientId!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientDetailScreen(patientId: apt.patientId!),
          ),
        );
      }
    }

    void startSession() {
      ref.read(clinicalSessionProvider.notifier).startNewSession(
            patientId: apt.patientId ?? 'pat-unknown',
            patientName: apt.patientName,
            patientMrn: apt.patientMrn,
          );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SessionWorkspaceScreen(),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobileCard ? 12.0 : 16.0),
        child: isMobileCard
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      timeBadge,
                      const SizedBox(width: 12),
                      patientInfo,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.folder_shared_outlined, size: 17),
                          label: const Text('الملف الطبي', style: TextStyle(fontSize: 13)),
                          onPressed: openProfile,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: const Text('بدء الجلسة', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B4F72),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: startSession,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  timeBadge,
                  const SizedBox(width: 16),
                  patientInfo,
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_shared_outlined, size: 18),
                        label: const Text('الملف الطبي'),
                        onPressed: openProfile,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit_note, size: 20),
                        label: const Text('بدء الجلسة السريرية'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B4F72),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: startSession,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
