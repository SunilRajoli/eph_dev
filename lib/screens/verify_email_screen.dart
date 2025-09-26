// lib/screens/verify_email_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';
import '../services/api_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String? token;
  final String? email;

  const VerifyEmailScreen({super.key, this.token, this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool loading = false;
  bool resendingEmail = false;
  String message = "";
  bool success = false;
  String? token;
  String? email;

  @override
  void initState() {
    super.initState();
    token = widget.token;
    email = widget.email;

    // If token is provided, automatically verify
    if (token != null && token!.isNotEmpty) {
      _verifyEmail();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If token passed via route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      if (args['token'] != null) {
        token = args['token'] as String;
      }
      if (args['email'] != null) {
        email = args['email'] as String;
      }

      // Auto verify if token is available and we haven't tried yet
      if (token != null && token!.isNotEmpty && !loading && message.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _verifyEmail());
      }
    }
  }

  Future<void> _verifyEmail() async {
    if (token == null || token!.isEmpty) {
      setState(() {
        message = 'No verification token found. Please check your email for the verification link.';
        success = false;
      });
      return;
    }

    setState(() {
      loading = true;
      message = "";
    });

    try {
      final res = await ApiService.verifyEmail(token!);
      if (res['success'] == true) {
        setState(() {
          success = true;
          message = res['message'] ?? 'Email verified successfully! Welcome to EPH Platform.';
        });

        // Small delay then navigate to login
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login', arguments: {
            'message': 'Email verified! You can now log in.',
            'email': email
          });
        }
      } else {
        setState(() {
          success = false;
          message = res['message'] ?? 'Verification failed. The token may be invalid or expired.';
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

  Future<void> _resendVerificationEmail() async {
    if (email == null || email!.isEmpty) {
      setState(() {
        message = 'Email address not available for resending verification.';
        success = false;
      });
      return;
    }

    setState(() {
      resendingEmail = true;
      message = "";
    });

    try {
      final res = await ApiService.resendVerificationEmail(email!);
      if (res['success'] == true) {
        setState(() {
          success = true;
          message = res['message'] ?? 'Verification email sent! Please check your inbox.';
        });
      } else {
        setState(() {
          success = false;
          message = res['message'] ?? 'Failed to resend verification email.';
        });
      }
    } catch (e) {
      setState(() {
        success = false;
        message = 'Network error: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => resendingEmail = false);
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
                      children: [
                        Icon(
                            success ? Icons.check_circle : Icons.email_outlined,
                            color: success ? Colors.green : Colors.white,
                            size: 36
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                              success ? 'Email Verified!' : 'Verify Your Email',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800
                              )
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    if (email != null)
                      Text(
                        'Verification for: $email',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14
                        ),
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 12),

                    if (loading)
                      Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Verifying your email...',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14
                            ),
                          ),
                        ],
                      )
                    else if (message.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: success ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                              color: success ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 14
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 20),

                    if (!success && !loading) ...[
                      // Show resend button if verification failed
                      if (email != null && email!.isNotEmpty)
                        CustomButton(
                          text: resendingEmail ? 'Sending...' : 'Resend Verification Email',
                          onPressed: resendingEmail ? null : _resendVerificationEmail,
                          enabled: !resendingEmail,
                        ),

                      const SizedBox(height: 12),

                      // Manual verification attempt if token is available
                      if (token != null && token!.isNotEmpty)
                        CustomButton(
                          text: 'Try Again',
                          onPressed: _verifyEmail,
                          enabled: true,
                        ),
                    ],

                    if (success)
                      Column(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.greenAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'You can close this window.',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'Continue to Login',
                            onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                '/login',
                                arguments: {
                                  'message': 'Email verified! You can now log in.',
                                  'email': email
                                }
                            ),
                            enabled: true,
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                          'Back to Login',
                          style: TextStyle(color: Colors.white70)
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