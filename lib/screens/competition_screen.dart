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
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out')));
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

  Future<void> _fetchCompetitions({bool forceRefresh = false}) async {
    if (!_refreshing) {
      setState(() {
        _loading = !forceRefresh;
        _refreshing = forceRefresh;
        _error = null;
      });
    }

    try {
      final allRes = await ApiService.getCompetitions(filter: '', search: null);
      List<Map<String, dynamic>> allComps = [];
      if (allRes['success'] == true) {
        final data = allRes['data'] as Map<String, dynamic>?;
        allComps = (data != null && data['competitions'] != null)
            ? List<Map<String, dynamic>>.from(data['competitions'])
            : <Map<String, dynamic>>[];
      }

      int ongoing = 0, upcoming = 0, completed = 0;
      for (final c in allComps) {
        final s = _computeStatus(c);
        if (s == 'ongoing') ongoing++;
        else if (s == 'upcoming') upcoming++;
        else if (s == 'completed') completed++;
      }

      final filterParam = _filterToQueryParam(_activeFilter);
      final res = await ApiService.getCompetitions(
        filter: filterParam,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );

      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>?;
        final comps = (data != null && data['competitions'] != null)
            ? List<Map<String, dynamic>>.from(data['competitions'])
            : <Map<String, dynamic>>[];

        if (mounted) setState(() {
          _competitions = comps;
          ongoingCount = ongoing;
          upcomingCount = upcoming;
          completedCount = completed;
          _loading = false;
          _refreshing = false;
        });
      } else {
        if (mounted) setState(() {
          _error = res['message'] ?? 'Failed to load competitions';
          _loading = false;
          _refreshing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Network error: ${e.toString()}';
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ongoing':
        return Colors.greenAccent.shade700;
      case 'upcoming':
        return Colors.amberAccent.shade700;
      case 'completed':
      default:
        return Colors.grey.shade500;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ongoing':
        return 'Ongoing';
      case 'upcoming':
        return 'Upcoming';
      case 'completed':
      default:
        return 'Completed';
    }
  }

  Future<void> _onTapRegister(Map<String, dynamic> competition) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      final choice = await showDialog<_AuthChoice>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF07101A),
            title: const Text('Login required', style: TextStyle(color: Colors.white)),
            content: const Text('You must be logged in to register for competitions. Login or register now?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(_AuthChoice.cancel), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(ctx).pop(_AuthChoice.register), child: const Text('Register')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(_AuthChoice.login), child: const Text('Login')),
            ],
          );
        },
      );

      if (choice == _AuthChoice.login) {
        // wait for login flow to complete
        await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'login'});
        await _checkAuthStatus();
        final tokenAfter = await AuthService.getToken();
        if (tokenAfter != null && tokenAfter.isNotEmpty) {
          Navigator.pushNamed(context, '/competitions/register', arguments: {
            'competitionId': competition['id'],
            'competitionTitle': competition['title'],
          });
        }
      } else if (choice == _AuthChoice.register) {
        await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'register', 'showRoleTopRight': true});
        await _checkAuthStatus();
        final tokenAfter = await AuthService.getToken();
        if (tokenAfter != null && tokenAfter.isNotEmpty) {
          Navigator.pushNamed(context, '/competitions/register', arguments: {
            'competitionId': competition['id'],
            'competitionTitle': competition['title'],
          });
        }
      }
      return;
    }

    Navigator.pushNamed(
      context,
      '/competitions/register',
      arguments: {
        'competitionId': competition['id'],
        'competitionTitle': competition['title'],
      },
    );
  }

  Widget _topHeader() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
            child: ClipOval(
              child: Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.engineering, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 10),
          const Text('EPH', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
      actions: _isLoggedIn
          ? [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Row(
            children: [
              if (_currentUser != null) ...[
                Text(
                  (_currentUser!['name'] ?? 'User').toString(),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 8),
              ],
              PopupMenuButton<String>(
                color: const Color(0xFF07101A),
                onSelected: (val) async {
                  if (val == 'logout') await _handleLogout();
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'logout', child: Text('Logout')),
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
              const SizedBox(width: 8),
            ],
          ),
        ),
      ]
          : [
        TextButton(
          onPressed: () async {
            await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'login'});
            await _checkAuthStatus();
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
            await _checkAuthStatus();
          },
          child: const Text('Register'),
        ),
        const SizedBox(width: 12),
      ],
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
            color: Colors.greenAccent,
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
                child: Icon(Icons.close, color: Colors.white.withOpacity(0.6)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchCompetitions, child: const Text('Retry'))
          ]),
        ),
      );
    }

    if (_competitions.isEmpty) {
      return Expanded(
        child: Center(
          child: Text('No competitions found', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: () => _fetchCompetitions(forceRefresh: true),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _competitions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final c = _competitions[idx];
            final status = _computeStatus(c);
            final postedBy = (c['posted_by'] ?? c['postedBy']) as Map<String, dynamic>? ?? {};
            final start = c['start_date'] != null ? DateTime.tryParse(c['start_date'].toString()) : null;
            final end = c['end_date'] != null ? DateTime.tryParse(c['end_date'].toString()) : null;
            final df = DateFormat('d MMM');

            final seatsRemaining = c['seats_remaining'] ?? c['seatsRemaining'] ?? 0;
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
              seatsRemaining: seatsRemaining,
              postedByName: postedBy['name'] ?? postedBy['org'] ?? 'Unknown',
              sponsor: c['sponsor'],
              rules: c['rules'],
              eligibility: c['eligibility_criteria'],
              contact: c['contact_info'],
              onRegister: () => _onTapRegister(c),
              statusColor: _statusColor(status),
              statusLabel: _statusLabel(status),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Make scaffold transparent so our gradient body is visible (prevents white blanks)
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(kToolbarHeight), child: _topHeader()),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _filtersRow(),
            _searchBar(),
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            _buildList(),
          ],
        ),
      ),
    );
  }
}

