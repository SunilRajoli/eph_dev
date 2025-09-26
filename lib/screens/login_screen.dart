// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;
  bool oauthLoading = false;
  String errorMsg = "";
  String? selectedRole;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      selectedRole = args['role'] as String?;
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    if (!re.hasMatch(v.trim())) return 'Enter valid email';
    return null;
  }

  Future<void> _handleLogin() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() {
      loading = true;
      errorMsg = '';
    });

    try {
      final res = await ApiService.login(
        emailCtrl.text.trim(),
        passCtrl.text,
        role: selectedRole,
      );

      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>?;
        final token = data?['token'] as String?;
        final user = data?['user'] as Map<String, dynamic>?;

        if (token != null) await AuthService.saveToken(token);
        if (user != null) await AuthService.saveUser(user);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        }
        return;
      }

      String friendly = res['message']?.toString() ?? 'Login failed';
      if (mounted) setState(() => errorMsg = friendly);
    } catch (e) {
      if (mounted) {
        setState(() => errorMsg = 'Network error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _handleOAuthLogin(String provider) async {
    setState(() {
      oauthLoading = true;
      errorMsg = '';
    });

    try {
      final result = await ApiService.initiateOAuth(provider);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Redirecting to ${provider.toUpperCase()}...'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => errorMsg = result['message'] ?? 'OAuth login failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMsg = 'OAuth error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => oauthLoading = false);
    }
  }

  Widget _oauthSideButton({
    required String provider,
    required Widget iconWidget,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 46,
        child: ElevatedButton.icon(
          onPressed: oauthLoading ? null : onTap,
          icon: iconWidget,
          label: Text(
            provider,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            disabledBackgroundColor: bgColor.withOpacity(0.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.92;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/roles'),
        ),
        actions: [
          if (selectedRole != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    selectedRole!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Container(
              width: width,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.06),
                        ),
                        child: const Icon(Icons.login, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Welcome back',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Email/Password Form
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
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.02),
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passCtrl,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          validator: (v) => (v == null || v.length < 6) ? '6+ chars' : null,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.02),
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Error Message
                        if (errorMsg.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade800.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              errorMsg,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Login Button
                        CustomButton(
                          text: loading ? 'Signing in...' : 'Login',
                          onPressed: loading ? null : _handleLogin,
                          enabled: !loading && !oauthLoading,
                        ),

                        const SizedBox(height: 12),

                        // Register Link
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            '/register',
                            arguments: {'role': selectedRole},
                          ),
                          child: const Text(
                            "Don't have an account? Register",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Divider with OR
                  Row(
                    children: [
                      Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.2))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                      ),
                      Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.2))),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // OAuth Buttons side-by-side (improved UI)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: oauthLoading ? null : () => _handleOAuthLogin('google'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: oauthLoading ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // prefer an asset; fallback to icon if missing
                                Image.asset(
                                  'assets/google.png',
                                  height: 20,
                                  width: 20,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.white70),
                                ),
                                const SizedBox(width: 10),
                                const Text('Continue with Google', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: oauthLoading ? null : () => _handleOAuthLogin('github'),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: oauthLoading ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.code, color: Colors.white70),
                                SizedBox(width: 10),
                                Text('Continue with GitHub', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // small note about oauth
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      oauthLoading ? 'Opening provider...' : 'Sign in quickly using external providers',
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
