import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;
  bool _editing = false;

  // Controllers for editable fields
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _collegeCtrl = TextEditingController();
  final TextEditingController _branchCtrl = TextEditingController();
  final TextEditingController _yearCtrl = TextEditingController();
  final TextEditingController _skillsInputCtrl = TextEditingController();

  List<String> _skills = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _collegeCtrl.dispose();
    _branchCtrl.dispose();
    _yearCtrl.dispose();
    _skillsInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Load saved user (if any)
      final local = await AuthService.getUser();
      if (local != null) {
        _applyUserToForm(local);
        setState(() => _user = local);
      }

      // 2) Try to fetch latest profile from API (if logged in)
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        final res = await ApiService.getProfile(token);
        if (res['success'] == true) {
          final data = res['data'] as Map<String, dynamic>?;
          final remoteUser = data != null && data['user'] != null
              ? Map<String, dynamic>.from(data['user'])
              : null;
          if (remoteUser != null) {
            await AuthService.saveUser(remoteUser); // keep local in sync
            _applyUserToForm(remoteUser);
            if (mounted) setState(() => _user = remoteUser);
          }
        } else {
          if (mounted) setState(() => _error = res['message'] ?? 'Failed to load profile');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyUserToForm(Map<String, dynamic> user) {
    _nameCtrl.text = (user['name'] ?? '').toString();
    _collegeCtrl.text = (user['college'] ?? '').toString();
    _branchCtrl.text = (user['branch'] ?? '').toString();
    _yearCtrl.text = (user['year'] ?? '').toString();

    final skillsField = user['skills'];
    if (skillsField is List) {
      _skills = skillsField.map((s) => s.toString()).toList();
    } else if (skillsField is String) {
      _skills = skillsField.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else {
      _skills = [];
    }
  }

  void _addSkillsFromInput() {
    final raw = _skillsInputCtrl.text.trim();
    if (raw.isEmpty) return;
    final parts = raw.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
    setState(() {
      for (final p in parts) {
        if (!_skills.contains(p)) _skills.add(p);
      }
      _skillsInputCtrl.clear();
    });
  }

  void _removeSkill(String s) {
    setState(() => _skills.remove(s));
  }

  Future<void> _saveProfile() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to update profile')));
      return;
    }

    // Basic validation for year
    int? year;
    if (_yearCtrl.text.trim().isNotEmpty) {
      year = int.tryParse(_yearCtrl.text.trim());
      if (year == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Year must be a number')));
        return;
      }
    }

    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'college': _collegeCtrl.text.trim(),
      'branch': _branchCtrl.text.trim(),
      'year': year,
      'skills': _skills,
    };

    try {
      final res = await ApiService.updateProfile(token, payload);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>?;
        final updatedUser = data != null && data['user'] != null ? Map<String, dynamic>.from(data['user']) : null;
        if (updatedUser != null) {
          // Persist locally and update UI
          await AuthService.saveUser(updatedUser);
          setState(() {
            _user = updatedUser;
            _editing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
        } else {
          setState(() => _error = 'Profile updated but response malformed');
        }
      } else {
        setState(() => _error = res['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      setState(() => _error = 'Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.clearToken();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/roles');
  }

  Widget _labelValue(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white70))),
        Expanded(child: Text(value == null || value.isEmpty ? '-' : value, style: const TextStyle(color: Colors.white))),
      ],
    );
  }

  Widget _chip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white70)),
      backgroundColor: Colors.white.withOpacity(0.04),
      onDeleted: _editing ? () => _removeSkill(text) : null,
    );
  }

  Widget _topHeader() {
    // Transparent AppBar with small rounded card (same as competitions header)
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: kToolbarHeight + 8,
      titleSpacing: 12,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(gradient: AppTheme.gradient, shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.engineering, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EPH', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14)),
                // show profile name (or 'Profile') as a small subtitle
                Text(
                  _user != null && (_user!['name'] ?? '').toString().isNotEmpty ? _user!['name'].toString() : 'Profile',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            // Edit / Cancel action moved inside header card to match competitions navbar
            if (!_editing)
              TextButton(
                onPressed: _user == null ? null : () => setState(() => _editing = true),
                child: const Text('Edit', style: TextStyle(color: Colors.white)),
              )
            else
              TextButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Let the gradient show behind the AppBar
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(kToolbarHeight), child: _topHeader()),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Top card with name, role, xp, badges
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // name + role
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _user?['name'] ?? '-',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              (_user?['role'] ?? 'student').toString().toUpperCase(),
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _infoChip('XP', (_user?['xp'] ?? 0).toString()),
                          const SizedBox(width: 8),
                          _infoChip('Badges', ((_user?['badges'] as List<dynamic>?)?.length ?? 0).toString()),
                          const SizedBox(width: 8),
                          _infoChip('Verified', (_user?['verified'] == true) ? 'Yes' : 'No'),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email (read-only)
                      _labelValue('Email', _user?['email']?.toString()),
                      const SizedBox(height: 12),

                      // Name (editable)
                      _editing
                          ? TextField(
                        controller: _nameCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Full name', labelStyle: TextStyle(color: Colors.white70)),
                      )
                          : _labelValue('Name', _user?['name']?.toString()),
                      const SizedBox(height: 12),

                      // College
                      _editing
                          ? TextField(
                        controller: _collegeCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'College', labelStyle: TextStyle(color: Colors.white70)),
                      )
                          : _labelValue('College', _user?['college']?.toString()),
                      const SizedBox(height: 12),

                      // Branch
                      _editing
                          ? TextField(
                        controller: _branchCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Branch', labelStyle: TextStyle(color: Colors.white70)),
                      )
                          : _labelValue('Branch', _user?['branch']?.toString()),
                      const SizedBox(height: 12),

                      // Year
                      _editing
                          ? TextField(
                        controller: _yearCtrl,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Year', labelStyle: TextStyle(color: Colors.white70)),
                      )
                          : _labelValue('Year', _user?['year']?.toString()),

                      const SizedBox(height: 14),

                      // Skills
                      const Text('Skills', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: _skills.map((s) => _chip(s)).toList()),
                      if (_editing) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _skillsInputCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(hintText: 'Add skill (comma to add multiple)', hintStyle: TextStyle(color: Colors.white60)),
                                onSubmitted: (_) => _addSkillsFromInput(),
                              ),
                            ),
                            IconButton(onPressed: _addSkillsFromInput, icon: const Icon(Icons.add, color: Colors.white70))
                          ],
                        )
                      ],

                      const SizedBox(height: 12),

                      // last_login & is_active summary (read-only)
                      _labelValue('Last active', _user?['last_login']?.toString()),
                      const SizedBox(height: 8),
                      _labelValue('Active', (_user?['is_active'] == true) ? 'Yes' : 'No'),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ],

                      const SizedBox(height: 18),

                      // Save / Logout buttons
                      if (_editing)
                        ElevatedButton(
                          onPressed: _saving ? null : _saveProfile,
                          child: Text(_saving ? 'Saving...' : 'Save changes'),
                        )
                      else
                        ElevatedButton(
                          onPressed: _logout,
                          child: const Text('Logout'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
