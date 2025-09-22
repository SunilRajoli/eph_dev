// lib/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  bool loading = false;
  String message = "";
  bool success = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email';
    final email = v.trim();
    final regex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    if (!regex.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() {
      loading = true;
      message = "";
      success = false;
    });

    try {
      final res = await ApiService.forgotPassword(emailCtrl.text.trim());
      if (res['success'] == true) {
        setState(() {
          success = true;
          message = res['message'] ?? 'If your email exists, a reset link has been sent.';
        });
      } else {
        // For security best-practice, backend usually returns success regardless.
        setState(() {
          success = false;
          message = res['message'] ?? 'An error occurred. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        success = false;
        message = 'Network error: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.92;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Container(
                width: width,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: const [
                        Icon(Icons.lock_reset, color: Colors.white, size: 36),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Reset your password',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'Enter the email associated with your account. We will send a password reset link if the email exists.',
                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 18),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            validator: _validateEmail,
                            decoration: InputDecoration(
                              hintText: 'Email',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.02),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 14),

                          if (message.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: success ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                message,
                                style: TextStyle(color: success ? Colors.greenAccent : Colors.redAccent),
                              ),
                            ),

                          const SizedBox(height: 12),

                          CustomButton(
                            text: loading ? 'Sending...' : 'Send reset link',
                            onPressed: loading ? null : _submit,
                            enabled: !loading,
                          ),

                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                            child: const Text('Back to Login', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
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
