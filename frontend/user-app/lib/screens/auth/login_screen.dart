import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/apex_loading.dart';
import '../../services/auth_service.dart';
import '../../services/token_storage.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onGoToRegister;

  const LoginScreen({super.key, required this.onLogin, required this.onGoToRegister});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _localAuth = LocalAuthentication();
  bool _obscure = true;
  bool _isLoading = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final storage = TokenStorage();
    final enabled = await storage.isBiometricEnabled();
    if (mounted) setState(() => _biometricEnabled = enabled);
  }

  Future<void> _handleBiometricLogin() async {
    final storage = TokenStorage();
    final email = await storage.getBiometricEmail();
    final refreshToken = await storage.getBiometricRefreshToken();

    if (email == null || refreshToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric credentials not found. Please sign in with password.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to sign in',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!authenticated) return;

      setState(() => _isLoading = true);
      final authService = AuthService();
      await authService.refreshToken();
      if (mounted) widget.onLogin();
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = context.colors;
    return Scaffold(
      backgroundColor: tc.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  Center(
                    child: Image.asset(
                      'assets/images/apex_no_bg.png',
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Welcome Back',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: tc.text),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Sign in to your APEX Housing account',
                      style: TextStyle(fontSize: 15, color: tc.subtitle),
                    ),
                  ),
                  const SizedBox(height: 48),
                  _label('Email', tc),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'Enter your email'),
                  ),
                  const SizedBox(height: 24),
                  _label('Password', tc),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: tc.hint, size: 22),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                final authService = AuthService();
                                await authService.login(
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text,
                                );
                                if (mounted) {
                                  widget.onLogin();
                                }
                              } on Exception catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                  );
                                  setState(() => _isLoading = false);
                                }
                              }
                            },
                      child: const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_biometricEnabled) ...[
                    Center(
                      child: GestureDetector(
                        onTap: _isLoading ? null : _handleBiometricLogin,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.08),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
                          ),
                          child: const Icon(Icons.fingerprint_rounded, size: 36, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Sign in with fingerprint',
                        style: TextStyle(fontSize: 13, color: tc.subtitle),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: tc.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('or continue with', style: TextStyle(color: tc.hint, fontSize: 13)),
                      ),
                      Expanded(child: Divider(color: tc.border)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: _socialButton(Icons.g_mobiledata, 'Google', tc, _handleGoogleSignIn)),
                      const SizedBox(width: 14),
                      Expanded(child: _socialButton(Icons.apple, 'Apple', tc, _handleAppleComingSoon)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: GestureDetector(
                      onTap: widget.onGoToRegister,
                      child: Text.rich(
                        TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(color: tc.subtitle, fontSize: 14),
                          children: const [
                            TextSpan(text: 'Register', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (_isLoading) const ApexLoadingFull(label: 'Signing in...'),
        ],
      ),
    );
  }

  Widget _label(String text, ThemeColors tc) {
    return Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tc.text));
  }

  Widget _socialButton(IconData icon, String label, ThemeColors tc, VoidCallback? onPressed) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: tc.border),
        foregroundColor: tc.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authService = AuthService();
      await authService.signInWithGoogle();
      if (mounted) widget.onLogin();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleAppleComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Apple Sign-In coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
