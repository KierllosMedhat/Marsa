import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/update/ota_update_dialog.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'doctor@marsa.clinic');
  final _passwordController = TextEditingController(text: 'DoctorPass123!');
  final _totpController = TextEditingController();
  bool _obscurePassword = true;
  String _selectedRole = 'doctor';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  void _selectRolePreset(String role) {
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _selectedRole = role;
      if (role == 'receptionist') {
        _emailController.text = 'receptionist@marsa.clinic';
        _passwordController.text = 'ReceptionPass123!';
      } else {
        _emailController.text = 'doctor@marsa.clinic';
        _passwordController.text = 'DoctorPass123!';
      }
    });
  }

  void _submitLogin() {
    final authState = ref.read(authProvider);
    if (authState.isLoading) return;
    ref.read(authProvider.notifier).login(
          _emailController.text,
          _passwordController.text,
        );
  }

  void _showServerSettingsDialog() {
    final client = ref.read(apiClientProvider);
    final localStore = ref.read(localStoreProvider);
    final urlController = TextEditingController(text: client.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعدادات الاتصال بالخادم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل عنوان خادم العيادة المحلي أو السحابي (Next.js API):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'عنوان الخادم (API Base URL)',
                hintText: 'http://localhost:3000/api',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              client.resetBaseUrl();
              await localStore.clearBaseUrl();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تمت استعادة العنوان الافتراضي: ${client.baseUrl}',
                    ),
                  ),
                );
              }
            },
            child: const Text('استعادة الافتراضي'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              client.setBaseUrl(urlController.text.trim());
              await localStore.saveBaseUrl(client.baseUrl);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم تحديث عنوان الخادم إلى: ${client.baseUrl}',
                    ),
                  ),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMobile
              ? 'عيادة مرساة — بوابة الدخول'
              : 'مرساة — بوابة الكادر الطبي والاستقبال (Flutter App)',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          const OtaUpdateActionButton(),
          IconButton(
            icon: const Icon(Icons.settings_ethernet),
            tooltip: 'إعدادات عنوان الخادم',
            onPressed: _showServerSettingsDialog,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14.0 : 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 18.0 : 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon & Title
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFB58728),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withAlpha(40),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.psychology,
                              size: 40,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'عيادة مرساة',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'د. مارينا نبيه نمر — أخصائي الطب النفسي وعلاج الإدمان',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8E6513),
                      ),
                    ),
                    const SizedBox(height: 28),

                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (!authState.requiresMfa) ...[
                      // Role Selector Pills
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD5E2CE)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectRolePreset('doctor'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedRole == 'doctor'
                                        ? const Color(0xFF45632D)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.medical_services_outlined,
                                        size: 16,
                                        color: _selectedRole == 'doctor'
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'دخول الطبيب',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _selectedRole == 'doctor'
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectRolePreset('receptionist'),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedRole == 'receptionist'
                                        ? const Color(0xFF45632D)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.desk_outlined,
                                        size: 16,
                                        color: _selectedRole == 'receptionist'
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'دخول الاستقبال',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _selectedRole == 'receptionist'
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        onChanged: (val) {
                          ref.read(authProvider.notifier).clearError();
                          final isRecep =
                              val.toLowerCase().contains('reception');
                          if ((isRecep && _selectedRole != 'receptionist') ||
                              (!isRecep && _selectedRole != 'doctor')) {
                            setState(() {
                              _selectedRole =
                                  isRecep ? 'receptionist' : 'doctor';
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني المهني',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        textDirection: TextDirection.ltr,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: (_) =>
                            ref.read(authProvider.notifier).clearError(),
                        onSubmitted: (_) => _submitLogin(),
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور المشفرة',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: authState.isLoading ? null : _submitLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'تسجيل الدخول الآمن',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ] else ...[
                      // MFA TOTP step
                      Text(
                        'تم تفعيل المصادقة الثنائية (MFA) لحساب الطبيب.\nيرجى إدخال الرمز المكون من 6 أرقام من تطبيق Authenticator:',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _totpController,
                        decoration: const InputDecoration(
                          labelText: 'رمز التحقق (TOTP)',
                          hintText: '123456',
                          prefixIcon: Icon(Icons.security),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 22,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: authState.isLoading
                            ? null
                            : () {
                                ref
                                    .read(authProvider.notifier)
                                    .verifyMfa(_totpController.text);
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'تأكيد الرمز والمتابعة',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Offline Tablet Mode Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.wifi_off_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'طبيب (Offline)',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              side: BorderSide(color: Colors.blueGrey.shade300),
                            ),
                            onPressed: () {
                              ref.read(authProvider.notifier).signInOffline();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.wifi_off_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'استقبال (Offline)',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              side: BorderSide(color: Colors.blueGrey.shade300),
                            ),
                            onPressed: () {
                              ref
                                  .read(authProvider.notifier)
                                  .signInOfflineReceptionist();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
