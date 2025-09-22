import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/role_card.dart';
import '../theme/app_theme.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole;

  final List<Map<String, dynamic>> roles = [
    {
      'key': 'student',
      'title': 'Student',
      'subtitle': 'Showcase projects & join competitions',
      'icon': Icons.school,
    },
    {
      'key': 'hiring',
      'title': 'Hiring',
      'subtitle': 'Discover talents & post opportunities',
      'icon': Icons.work,
    },
    {
      'key': 'investor',
      'title': 'Investor',
      'subtitle': 'Find startups & promising projects',
      'icon': Icons.monetization_on,
    },
    {
      'key': 'admin',
      'title': 'Admin',
      'subtitle': 'Manage competitions & platform',
      'icon': Icons.admin_panel_settings,
    },
  ];

  void _onSelect(String key) {
    setState(() {
      selectedRole = key;
    });
  }

  void _continue() {
    if (selectedRole == null) return;
    Navigator.pushNamed(context, '/login', arguments: {'role': selectedRole});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use the same gradient background as Splash
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    // small circle/logo placeholder
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                      ),
                      child: const Icon(Icons.engineering, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Choose your role',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // optional: skip selection
                        Navigator.pushNamed(context, '/login');
                      },
                      child: const Text('Skip', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Intro card / subtitle
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: const Text(
                    'Select a role that best describes you. This helps tailor the experience and show relevant content.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),

                const SizedBox(height: 18),

                // Role list (vertical)
                Expanded(
                  child: ListView.separated(
                    itemCount: roles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final r = roles[idx];
                      final key = r['key'] as String;
                      return RoleCard(
                        title: r['title'],
                        subtitle: r['subtitle'],
                        icon: r['icon'] as IconData,
                        selected: selectedRole == key,
                        onTap: () => _onSelect(key),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Continue button
                CustomButton(
                  text: selectedRole == null ? 'Select a role to continue' : 'Continue as ${selectedRole!.toUpperCase()}',
                  enabled: selectedRole != null,
                  onPressed: _continue,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can change role later in profile settings.',
                  style: TextStyle(color: Colors.white.withOpacity(0.76), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
