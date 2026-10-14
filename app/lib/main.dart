import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/receptionist/screens/receptionist_dashboard_screen.dart';
import 'features/schedule/screens/doctor_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Arabic locale data for DateFormat to prevent any crash
  try {
    await initializeDateFormatting('ar', null);
  } catch (_) {}

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

/// Root widget for the مرساة mobile & tablet application.
///
/// Configures Arabic RTL directionality, Cairo typography,
/// Material 3 clinical theme, and dynamic role-based routing (Doctor / Receptionist).
class MarsaApp extends ConsumerWidget {
  const MarsaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    Widget homeScreen;
    if (!authState.isAuthenticated) {
      homeScreen = const LoginScreen();
    } else if (authState.user?.role == 'receptionist') {
      homeScreen = const ReceptionistDashboardScreen();
    } else {
      homeScreen = const DoctorDashboardScreen();
    }

    return MaterialApp(
      title: 'مرساة — منصة العيادة',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ar', 'EG'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: homeScreen,
    );
  }
}