enum _AuthChoice { cancel, login, register }

class _MetricButton extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _MetricButton({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
    this.selected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.white.withOpacity(0.08) : Colors.transparent),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 14, backgroundColor: color.withOpacity(0.12), child: Icon(Icons.timeline, color: color, size: 18)),
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
  final dynamic rules;
  final dynamic eligibility;
  final dynamic contact;
  final VoidCallback? onRegister;
  final Color statusColor;
  final String statusLabel;

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
    this.rules,
    this.eligibility,
    this.contact,
    this.onRegister,
    required this.statusColor,
    required this.statusLabel,
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
                  ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(widget.bannerUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.emoji_objects_outlined, color: Colors.white70)))
                  : const Icon(Icons.emoji_objects_outlined, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: widget.statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(widget.statusLabel, style: TextStyle(color: widget.statusColor, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(widget.subtitle, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (widget.start != null && widget.end != null)
                    Chip(label: Text('${df.format(widget.start!)} → ${df.format(widget.end!)}'), backgroundColor: Colors.white.withOpacity(0.02), labelStyle: const TextStyle(color: Colors.white70)),
                  Chip(label: Text('${widget.membersCount} participants'), backgroundColor: Colors.white.withOpacity(0.02), labelStyle: const TextStyle(color: Colors.white70)),
                  Chip(label: Text('${widget.seatsRemaining} seats left'), backgroundColor: Colors.white.withOpacity(0.02), labelStyle: const TextStyle(color: Colors.white70)),
                  ...widget.tags.take(3).map((t) => Chip(label: Text(t), backgroundColor: Colors.white.withOpacity(0.02), labelStyle: const TextStyle(color: Colors.white70))).toList(),
                ])
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
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        CircleAvatar(radius: 14, backgroundColor: Colors.white.withOpacity(0.06), child: Text(widget.postedByName.isNotEmpty ? widget.postedByName[0].toUpperCase() : 'U')),
                        const SizedBox(width: 8),
                        Text('Posted by ${widget.postedByName}', style: const TextStyle(color: Colors.white70)),
                      ]),
                      Row(children: [
                        TextButton(onPressed: widget.onRegister, child: const Text('Register', style: TextStyle(color: Colors.white70))),
                        const SizedBox(width: 6),
                        Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white70),
                      ])
                    ]),
                  ),
                ),
                if (_expanded) ...[
                  const Divider(color: Colors.white10, height: 0),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if ((widget.sponsor ?? '').toString().isNotEmpty) Text('Sponsor: ${widget.sponsor}', style: const TextStyle(color: Colors.white70)),
                      if (widget.rules != null) ...[
                        const SizedBox(height: 8),
                        const Text('Rules:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(widget.rules.toString(), style: const TextStyle(color: Colors.white70)),
                      ],
                      if (widget.eligibility != null) ...[
                        const SizedBox(height: 8),
                        const Text('Eligibility:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(widget.eligibility.toString(), style: const TextStyle(color: Colors.white70)),
                      ],
                      if (widget.contact != null) ...[
                        const SizedBox(height: 8),
                        Text('Contact: ${_contactToString(widget.contact)}', style: const TextStyle(color: Colors.white70)),
                      ]
                    ]),
                  )
                ]
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
