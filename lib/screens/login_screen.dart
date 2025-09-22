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

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;
  String errorMsg = "";
  bool obscure = true;
  String? selectedRole;

  late final AnimationController _btnAnimController;
  late final Animation<double> _btnScaleAnim;

  @override
  void initState() {
    super.initState();
    _btnAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
    _btnScaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _btnAnimController, curve: Curves.easeOut),
    );
  }

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
    _btnAnimController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    if (!re.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 chars';
    return null;
  }

  Future<void> _handleLogin() async {
    // Admin flow: send magic link
    if (selectedRole != null && selectedRole == 'admin') {
      final emailOk = _validateEmail(emailCtrl.text) == null;
      if (!emailOk) {
        setState(() => errorMsg = 'Please enter a valid admin email');
        return;
      }
      setState(() {
        loading = true;
        errorMsg = '';
      });
      try {
        final res = await ApiService.sendAdminMagicLink(emailCtrl.text.trim());
        setState(() {
          errorMsg = res['message'] ?? 'If this admin exists, a magic link was sent.';
        });
      } catch (e) {
        setState(() => errorMsg = 'Network error: ${e.toString()}');
      } finally {
        if (mounted) setState(() => loading = false);
      }
      return;
    }

    // Normal login for student/hiring/investor
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

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
        final token = data != null && data['token'] != null ? data['token'] as String : null;
        final user = data != null && data['user'] != null ? Map<String, dynamic>.from(data['user']) : null;
        if (token != null) await AuthService.saveToken(token);
        if (user != null) await AuthService.saveUser(user);
        if (mounted) {
          print('Login success -> navigating to /main');
          Navigator.pushReplacementNamed(context, '/main');
        }
      } else {
        setState(() => errorMsg = res['message'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => errorMsg = 'Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _buildAdminNote() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Admin login uses a magic link sent to your email. Open the link to sign in.',
        style: TextStyle(color: Colors.white70, fontSize: 12),
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
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: Center(
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          child: const Icon(Icons.engineering, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Welcome back',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Admin special: only email + magic link
                    if (selectedRole != null && selectedRole == 'admin') ...[
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Admin email',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildAdminNote(),
                      const SizedBox(height: 8),
                      CustomButton(
                        text: loading ? 'Sending...' : 'Send magic link',
                        onPressed: loading ? null : _handleLogin,
                        enabled: !loading,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/register', arguments: {'role': selectedRole}),
                        child: const Text('Register (admins via invite only)', style: TextStyle(color: Colors.white70)),
                      ),
                    ] else ...[
                      // Normal login form for other roles
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
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: passCtrl,
                              obscureText: obscure,
                              style: const TextStyle(color: Colors.white),
                              validator: _validatePassword,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.02),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                suffixIcon: IconButton(
                                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                                  onPressed: () => setState(() => obscure = !obscure),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                                  child: const Text('Forgot password?', style: TextStyle(color: Colors.white70)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/register', arguments: {'role': selectedRole}),
                                  child: const Text("Don't have an account? Register", style: TextStyle(color: Colors.white70)),
                                ),
                              ],
                            ),
                            if (errorMsg.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.red.shade800.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: Text(errorMsg, style: const TextStyle(color: Colors.redAccent)),
                              ),
                              const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTapDown: (_) => _btnAnimController.forward(),
                              onTapUp: (_) => _btnAnimController.reverse(),
                              onTapCancel: () => _btnAnimController.reverse(),
                              child: AnimatedBuilder(
                                animation: _btnScaleAnim,
                                builder: (context, child) => Transform.scale(scale: _btnScaleAnim.value, child: child),
                                child: CustomButton(text: loading ? 'Logging in...' : 'Login', onPressed: loading ? null : _handleLogin, enabled: !loading),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or', style: TextStyle(color: Colors.white70))),
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google login not wired'))),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset('assets/google.png', height: 18, width: 18, errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.white70)),
                                    const SizedBox(width: 8),
                                    const Text('Google', style: TextStyle(color: Colors.white70)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GitHub login not wired'))),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.code, color: Colors.white70),
                                    SizedBox(width: 8),
                                    Text('GitHub', style: TextStyle(color: Colors.white70)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
