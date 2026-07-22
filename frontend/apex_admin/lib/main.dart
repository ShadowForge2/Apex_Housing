import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'screens/admin_shell.dart';
import 'screens/auth/admin_splash_screen.dart';
import 'screens/auth/admin_login_screen.dart';
import 'screens/auth/admin_signup_screen.dart';
import 'screens/auth/admin_forgot_password_screen.dart';
import 'services/token_storage.dart';
import 'services/admin_auth_service.dart';
import 'services/security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run security checks (non-blocking, logs warnings)
  SecurityService.instance.runChecks().then((_) {
    final report = SecurityService.instance.getReport();
    if (report['compromised'] == true) {
      debugPrint('[SECURITY] Device compromise detected: $report');
    }
  });

  runApp(const ApexAdminApp());
}

class ApexAdminApp extends StatelessWidget {
  const ApexAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APEX Housing Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AdminAuthFlow(),
    );
  }
}

enum AuthScreen { splash, login, signup, forgotPassword, shell }

class AdminAuthFlow extends StatefulWidget {
  const AdminAuthFlow({super.key});

  @override
  State<AdminAuthFlow> createState() => _AdminAuthFlowState();
}

class _AdminAuthFlowState extends State<AdminAuthFlow> {
  AuthScreen _currentScreen = AuthScreen.splash;

  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    final storage = TokenStorage();
    final loggedIn = await storage.isLoggedIn();
    if (loggedIn && mounted) {
      setState(() {
        _currentScreen = AuthScreen.shell;
      });
    }
  }

  void _onSplashComplete() {
    _checkLoginState().then((_) {
      if (mounted && _currentScreen == AuthScreen.splash) {
        setState(() => _currentScreen = AuthScreen.login);
      }
    });
  }

  void _onLogin() async {
    if (mounted) {
      setState(() {
        _currentScreen = AuthScreen.shell;
      });
    }
  }

  void _onSignup() async {
    if (mounted) {
      setState(() {
        _currentScreen = AuthScreen.shell;
      });
    }
  }

  void _goToSignup() {
    setState(() => _currentScreen = AuthScreen.signup);
  }

  void _goToLogin() {
    setState(() => _currentScreen = AuthScreen.login);
  }

  void _goToForgotPassword() {
    setState(() => _currentScreen = AuthScreen.forgotPassword);
  }

  void _onForgotPasswordComplete() {
    setState(() => _currentScreen = AuthScreen.login);
  }

  void _onLogout() async {
    await AdminAuthService().logout();
    if (mounted) {
      setState(() => _currentScreen = AuthScreen.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentScreen) {
      case AuthScreen.splash:
        return AdminSplashScreen(onComplete: _onSplashComplete);
      case AuthScreen.login:
        return AdminLoginScreen(
          onLogin: _onLogin,
          onGoToSignup: _goToSignup,
          onGoToForgotPassword: _goToForgotPassword,
        );
      case AuthScreen.signup:
        return AdminSignupScreen(
          onSignup: _onSignup,
          onGoToLogin: _goToLogin,
        );
      case AuthScreen.forgotPassword:
        return AdminForgotPasswordScreen(
          onComplete: _onForgotPasswordComplete,
        );
      case AuthScreen.shell:
        return AdminShell(
          onLogout: _onLogout,
        );
    }
  }
}
