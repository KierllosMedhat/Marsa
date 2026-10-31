import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/staff_user.dart';
import '../providers/auth_provider.dart';

class AccountManagementScreen extends ConsumerStatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  ConsumerState<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState
    extends ConsumerState<AccountManagementScreen> {
  List<StaffUser> _staffList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStaffAccounts();
  }

  Future<void> _loadStaffAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final client = ref.read(apiClientProvider);
    final res = await client.getList('/staff');
    if (!mounted) return;

    if (res.isSuccess && res.data != null) {
      final list = res.data!
          .map((e) => StaffUser.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _staffList = list;
        _isLoading = false;
      });
    } else {
      final currentUser = ref.read(authProvider).user;
      final fallback = <StaffUser>[
        if (currentUser != null)
          currentUser
        else
          StaffUser(
            staffId: '11111111-1111-4111-8111-111111111111',
            role: 'doctor',
            nameAr: 'د. مارينا نبيه نمر',
            nameEn: 'Dr. Marina Nabih Nemer',
            email: 'doctor@marsa.clinic',
            phone: '01098042486',
            mfaEnabled: false,
            isActive: true,
          ),
        StaffUser(
          staffId: '22222222-2222-4222-8222-222222222222',
          role: 'receptionist',
          nameAr: 'سارة مصطفى (الاستقبال)',
          nameEn: 'Sara Mostafa (Receptionist)',
          email: 'receptionist@marsa.clinic',
          phone: '01000000002',
          mfaEnabled: false,
          isActive: true,
        ),
      ];
      setState(() {
        _staffList = fallback;
        _isLoading = false;
        _errorMessage = res.errorMessage;
      });
    }
  }

  void _showEditOrCreateStaffDialog({StaffUser? existing}) {
    final isEditing = existing != null;
    final currentUser = ref.read(authProvider).user;
    final isSelf = isEditing && currentUser?.staffId == existing.staffId;

    final nameArCtrl = TextEditingController(text: existing?.nameAr ?? '');
    final nameEnCtrl = TextEditingController(text: existing?.nameEn ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final passwordCtrl = TextEditingController();
    String selectedRole = existing?.role ?? 'receptionist';
    bool isActive = existing?.isActive ?? true;
    bool obscurePassword = true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.manage_accounts : Icons.person_add,
                color: const Color(0xFF45632D),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isSelf
                      ? 'تعديل حسابي الشخصي وكلمة المرور'
                      : (isEditing
                          ? 'تعديل حساب: ${existing.nameAr}'
                          : 'إضافة حساب مستخدم جديد بالعيادة'),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameArCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم بالعربية *',
                      hintText: 'مثال: د. مارينا نبيه نمر / سارة مصطفى',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameEnCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم بالإنجليزية (اختياري)',
                      hintText: 'Dr. Marina Nabih Nemer',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني / اسم المستخدم للدخول *',
                      hintText: 'doctor@marsa.clinic',
                      prefixIcon: Icon(Icons.alternate_email),
                      border: OutlineInputBorder(),
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: '01098042486',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: (selectedRole == 'doctor' ||
                            selectedRole == 'receptionist')
                        ? selectedRole
                        : 'doctor',
                    decoration: const InputDecoration(
                      labelText: 'الصلاحية والدور الوظيفي *',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'doctor',
                        child: Text(
                            'طبيب / مدير النظام (صلاحية كاملة للسجلات الطبية)'),
                      ),
                      DropdownMenuItem(
                        value: 'receptionist',
                        child: Text(
                            'موظف استقبال (إدارة المواعيد والحجوزات فقط)'),
                      ),
                    ],
                    onChanged: isSelf
                        ? null
                        : (val) {
                            if (val != null) {
                              setDialogState(() => selectedRole = val);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: isEditing
                          ? 'كلمة مرور جديدة (اتركها فارغة للإبقاء على الحالية)'
                          : 'كلمة المرور *',
                      hintText: isEditing
                          ? 'أدخل كلمة مرور جديدة لتغييرها'
                          : 'أدخل كلمة مرور قوية للحساب',
                      prefixIcon: const Icon(Icons.lock_reset),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setDialogState(
                          () => obscurePassword = !obscurePassword,
                        ),
                      ),
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  if (!isSelf && isEditing) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('حالة الحساب (نشط ومسموح له بالدخول)'),
                      value: isActive,
                      activeColor: const Color(0xFF45632D),
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(isEditing ? 'حفظ التعديلات' : 'إنشاء الحساب'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF45632D),
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final nameAr = nameArCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final password = passwordCtrl.text.trim();
                      final messenger = ScaffoldMessenger.of(this.context);

                      if (nameAr.isEmpty || email.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                                'يرجى إدخال الاسم والبريد الإلكتروني / اسم المستخدم.'),
                          ),
                        );
                        return;
                      }
                      if (!isEditing && password.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content:
                                Text('يرجى إدخال كلمة المرور للحساب الجديد.'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final client = ref.read(apiClientProvider);

                      final payload = <String, dynamic>{
                        'name_ar': nameAr,
                        'name_en': nameEnCtrl.text.trim().isEmpty
                            ? null
                            : nameEnCtrl.text.trim(),
                        'email': email,
                        'phone': phoneCtrl.text.trim().isEmpty
                            ? null
                            : phoneCtrl.text.trim(),
                        'role': selectedRole,
                        'is_active': isActive,
                        if (password.isNotEmpty) 'password': password,
                      };

                      final res = isEditing
                          ? await client.put(
                              '/staff/${existing.staffId}',
                              body: payload,
                            )
                          : await client.post('/staff', body: payload);

                      if (ctx.mounted) Navigator.pop(ctx);

                      if (res.isSuccess && res.data != null) {
                        final updatedUser = StaffUser.fromJson(res.data!);
                        if (isSelf) {
                          await ref
                              .read(authProvider.notifier)
                              .updateCurrentUser(updatedUser);
                        }
                        await _loadStaffAccounts();
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                isEditing
                                    ? 'تم تحديث بيانات الحساب بنجاح.'
                                    : 'تم إنشاء الحساب الجديد بنجاح.',
                              ),
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.red,
                              content: Text(
                                res.errorMessage ??
                                    'حدث خطأ أثناء حفظ بيانات الحساب.',
                              ),
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteStaff(StaffUser staff) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب نهائياً؟'),
        content: Text(
          'هل أنت متأكد من حذف حساب "${staff.nameAr}" (${staff.email})؟\nلن يتمكن هذا المستخدم من تسجيل الدخول بعد الحذف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final client = ref.read(apiClientProvider);
    final res = await client.delete('/staff/${staff.staffId}');
    if (res.isSuccess) {
      await _loadStaffAccounts();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('تم حذف الحساب بنجاح.')),
        );
      }
    } else {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(res.errorMessage ?? 'تعذر حذف الحساب.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.manage_accounts, size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'إدارة الحسابات والمستخدمين',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث القائمة',
            onPressed: _loadStaffAccounts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF45632D),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة حساب جديد'),
        onPressed: () => _showEditOrCreateStaffDialog(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                // 1. Current Doctor's Personal Account Card
                if (currentUser != null) ...[
                  Text(
                    'حسابي الشخصي (الطبيب مدير العيادة)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF45632D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: Color(0xFF45632D),
                        width: 1.2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 24,
                                backgroundColor: Color(0xFF45632D),
                                child: Icon(
                                  Icons.medical_services,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentUser.nameAr,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      currentUser.email,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.key, size: 16),
                                label: const Text('تعديل بياناتي وكلمة المرور'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF45632D),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _showEditOrCreateStaffDialog(
                                  existing: currentUser,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 2. All Clinic Staff Accounts Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'حسابات طاقم العيادة (${_staffList.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF45632D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'ملاحظة: $_errorMessage',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ..._staffList.map((staff) {
                  final isSelf = currentUser?.staffId == staff.staffId;
                  final isDoc = staff.role == 'doctor';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                  CircleAvatar(
                                    backgroundColor: isDoc
                                        ? const Color(0xFF1B4F72).withAlpha(30)
                                        : const Color(0xFF45632D).withAlpha(30),
                                    child: Icon(
                                      isDoc
                                          ? Icons.medical_services_outlined
                                          : Icons.desk_outlined,
                                      color: isDoc
                                          ? const Color(0xFF1B4F72)
                                          : const Color(0xFF45632D),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        staff.nameAr,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'اسم المستخدم / البريد: ${staff.email}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      if (staff.phone != null &&
                                          staff.phone!.isNotEmpty)
                                        Text(
                                          'الهاتف: ${staff.phone}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 6,
                                children: [
                                  Chip(
                                    label: Text(
                                      isDoc ? 'طبيب' : 'موظف استقبال',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: isDoc
                                        ? const Color(0xFF1B4F72)
                                        : const Color(0xFF45632D),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Chip(
                                    label: Text(
                                      staff.isActive ? 'نشط' : 'موقوف',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: staff.isActive
                                        ? Colors.teal
                                        : Colors.red,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text(
                                  'تعديل الحساب / تغيير كلمة المرور',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () => _showEditOrCreateStaffDialog(
                                  existing: staff,
                                ),
                              ),
                              if (!isSelf)
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'حذف الحساب',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                  onPressed: () => _confirmDeleteStaff(staff),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
