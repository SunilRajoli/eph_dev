// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  // Student fields
  final collegeCtrl = TextEditingController();
  final branchCtrl = TextEditingController();
  final yearCtrl = TextEditingController();

  // Hiring fields
  final companyCtrl = TextEditingController();
  final websiteCtrl = TextEditingController();
  final teamSizeCtrl = TextEditingController();

  // Investor fields
  final firmCtrl = TextEditingController();
  final investStageCtrl = TextEditingController();
  final firmWebsiteCtrl = TextEditingController();

  bool loading = false;
  String errorMsg = "";
  String? selectedRole;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) selectedRole = args['role'] as String?;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    collegeCtrl.dispose();
    branchCtrl.dispose();
    yearCtrl.dispose();
    companyCtrl.dispose();
    websiteCtrl.dispose();
    teamSizeCtrl.dispose();
    firmCtrl.dispose();
    investStageCtrl.dispose();
    firmWebsiteCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    if (!re.hasMatch(v.trim())) return 'Enter valid email';
    return null;
  }

  Future<void> _handleRegister() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final role = selectedRole ?? 'student';
    if (role == 'admin') {
      setState(() => errorMsg = 'Admin accounts are created by invite only. Use admin magic link.');
      return;
    }

    setState(() {
      loading = true;
      errorMsg = '';
    });

    // Build payload
    final payload = <String, dynamic>{
      'name': nameCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'password': passCtrl.text,
      'role': role,
    };

    // Role-specific fields (only attach when meaningful)
    if (role == 'student') {
      final college = collegeCtrl.text.trim();
      final branch = branchCtrl.text.trim();
      if (college.isNotEmpty) payload['college'] = college;
      if (branch.isNotEmpty) payload['branch'] = branch;
      final parsedYear = int.tryParse(yearCtrl.text.trim());
      if (parsedYear != null) payload['year'] = parsedYear;
    } else if (role == 'hiring') {
      final company = companyCtrl.text.trim();
      final website = websiteCtrl.text.trim();
      if (company.isNotEmpty) payload['company_name'] = company;
      if (website.isNotEmpty) payload['company_website'] = website;
      final parsedTeam = int.tryParse(teamSizeCtrl.text.trim());
      if (parsedTeam != null) payload['team_size'] = parsedTeam;
    } else if (role == 'investor') {
      final firm = firmCtrl.text.trim();
      final stage = investStageCtrl.text.trim();
      final site = firmWebsiteCtrl.text.trim();
      if (firm.isNotEmpty) payload['firm_name'] = firm;
      if (stage.isNotEmpty) payload['investment_stage'] = stage;
      if (site.isNotEmpty) payload['website'] = site;
    }

    // Debug: print payload
    // ignore: avoid_print
    print('Register payload: $payload');

    try {
      final res = await ApiService.registerFromPayload(payload);

      // Debug: print full response
      // ignore: avoid_print
      print('Register response: $res');

      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>?;
        final token = data != null && data['token'] != null ? data['token'] as String : null;
        final user = data != null && data['user'] != null ? Map<String, dynamic>.from(data['user']) : null;
        if (token != null) await AuthService.saveToken(token);
        if (user != null) await AuthService.saveUser(user);
        if (mounted) {
          print('Register success -> navigating to /main');
          Navigator.pushReplacementNamed(context, '/main');
        }
        return;
      }

      // Parse server-side validation errors into a friendly string
      String friendly = '';
      if (res['message'] != null) friendly = res['message'].toString();

      final errors = res['errors'] ?? res['validation'] ?? null;
      if (errors != null) {
        if (errors is Map) {
          final parts = <String>[];
          errors.forEach((k, v) {
            if (v is List) parts.add('$k: ${v.join(", ")}');
            else parts.add('$k: $v');
          });
          friendly = parts.join('\n');
        } else if (errors is List) {
          friendly = errors.map((e) => e.toString()).join('\n');
        } else {
          friendly = errors.toString();
        }
      }

      if (friendly.isEmpty) friendly = res.toString();

      if (mounted) setState(() => errorMsg = friendly);
    } catch (e) {
      if (mounted) setState(() => errorMsg = 'Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  Widget _roleSpecificFields() {
    if (selectedRole == 'student') {
      return Column(
        children: [
          TextFormField(
            controller: collegeCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'College',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              prefixIcon: const Icon(Icons.school, color: Colors.white70),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: branchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Branch',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              prefixIcon: const Icon(Icons.account_tree, color: Colors.white70),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: yearCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Year (e.g. 3)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              prefixIcon: const Icon(Icons.calendar_today, color: Colors.white70),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      );
    } else if (selectedRole == 'hiring') {
      return Column(
        children: [
          TextFormField(
            controller: companyCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Company name',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              prefixIcon: const Icon(Icons.business, color: Colors.white70),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: websiteCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Company website',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              prefixIcon: const Icon(Icons.link, color: Colors.white70),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: teamSizeCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Team size',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              prefixIcon: const Icon(Icons.group, color: Colors.white70),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      );
    } else if (selectedRole == 'investor') {
      return Column(
        children: [
          TextFormField(
            controller: firmCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Firm / Angel name',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              prefixIcon: const Icon(Icons.account_balance, color: Colors.white70),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: investStageCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Investment stage (seed/series A)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              prefixIcon: const Icon(Icons.timeline, color: Colors.white70),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: firmWebsiteCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Website / portfolio',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              prefixIcon: const Icon(Icons.link, color: Colors.white70),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.92;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pushReplacementNamed(context, '/roles')),
        actions: [
          if (selectedRole != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20)),
                  child: Text(selectedRole!.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
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
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: Column(
                children: [
                  // header
                  Row(
                    children: [
                      Container(width: 46, height: 46, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)), child: const Icon(Icons.person_add, color: Colors.white)),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Create account', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(controller: nameCtrl, style: const TextStyle(color: Colors.white), validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null, decoration: InputDecoration(hintText: 'Full name', hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)), filled: true, fillColor: Colors.white.withOpacity(0.02), prefixIcon: const Icon(Icons.person_outline, color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                        const SizedBox(height: 10),
                        TextFormField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), validator: _validateEmail, decoration: InputDecoration(hintText: 'Email', hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)), filled: true, fillColor: Colors.white.withOpacity(0.02), prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                        const SizedBox(height: 10),
                        TextFormField(controller: passCtrl, obscureText: true, style: const TextStyle(color: Colors.white), validator: (v) => (v == null || v.length < 6) ? '6+ chars' : null, decoration: InputDecoration(hintText: 'Password', hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)), filled: true, fillColor: Colors.white.withOpacity(0.02), prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                        const SizedBox(height: 12),
                        // role-specific fields
                        _roleSpecificFields(),
                        const SizedBox(height: 12),
                        if (errorMsg.isNotEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade800.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(errorMsg, style: const TextStyle(color: Colors.redAccent))),
                        const SizedBox(height: 12),
                        CustomButton(text: loading ? 'Creating...' : 'Register', onPressed: loading ? null : _handleRegister, enabled: !loading),
                        const SizedBox(height: 12),
                        TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/login', arguments: {'role': selectedRole}), child: const Text('Already have account? Login', style: TextStyle(color: Colors.white70))),
                      ],
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
