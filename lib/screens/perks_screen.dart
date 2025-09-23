// lib/screens/perks_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class PerksScreen extends StatefulWidget {
  const PerksScreen({super.key});

  @override
  State<PerksScreen> createState() => _PerksScreenState();
}

class _PerksScreenState extends State<PerksScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _perks = [];

  // auth state for header
  bool _isLoggedIn = false;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadPerks();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    try {
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        final user = await AuthService.getUser();
        if (mounted) setState(() {
          _isLoggedIn = true;
          _currentUser = user;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() {
      _isLoggedIn = false;
      _currentUser = null;
    });
  }

  Future<void> _loadPerks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.getPerks(limit: 50);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>?;
        final list = (data != null && data['perks'] != null)
            ? List<Map<String, dynamic>>.from(data['perks'])
            : <Map<String, dynamic>>[];
        setState(() => _perks = list);
      } else {
        setState(() => _error = res['message'] ?? 'Failed to load perks');
      }
    } catch (e) {
      setState(() => _error = 'Network error: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _redeem(String id) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      // prompt login
      final r = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Login required'),
          content: const Text('You need to be logged in to redeem perks. Login now?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Login')),
          ],
        ),
      );
      if (r == true) {
        await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'login'});
        await _checkAuth();
      }
      return;
    }

    // redeem
    setState(() => _loading = true);
    final res = await ApiService.redeemPerk(id);
    setState(() => _loading = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Redeemed')));
      _loadPerks();
    } else {
      final message = res['message'] ?? 'Failed to redeem';
      final reasons = res['reasons'];
      final text = reasons != null ? '$message: ${(reasons as List).join(', ')}' : message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.clearToken();
    await _checkAuth();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out')));
  }

  Widget _topHeader() {
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
            const Text('EPH', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Perks', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            if (_isLoggedIn)
              Row(
                children: [
                  if (_currentUser != null) ...[
                    Text((_currentUser!['name'] ?? 'User').toString(), style: const TextStyle(color: Colors.white70)),
                    const SizedBox(width: 8),
                  ],
                  PopupMenuButton<String>(
                    color: Colors.black87,
                    onSelected: (val) async {
                      if (val == 'logout') await _handleLogout();
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: Colors.white))),
                    ],
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      child: Text(
                        _currentUser != null && _currentUser!['name'] != null && _currentUser!['name'].toString().isNotEmpty
                            ? _currentUser!['name'].toString()[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'login'});
                      await _checkAuth();
                    },
                    child: const Text('Login', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.transparent,
                    ),
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'register', 'showRoleTopRight': true});
                      await _checkAuth();
                    },
                    child: const Text('Register'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(kToolbarHeight), child: _topHeader()),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            Expanded(
              child: _perks.isEmpty && !_loading
                  ? Center(child: Text('No perks available', style: TextStyle(color: Colors.white70)))
                  : ListView.separated(
                itemCount: _perks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final p = _perks[i];
                  return Card(
                    color: Colors.white.withOpacity(0.03),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(p['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Text('${p['xp_required'] ?? 0} XP', style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(p['description'] ?? '', style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => _redeem(p['id'].toString()),
                                child: const Text('Redeem'),
                              ),
                              const SizedBox(width: 10),
                              Text('Available: ${p['xp_needed'] == 0 ? 'Yes' : 'No (needs ${p['xp_needed']})'}', style: const TextStyle(color: Colors.white70))
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
