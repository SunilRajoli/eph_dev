// lib/screens/competition_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

enum CompetitionFilter { all, ongoing, upcoming, completed }

class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen> with WidgetsBindingObserver {
  CompetitionFilter _activeFilter = CompetitionFilter.all;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<Map<String, dynamic>> _competitions = [];
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  // counts (computed from full dataset)
  int ongoingCount = 0;
  int upcomingCount = 0;
  int completedCount = 0;

  // Auth state
  bool _isLoggedIn = false;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // keep fetch and auth checks separate but ensure auth is checked after first frame
    _fetchCompetitions();
    // ensure auth check runs after first frame so secure storage is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStatus();
    });

    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // also re-check auth whenever dependencies change (useful after navigation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Called when app is resumed (useful for deep-link / magic link flows)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAuthStatus();
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _fetchCompetitions();
    });
    // ensure UI updates for the clear icon
    setState(() {});
  }

  Future<void> _checkAuthStatus() async {
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
      if (mounted) setState(() {
        _isLoggedIn = false;
        _currentUser = null;
      });
    } catch (_) {
      if (mounted) setState(() {
        _isLoggedIn = false;
        _currentUser = null;
      });
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.clearToken();
    await _checkAuthStatus();
    await _fetchCompetitions();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.logout, color: Colors.white),
            SizedBox(width: 8),
            Text('Logged out successfully'),
          ],
        ),
        backgroundColor: Colors.green.shade800,
      ),
    );
  }

  String _filterToQueryParam(CompetitionFilter f) {
    switch (f) {
      case CompetitionFilter.ongoing:
        return 'ongoing';
      case CompetitionFilter.upcoming:
        return 'upcoming';
      case CompetitionFilter.completed:
        return 'past';
      case CompetitionFilter.all:
      default:
        return '';
    }
  }

  String _computeStatus(Map<String, dynamic> c) {
    final status = (c['status'] as String?)?.toLowerCase() ?? '';
    final start = c['start_date'] != null ? DateTime.tryParse(c['start_date'].toString()) : null;
    final end = c['end_date'] != null ? DateTime.tryParse(c['end_date'].toString()) : null;
    final now = DateTime.now();

    if (status == 'ongoing') return 'ongoing';
    if (status == 'completed') return 'completed';
    if (status == 'published' || status == 'upcoming' || status.isEmpty) {
      if (start != null && start.isAfter(now)) return 'upcoming';
      if (start != null && end != null && start.isBefore(now) && end.isAfter(now)) return 'ongoing';
      if (end != null && end.isBefore(now)) return 'completed';
      return 'upcoming';
    }
    return status;
  }

  // ---------------------------
  // Updated _fetchCompetitions
  // ---------------------------
  Future<void> _fetchCompetitions({bool forceRefresh = false}) async {
    if (!_refreshing) {
      setState(() {
        _loading = !forceRefresh;
        _refreshing = forceRefresh;
        _error = null;
      });
    }

    try {
      // 1) Fetch full list (used for counting & reliable client-side filtering)
      final allRes = await ApiService.getCompetitions(filter: '', search: null);
      List<Map<String, dynamic>> allComps = [];
      if (allRes['success'] == true) {
        final data = allRes['data'] as Map<String, dynamic>?;
        allComps = (data != null && data['competitions'] != null)
            ? List<Map<String, dynamic>>.from(data['competitions'])
            : <Map<String, dynamic>>[];
      } else {
        // If main fetch failed, set error and return early
        if (mounted) setState(() {
          _error = allRes['message'] ?? 'Failed to load competitions';
          _loading = false;
          _refreshing = false;
        });
        return;
      }

      // compute counts from the full dataset using the same client-side status logic
      int ongoing = 0, upcoming = 0, completed = 0;
      for (final c in allComps) {
        final s = _computeStatus(c);
        if (s == 'ongoing') ongoing++;
        else if (s == 'upcoming') upcoming++;
        else if (s == 'completed') completed++;
      }

      // 2) Apply client-side search + filter to ensure UI matches _computeStatus
      final searchText = _searchCtrl.text.trim();
      List<Map<String, dynamic>> filtered = allComps;

      // apply search (title, subtitle, sponsor, tags)
      if (searchText.isNotEmpty) {
        final q = searchText.toLowerCase();
        filtered = filtered.where((c) {
          final title = (c['title'] ?? '').toString().toLowerCase();
          final subtitle = (c['subtitle'] ?? c['description'] ?? '').toString().toLowerCase();
          final sponsor = (c['sponsor'] ?? '').toString().toLowerCase();
          final tags = (c['tags'] as List<dynamic>?)?.map((t) => t.toString().toLowerCase()).toList() ?? <String>[];
          return title.contains(q) || subtitle.contains(q) || sponsor.contains(q) || tags.any((t) => t.contains(q));
        }).toList();
      }

      // apply active filter using _computeStatus
      filtered = filtered.where((c) {
        final s = _computeStatus(c);
        switch (_activeFilter) {
          case CompetitionFilter.ongoing:
            return s == 'ongoing';
          case CompetitionFilter.upcoming:
            return s == 'upcoming';
          case CompetitionFilter.completed:
            return s == 'completed';
          case CompetitionFilter.all:
          default:
            return true;
        }
      }).toList();

      // 3) Optionally call server-filtered endpoint for freshness/pagination,
      //    but prefer client-side if the server response looks inconsistent.
      final filterParam = _filterToQueryParam(_activeFilter);
      final serverRes = await ApiService.getCompetitions(
        filter: filterParam,
        search: searchText.isEmpty ? null : searchText,
      );

      List<Map<String, dynamic>> serverComps = [];
      if (serverRes['success'] == true) {
        final data = serverRes['data'] as Map<String, dynamic>?;
        serverComps = (data != null && data['competitions'] != null)
            ? List<Map<String, dynamic>>.from(data['competitions'])
            : <Map<String, dynamic>>[];
      }

      // prefer server result only if it looks consistent with our filter
      final useServer = serverComps.isNotEmpty &&
          serverComps.every((c) {
            final s = _computeStatus(c);
            switch (_activeFilter) {
              case CompetitionFilter.ongoing:
                return s == 'ongoing';
              case CompetitionFilter.upcoming:
                return s == 'upcoming';
              case CompetitionFilter.completed:
                return s == 'completed';
              case CompetitionFilter.all:
              default:
                return true;
            }
          });

      final compsToShow = useServer ? serverComps : filtered;

      if (mounted) setState(() {
        // ensure each competition has user flags (defaults false) so UI is predictable
        _competitions = compsToShow.map((c) {
          final copy = Map<String, dynamic>.from(c);
          copy['user_registered'] = copy['user_registered'] == true;
          copy['user_submitted'] = copy['user_submitted'] == true;
          return copy;
        }).toList();
        ongoingCount = ongoing;
        upcomingCount = upcoming;
        completedCount = completed;
        _loading = false;
        _refreshing = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Network error: ${e.toString()}';
        _loading = false;
        _refreshing = false;
      });
    }
  }

  // ---------------------------
  // Helpers to update local flags when returning from register/submit screens
  // ---------------------------
  void _setRegistered(String competitionId, {bool value = true}) {
    final idx = _competitions.indexWhere((c) => c['id'] == competitionId);
    if (idx == -1) return;
    final updated = Map<String, dynamic>.from(_competitions[idx]);
    updated['user_registered'] = value;
    setState(() => _competitions[idx] = updated);
  }

  void _setSubmitted(String competitionId, {bool value = true}) {
    final idx = _competitions.indexWhere((c) => c['id'] == competitionId);
    if (idx == -1) return;
    final updated = Map<String, dynamic>.from(_competitions[idx]);
    updated['user_submitted'] = value;
    setState(() => _competitions[idx] = updated);
  }

  // ---------------------------
  // Robust register/submit handlers
  // ---------------------------
  Future<void> _onTapRegister(Map<String, dynamic> competition) async {
    // ensure user is logged in, else run login/register flows then continue
    String? token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      final choice = await showDialog<_AuthChoice>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF07101A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: const [
                Icon(Icons.login, color: Colors.white70, size: 24),
                SizedBox(width: 8),
                Text('Login Required', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text(
              'You must be logged in to register for competitions. Would you like to login or create a new account?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_AuthChoice.cancel),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              // Register button (subtle/translucent)
              TextButton.icon(
                onPressed: () => Navigator.of(ctx).pop(_AuthChoice.register),
                icon: const Icon(Icons.person_add, size: 18, color: Colors.white70),
                label: const Text('Register', style: TextStyle(color: Colors.white70)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.02),
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              // Login button (primary-ish but translucent to match UI)
              TextButton.icon(
                onPressed: () => Navigator.of(ctx).pop(_AuthChoice.login),
                icon: const Icon(Icons.login, size: 18, color: Colors.white),
                label: const Text('Login', style: TextStyle(color: Colors.white)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.06),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
      );

      if (choice == null || choice == _AuthChoice.cancel) return;

      // navigate to roles/login/register depending on choice
      if (choice == _AuthChoice.login) {
        await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'login'});
      } else {
        await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'register', 'showRoleTopRight': true});
      }

      // re-check token
      await _checkAuthStatus();
      token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;
    }

    // Now user is logged in – open registration screen and await result
    final result = await Navigator.pushNamed(context, '/competitions/register', arguments: {
      'competitionId': competition['id'],
      'competitionTitle': competition['title'],
    });

    // result must be a Map: {'registered': true} on success
    if (result is Map && result['registered'] == true) {
      // optimistic local update
      _setRegistered(competition['id']);

      // Optional: trigger background sync to reconcile with backend (recommended)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _fetchCompetitions(forceRefresh: true);
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Successfully registered for competition!'),
            ],
          ),
          backgroundColor: Colors.green.shade800,
        ),
      );
    }
  }

  Future<void> _onTapSubmit(Map<String, dynamic> competition) async {
    // ensure user logged in
    String? token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      final choice = await showDialog<_AuthChoice>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF07101A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: const [
                Icon(Icons.login, color: Colors.white70, size: 24),
                SizedBox(width: 8),
                Text('Login Required', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text(
              'You must be logged in to submit your project. Would you like to login or create a new account?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_AuthChoice.cancel),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(ctx).pop(_AuthChoice.register),
                icon: const Icon(Icons.person_add, size: 18, color: Colors.white70),
                label: const Text('Register', style: TextStyle(color: Colors.white70)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.02),
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(ctx).pop(_AuthChoice.login),
                icon: const Icon(Icons.login, size: 18, color: Colors.white),
                label: const Text('Login', style: TextStyle(color: Colors.white)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.06),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
      );

      if (choice == null || choice == _AuthChoice.cancel) return;

      if (choice == _AuthChoice.login) {
        await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'login'});
      } else {
        await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'register'});
      }

      await _checkAuthStatus();
      token = await AuthService.getToken();
      if (token == null || token.isEmpty) return;
    }

    // Open submission screen and await result
    final result = await Navigator.pushNamed(context, '/competitions/submit', arguments: {
      'competitionId': competition['id'],
      'competitionTitle': competition['title'],
    });

    if (result is Map && result['submitted'] == true) {
      // optimistic local update
      _setSubmitted(competition['id']);

      // Also trigger background sync to reconcile with backend (recommended)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _fetchCompetitions(forceRefresh: true);
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.cloud_upload, color: Colors.white),
              SizedBox(width: 8),
              Text('Project submitted successfully!'),
            ],
          ),
          backgroundColor: Colors.green.shade800,
        ),
      );
    }
  }

  // ---------------------------
  // rest of the original code (UI rendering)
  // ---------------------------

  Color _statusColor(String status) {
    switch (status) {
      case 'ongoing':
        return Colors.green.shade600;
      case 'upcoming':
        return Colors.amber.shade600;
      case 'completed':
      default:
        return Colors.grey.shade500;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ongoing':
        return 'Live';
      case 'upcoming':
        return 'Soon';
      case 'completed':
      default:
        return 'Done';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'ongoing':
        return Icons.play_circle_fill;
      case 'upcoming':
        return Icons.schedule;
      case 'completed':
      default:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Let the gradient show behind the AppBar
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(kToolbarHeight), child: _topHeader()),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              _filtersRow(),
              _searchBar(),
              if (_loading) const LinearProgressIndicator(minHeight: 3),
              // expanded inner list (transparent)
              Expanded(child: _buildListInner()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topHeader() {
    // Keep the same app gradient behind the header; AppBar itself is transparent
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent, // <-- make AppBar transparent
      automaticallyImplyLeading: false,
      toolbarHeight: kToolbarHeight + 8,
      titleSpacing: 12,
      title: Container(
        // The small rounded, semi-transparent card (same treatment as LoginScreen)
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            // circular logo with gradient background (same as login)
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(gradient: AppTheme.gradient, shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('EPH', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 4),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: const [
                    Icon(Icons.emoji_events, size: 16, color: Colors.white70),
                    SizedBox(width: 4),
                    Text(
                      'Competitions',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            // Actions (Login/Register or user avatar)
            if (_isLoggedIn)
              Row(
                children: [
                  if (_currentUser != null) ...[
                    Text(
                      (_currentUser!['name'] ?? 'User').toString(),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                  ],
                  PopupMenuButton<String>(
                    // Use same translucent card-like background as the top header
                    color: Colors.white.withOpacity(0.04),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.white.withOpacity(0.04))),
                    offset: const Offset(0, 44),
                    onSelected: (val) async {
                      if (val == 'logout') {
                        await _handleLogout();
                      } else if (val == 'profile') {
                        Navigator.pushNamed(context, '/profile');
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: const [
                            Icon(Icons.person, size: 18, color: Colors.white70),
                            SizedBox(width: 8),
                            Text('Profile', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: const [
                            Icon(Icons.logout, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Logout', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
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
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'login'});
                      await _checkAuthStatus();
                    },
                    icon: const Icon(Icons.login, size: 16, color: Colors.white),
                    label: const Text('Login', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.transparent,
                    ),
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'register', 'showRoleTopRight': true});
                      await _checkAuthStatus();
                    },
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Register'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _filtersRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _MetricButton(
            label: 'Ongoing',
            count: ongoingCount,
            icon: Icons.play_circle_fill,
            color: Colors.green,
            selected: _activeFilter == CompetitionFilter.ongoing,
            onTap: () {
              setState(() => _activeFilter = CompetitionFilter.ongoing);
              _fetchCompetitions();
            },
          ),
          const SizedBox(width: 8),
          _MetricButton(
            label: 'Upcoming',
            count: upcomingCount,
            icon: Icons.schedule,
            color: Colors.amber,
            selected: _activeFilter == CompetitionFilter.upcoming,
            onTap: () {
              setState(() => _activeFilter = CompetitionFilter.upcoming);
              _fetchCompetitions();
            },
          ),
          const SizedBox(width: 8),
          _MetricButton(
            label: 'Completed',
            count: completedCount,
            icon: Icons.check_circle,
            color: Colors.grey,
            selected: _activeFilter == CompetitionFilter.completed,
            onTap: () {
              setState(() => _activeFilter = CompetitionFilter.completed);
              _fetchCompetitions();
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search competitions, sponsor, tags...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  _fetchCompetitions();
                  setState(() {});
                },
                child: Icon(Icons.clear, color: Colors.white.withOpacity(0.6)),
              )
          ],
        ),
      ),
    );
  }

  // extracted inner list to avoid Expanded duplication and allow transparent RefreshIndicator
  Widget _buildListInner() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _fetchCompetitions,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.black,
            ),
          ),
        ]),
      );
    }

    if (_competitions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No competitions found',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filter criteria',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      // prevent RefreshIndicator from painting a white rectangle behind the list
      backgroundColor: Colors.transparent,
      color: Colors.white70,
      onRefresh: () => _fetchCompetitions(forceRefresh: true),
      child: Container(
        color: Colors.transparent,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _competitions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final c = _competitions[idx];
            final status = _computeStatus(c);

            // 'postedBy' mapping: check many possible shapes returned by API
            final rawPostedBy = c['posted_by'] ??
                c['postedBy'] ??
                c['createdBy'] ??
                c['created_by'] ??
                c['createdByUser'] ??
                c['createdByUserData'] ??
                c['createdByData'];

            Map<String, dynamic>? postedBy;
            if (rawPostedBy is Map<String, dynamic>) {
              postedBy = rawPostedBy;
            } else if (rawPostedBy is String) {
              postedBy = {'name': rawPostedBy};
            } else if (rawPostedBy != null) {
              // sometimes API returns nested object as dynamic Map (not typed)
              try {
                postedBy = Map<String, dynamic>.from(rawPostedBy);
              } catch (_) {
                postedBy = null;
              }
            } else {
              postedBy = null;
            }

            final start = c['start_date'] != null ? DateTime.tryParse(c['start_date'].toString()) : null;
            final end = c['end_date'] != null ? DateTime.tryParse(c['end_date'].toString()) : null;
            final df = DateFormat('d MMM');

            // new fields extracted safely
            final contentSourceType = c['content_source_type'] ?? c['contentSourceType'] ?? c['source'] ?? '';
            final sponsor = c['sponsor'] ?? '';
            final registrationDeadlineRaw = c['registration_deadline'] ?? c['registrationDeadline'] ?? c['reg_deadline'];
            DateTime? registrationDeadline;
            if (registrationDeadlineRaw != null) registrationDeadline = DateTime.tryParse(registrationDeadlineRaw.toString());
            final maxTeamSize = c['max_team_size'] ?? c['maxTeamSize'] ?? c['team_size'] ?? null;
            final totalSeats = c['total_seats'] ?? c['totalSeats'] ?? c['seats_total'] ?? null;
            final seatsRemaining = c['seats_remaining'] ?? c['seatsRemaining'] ?? c['remaining_seats'] ?? 0;

            final seatsRemainingInt = (seatsRemaining is int) ? seatsRemaining : int.tryParse(seatsRemaining.toString()) ?? 0;
            final membersCount = c['stats'] != null ? (c['stats']['totalRegistrations'] ?? c['membersCount'] ?? 0) : (c['membersCount'] ?? 0);
            final tags = (c['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? [];

            return _CompetitionCard(
              title: c['title'] ?? '',
              subtitle: c['subtitle'] ?? c['description'] ?? '',
              bannerUrl: c['banner_image_url'],
              status: status,
              start: start,
              end: end,
              tags: tags,
              membersCount: membersCount,
              seatsRemaining: seatsRemainingInt,
              postedByName: postedBy != null ? (postedBy['name'] ?? postedBy['org'] ?? postedBy['username'] ?? '') : '',
              sponsor: sponsor?.toString(),
              contentSourceType: contentSourceType?.toString(),
              registrationDeadline: registrationDeadline,
              maxTeamSize: maxTeamSize != null ? int.tryParse(maxTeamSize.toString()) : null,
              totalSeats: totalSeats != null ? int.tryParse(totalSeats.toString()) : null,
              rules: c['rules'],
              eligibility: c['eligibility_criteria'],
              contact: c['contact_info'],
              onRegister: () => _onTapRegister(c),
              onSubmit: () => _onTapSubmit(c),
              userRegistered: c['user_registered'] == true,
              userSubmitted: c['user_submitted'] == true,
              statusColor: _statusColor(status),
              statusLabel: _statusLabel(status),
              statusIcon: _statusIcon(status),
            );
          },
        ),
      ),
    );
  }
}

