import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/schedule/screens/doctor_dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure status bar and navigation styling for tablet clinical environment
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.primaryNavy,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: MarsaApp(),
    ),
  );
}

/// Root widget for the مرساة tablet application.
///
/// Configures Arabic RTL directionality, Cairo typography,
/// Material 3 clinical theme, and dynamic authentication routing.
class MarsaApp extends ConsumerWidget {
  const MarsaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'مرساة — لوحة الطبيب',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: authState.isAuthenticated
          ? const DoctorDashboardScreen()
          : const LoginScreen(),
    );
  }
}
