// lib/screens/reset_password_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../services/api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  // Optionally accept token via constructor or route arguments
  final String? token;
  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final passCtrl = TextEditingController();
  final pass2Ctrl = TextEditingController();
  bool loading = false;
  String message = "";
  bool success = false;
  String? token;

  @override
  void initState() {
    super.initState();
    token = widget.token;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If token passed via route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args['token'] != null) {
      token = args['token'] as String;
    }
  }

  @override
  void dispose() {
    passCtrl.dispose();
    pass2Ctrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Use 6+ characters';
    return null;
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;
    if (passCtrl.text != pass2Ctrl.text) {
      setState(() {
        message = 'Passwords do not match';
        success = false;
      });
      return;
    }
    if (token == null || token!.isEmpty) {
      setState(() {
        message = 'Missing reset token. Use the link sent to your email.';
        success = false;
      });
      return;
    }

    setState(() {
      loading = true;
      message = "";
    });

    try {
      final res = await ApiService.resetPassword(token!, passCtrl.text);
      if (res['success'] == true) {
        setState(() {
          success = true;
          message = res['message'] ?? 'Password reset successful. Please login.';
        });
        // Small delay then go to login
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          success = false;
          message = res['message'] ?? 'Reset failed. The token may be invalid or expired.';
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
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lock, color: Colors.white, size: 36),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Set a new password', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (token != null)
                      Text('Using token: ${token!.substring(0, token!.length > 8 ? 8 : token!.length)}... (hidden)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 12),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: passCtrl,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            validator: _validatePassword,
                            decoration: InputDecoration(
                              hintText: 'New password',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.02),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: pass2Ctrl,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            validator: _validatePassword,
                            decoration: InputDecoration(
                              hintText: 'Confirm password',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.02),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (message.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: success ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(message, style: TextStyle(color: success ? Colors.greenAccent : Colors.redAccent)),
                            ),

                          const SizedBox(height: 12),

                          CustomButton(
                            text: loading ? 'Saving...' : 'Save new password',
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