enum _AuthChoice { cancel, login, register }

class _MetricButton extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _MetricButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
    this.selected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // subtle gradient using the base color with low opacity to avoid bright visuals
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withOpacity(selected ? 0.14 : 0.08),
        color.withOpacity(selected ? 0.06 : 0.03),
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.white.withOpacity(0.06) : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                // Subtle circular gradient for the icon container too
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.12), color.withOpacity(0.06)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color.withOpacity(0.85), size: 16),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(count.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])
          ],
        ),
      ),
    );
  }
}

class _CompetitionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? bannerUrl;
  final String status;
  final DateTime? start;
  final DateTime? end;
  final List<String> tags;
  final int membersCount;
  final int seatsRemaining;
  final String postedByName;
  final String? sponsor;
  final String? contentSourceType;
  final DateTime? registrationDeadline;
  final int? maxTeamSize;
  final int? totalSeats;
  final dynamic rules;
  final dynamic eligibility;
  final dynamic contact;
  final VoidCallback? onRegister;
  final VoidCallback? onSubmit;
  final bool userRegistered;
  final bool userSubmitted;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;

  const _CompetitionCard({
    required this.title,
    required this.subtitle,
    this.bannerUrl,
    required this.status,
    this.start,
    this.end,
    required this.tags,
    required this.membersCount,
    required this.seatsRemaining,
    required this.postedByName,
    this.sponsor,
    this.contentSourceType,
    this.registrationDeadline,
    this.maxTeamSize,
    this.totalSeats,
    this.rules,
    this.eligibility,
    this.contact,
    this.onRegister,
    this.onSubmit,
    this.userRegistered = false,
    this.userSubmitted = false,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    super.key,
  });

  @override
  State<_CompetitionCard> createState() => _CompetitionCardState();
}

