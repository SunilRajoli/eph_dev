import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/competition_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
// import 'screens/competition_register_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const EPHApp());
}

class EPHApp extends StatelessWidget {
  const EPHApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Engineering Projects Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/competitions': (context) => const CompetitionScreen(),
        '/roles': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        // '/competitions/register': (context) => const CompetitionRegisterScreen(),
        // '/competitions/:id': (ctx) => CompetitionDetailScreen(),
      },
    );
  }
}
