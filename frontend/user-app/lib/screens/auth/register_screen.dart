import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final void Function(String email) onRegister;
  final VoidCallback onGoToLogin;

  const RegisterScreen({super.key, required this.onRegister, required this.onGoToLogin});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'TENANT';
  bool _obscure = true;
  bool _agreeTerms = false;
  bool _isLoading = false;

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
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryLight, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text('Join APEX Housing today', style: TextStyle(fontSize: 15, color: tc.subtitle)),
                  const SizedBox(height: 40),
                  _label('Full Name'),
                  const SizedBox(height: 10),
                  TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Enter your full name')),
                  const SizedBox(height: 24),
                  _label('Email'),
                  const SizedBox(height: 10),
                  TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Enter your email')),
                  const SizedBox(height: 24),
                  _label('Password'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: 'Create a password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: tc.hint, size: 22),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _label('I am a'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _roleChip('Tenant', 'TENANT'),
                      const SizedBox(width: 12),
                      _roleChip('Landlord', 'LANDLORD'),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agreeTerms,
                          onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                          child: Text.rich(
                            TextSpan(
                              text: 'I agree to the ',
                              style: TextStyle(fontSize: 13, color: tc.subtitle),
                              children: [
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                  recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse('https://www.apex-housing.online/terms'), mode: LaunchMode.externalApplication),
                                ),
                                TextSpan(text: ' and ', style: TextStyle(color: tc.subtitle)),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                  recognizer: TapGestureRecognizer()..onTap = () => launchUrl(Uri.parse('https://www.apex-housing.online/privacy'), mode: LaunchMode.externalApplication),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_agreeTerms && !_isLoading)
                          ? () async {
                              setState(() => _isLoading = true);
                              try {
                                final fullName = _nameController.text.trim();
                                final parts = fullName.split(RegExp(r'\s+'));
                                final firstName = parts.isNotEmpty ? parts.first : '';
                                final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

                                final data = await AuthService().register(
                                  email: _emailController.text.trim(),
                                  password: _passwordController.text,
                                  role: _role,
                                  firstName: firstName,
                                  lastName: lastName,
                                );
                                if (mounted) {
                                  if (data['redirect_to_login'] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Account already exists. Please login.'),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                    widget.onGoToLogin();
                                  } else {
                                    widget.onRegister(_emailController.text.trim());
                                  }
                                }
                              } on Exception catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                  );
                                  setState(() => _isLoading = false);
                                }
                              }
                            }
                          : null,
                      child: const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: GestureDetector(
                      onTap: widget.onGoToLogin,
                      child: Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: tc.subtitle, fontSize: 14),
                          children: const [
                            TextSpan(text: 'Login', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isLoading) const ApexLoadingFull(label: 'Creating account...'),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
  }

  Widget _roleChip(String label, String value) {
    final tc = context.colors;
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : tc.card,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: selected ? AppColors.primary : tc.border),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : tc.subtitle,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