class _CompetitionCardState extends State<_CompetitionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM');
    final corner = BorderRadius.circular(14);
    final ddFmt = DateFormat('d MMM yyyy, hh:mm a');

    Widget _pill(String text, {IconData? icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.01)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
            ],
            Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );
    }

    return Card(
      color: Colors.white.withOpacity(0.03),
      shape: RoundedRectangleBorder(borderRadius: corner),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
              child: widget.bannerUrl != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  widget.bannerUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events, color: Colors.white70, size: 32),
                ),
              )
                  : const Icon(Icons.emoji_events, color: Colors.white70, size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: widget.statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.statusIcon, size: 12, color: widget.statusColor),
                        const SizedBox(width: 4),
                        Text(widget.statusLabel, style: TextStyle(color: widget.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(widget.subtitle, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                // Row of small pills: date, participants, seats etc
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (widget.start != null && widget.end != null) _pill('${df.format(widget.start!)} → ${df.format(widget.end!)}', icon: Icons.calendar_month),
                  _pill('${widget.membersCount} participants', icon: Icons.group),
                  _pill('${widget.seatsRemaining} seats left', icon: Icons.event_seat),
                  if (widget.totalSeats != null) _pill('Total: ${widget.totalSeats}', icon: Icons.event_available),
                  if (widget.maxTeamSize != null) _pill('Team: ${widget.maxTeamSize}', icon: Icons.people),
                  if (widget.contentSourceType != null && widget.contentSourceType!.isNotEmpty) _pill(widget.contentSourceType!, icon: Icons.source),
                ]),
                const SizedBox(height: 8),
                // Tags as small dark pills
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: widget.tags.map((t) {
                    // remove leading '#' and trim whitespace, preserve inner punctuation/casing
                    var txt = t.toString().trim();
                    if (txt.startsWith('#')) txt = txt.substring(1).trim();
                    if (txt.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag, size: 12, color: Colors.blue.shade300),
                          const SizedBox(width: 4),
                          Text(txt, style: TextStyle(color: Colors.blue.shade300, fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ]),
            )
          ]),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.01)),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white.withOpacity(0.06),
                              child: Icon(Icons.person, size: 16, color: Colors.white70),
                            ),
                            const SizedBox(width: 8),
                            Text('Posted by ${widget.postedByName.isNotEmpty ? widget.postedByName : 'Unknown'}', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                        Row(
                          children: [
                            // --- Enhanced Conditional action based on status and user flags ---
                            if (widget.status == 'upcoming') ...[
                              widget.userRegistered
                                  ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text('Registered', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                                  : TextButton.icon(
                                onPressed: widget.onRegister,
                                icon: const Icon(Icons.how_to_reg, size: 16, color: Colors.white70),
                                label: const Text('Register', style: TextStyle(color: Colors.white70)),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.02),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ] else if (widget.status == 'ongoing') ...[
                              widget.userSubmitted
                                  ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.cloud_done, size: 16, color: Colors.blue),
                                    SizedBox(width: 4),
                                    Text('Submitted', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                                  : TextButton.icon(
                                onPressed: widget.onSubmit,
                                icon: const Icon(Icons.upload_file, size: 16, color: Colors.white70),
                                label: const Text('Submit', style: TextStyle(color: Colors.white70)),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.02),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ] else if (widget.status == 'completed') ...[
                              if (widget.userRegistered && widget.userSubmitted) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                                      SizedBox(width: 4),
                                      Text('Submitted', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(widget.statusIcon, size: 14, color: widget.statusColor),
                                      const SizedBox(width: 4),
                                      Text('Completed', style: TextStyle(color: widget.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ] else if (widget.userRegistered && !widget.userSubmitted) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.warning, size: 16, color: Colors.orange),
                                      SizedBox(width: 4),
                                      Text('Not Submitted', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(widget.statusIcon, size: 14, color: widget.statusColor),
                                      const SizedBox(width: 4),
                                      Text('Completed', style: TextStyle(color: widget.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(widget.statusIcon, size: 14, color: widget.statusColor),
                                      const SizedBox(width: 4),
                                      Text('Completed', style: TextStyle(color: widget.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ]
                            ],
                            const SizedBox(width: 6),
                            Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white70),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded) ...[
                  const Divider(color: Colors.white10, height: 0),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Sponsor
                      if ((widget.sponsor ?? '').toString().isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.business, size: 16, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text('Sponsor: ${widget.sponsor}', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Registration deadline
                      if (widget.registrationDeadline != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 16, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text('Registration deadline: ${ddFmt.format(widget.registrationDeadline!)}', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Max team size / total seats
                      if (widget.maxTeamSize != null || widget.totalSeats != null) ...[
                        Row(children: [
                          if (widget.maxTeamSize != null) ...[
                            const Icon(Icons.people, size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text('Max team size: ${widget.maxTeamSize}', style: const TextStyle(color: Colors.white70)),
                          ],
                          if (widget.maxTeamSize != null && widget.totalSeats != null) const SizedBox(width: 16),
                          if (widget.totalSeats != null) ...[
                            const Icon(Icons.event_seat, size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text('Total seats: ${widget.totalSeats}', style: const TextStyle(color: Colors.white70)),
                          ],
                        ]),
                        const SizedBox(height: 8),
                      ],
                      // Rules
                      if (widget.rules != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.rule, size: 16, color: Colors.white70),
                            const SizedBox(width: 8),
                            const Text('Rules:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: Text(widget.rules.toString(), style: const TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Eligibility
                      if (widget.eligibility != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.verified_user, size: 16, color: Colors.white70),
                            const SizedBox(width: 8),
                            const Text('Eligibility:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: Text(widget.eligibility.toString(), style: const TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Contact
                      if (widget.contact != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.contact_mail, size: 16, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text('Contact: ${_contactToString(widget.contact)}', style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ]
                    ]),
                  )
                ],
              ],
            ),
          )
        ]),
      ),
    );
  }

  String _contactToString(dynamic contact) {
    if (contact == null) return '';
    if (contact is Map) {
      if (contact['email'] != null) return contact['email'].toString();
      if (contact['phone'] != null) return contact['phone'].toString();
      return contact.toString();
    }
    return contact.toString();
  }
}
