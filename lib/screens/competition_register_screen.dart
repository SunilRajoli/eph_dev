// lib/screens/competition_register_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';

enum _RegType { individual, team }

class CompetitionRegisterScreen extends StatefulWidget {
  const CompetitionRegisterScreen({super.key});

  @override
  State<CompetitionRegisterScreen> createState() => _CompetitionRegisterScreenState();
}

class _CompetitionRegisterScreenState extends State<CompetitionRegisterScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _competition; // full details from API
  String competitionId = '';
  final _formKey = GlobalKey<FormState>();

  // form fields
  _RegType _type = _RegType.individual;
  final teamNameCtrl = TextEditingController();
  final abstractCtrl = TextEditingController();
  final memberEmailCtrl = TextEditingController();
  final List<String> _memberEmails = [];

  // seat & team limits
  int _maxTeamSize = 1;
  int _seatsRemaining = 0;

  @override
  void initState() {
    super.initState();
    // real init happens in didChangeDependencies so we can read args
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final id = args['competitionId']?.toString();
      if (id != null && id.isNotEmpty) {
        competitionId = id;
        _loadCompetition();
        return;
      }
    }
    // If args are missing or invalid, show an error
    setState(() {
      _loading = false;
      _error = 'Missing or invalid competition ID';
    });
  }

  @override
  void dispose() {
    teamNameCtrl.dispose();
    abstractCtrl.dispose();
    memberEmailCtrl.dispose();
    super.dispose();
  }

  // Helper to safely parse ints from dynamic values
  int _toInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is String) {
      return int.tryParse(v) ?? fallback;
    }
    if (v is double) return v.toInt();
    try {
      return (v as num).toInt();
    } catch (_) {
      return fallback;
    }
  }

  // Robustly load competition details from possible response shapes
  Future<void> _loadCompetition() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.getCompetitionDetails(competitionId);

      // If ApiService returns map-like structure check multiple locations
      Map<String, dynamic>? comp;
      if (res == null) {
        setState(() {
          _error = 'Empty response from server';
          _loading = false;
        });
        return;
      }

      if (res is Map<String, dynamic>) {
        // success boolean first
        final bool ok = res['success'] == true;

        if (!ok) {
          // try to extract server message
          final msg = res['message'] ?? res['error'] ?? 'Failed to load competition';
          setState(() {
            _error = msg.toString();
            _loading = false;
          });
          return;
        }

        // Many API shapes: res['data']['competition'], res['competition'], res['data']
        if (res['competition'] != null && res['competition'] is Map) {
          comp = Map<String, dynamic>.from(res['competition']);
        } else if (res['data'] != null) {
          final data = res['data'];
          if (data is Map<String, dynamic>) {
            if (data['competition'] != null && data['competition'] is Map) {
              comp = Map<String, dynamic>.from(data['competition']);
            } else if (data['competitions'] != null && data['competitions'] is List && data['competitions'].isNotEmpty) {
              // sometimes single competition returned under competitions list
              final first = data['competitions'][0];
              if (first is Map<String, dynamic>) comp = Map<String, dynamic>.from(first);
            } else {
              // if data already is the competition map
              comp = Map<String, dynamic>.from(data);
            }
          }
        } else {
          // maybe the entire response is the competition object
          try {
            comp = Map<String, dynamic>.from(res);
            // avoid treating whole envelope as comp if it only contains 'success'
            if (comp.keys.length <= 2 && comp.containsKey('success')) comp = null;
          } catch (_) {
            comp = null;
          }
        }
      }

      if (comp == null) {
        setState(() {
          _error = 'Competition not found in server response';
          _loading = false;
        });
        return;
      }

      // set values safely
      final maxTeam = comp['max_team_size'] ?? comp['maxTeamSize'] ?? comp['team_size'];
      final seatsRemaining = comp['seats_remaining'] ?? comp['seatsRemaining'] ?? comp['remaining_seats'] ?? comp['seats'];

      setState(() {
        _competition = comp;
        _maxTeamSize = _toInt(maxTeam, fallback: 1);
        if (_maxTeamSize < 1) _maxTeamSize = 1;
        _seatsRemaining = _toInt(seatsRemaining, fallback: 0);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Network error: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<bool> _ensureLoggedIn() async {
    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty) return true;

    // Ask user to login/register
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
              'You must be logged in to register. Would you like to login or create a new account?',
              style: TextStyle(color: Colors.white70)
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_AuthChoice.cancel),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_AuthChoice.register),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.person_add, size: 18, color: Colors.white70),
                  SizedBox(width: 4),
                  Text('Register', style: TextStyle(color: Colors.white70)),
                ],
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.02),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_AuthChoice.login),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.login, size: 18, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Login', style: TextStyle(color: Colors.white)),
                ],
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.06),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        );
      },
    );

    if (choice == _AuthChoice.login) {
      await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'login'});
      final tokenAfter = await AuthService.getToken();
      return tokenAfter != null && tokenAfter.isNotEmpty;
    } else if (choice == _AuthChoice.register) {
      await Navigator.pushNamed(context, '/roles', arguments: {'mode': 'register', 'showRoleTopRight': true});
      final tokenAfter = await AuthService.getToken();
      return tokenAfter != null && tokenAfter.isNotEmpty;
    }

    return false;
  }

  String? _validateEmailField(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email required';
    final re = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
    if (!re.hasMatch(v.trim())) return 'Enter valid email';
    return null;
  }

  void _addMemberEmail() {
    final email = memberEmailCtrl.text.trim();
    final err = _validateEmailField(email);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text(err),
            ],
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }
    // check duplicates
    if (_memberEmails.contains(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Email already added'),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }
    // check against max team size (leader + members)
    final newSize = 1 + _memberEmails.length + 1; // leader + existing + new
    if (newSize > _maxTeamSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.people, color: Colors.white),
              const SizedBox(width: 8),
              Text('Max team size is $_maxTeamSize'),
            ],
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    setState(() {
      _memberEmails.add(email);
      memberEmailCtrl.clear();
    });
  }

  void _removeMemberEmail(int idx) {
    setState(() {
      _memberEmails.removeAt(idx);
    });
  }

  Future<void> _submitRegistration() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    // ensure logged in
    final loggedIn = await _ensureLoggedIn();
    if (!loggedIn) return;

    // extra validations
    if (_type == _RegType.team && (teamNameCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.group, color: Colors.white),
              SizedBox(width: 8),
              Text('Team name is required for team registration'),
            ],
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    // check seats
    if (_seatsRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.event_seat, color: Colors.white),
              SizedBox(width: 8),
              Text('No seats remaining for this competition'),
            ],
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final payload = <String, dynamic>{
        'type': _type == _RegType.individual ? 'individual' : 'team',
        if (_type == _RegType.team) 'team_name': teamNameCtrl.text.trim(),
        if (_memberEmails.isNotEmpty) 'member_emails': _memberEmails,
        if (abstractCtrl.text.trim().isNotEmpty) 'abstract': abstractCtrl.text.trim(),
      };

      final res = await ApiService.registerForCompetition(competitionId, payload);

      if (res is Map<String, dynamic> && res['success'] == true) {
        // Optimistically reduce seats locally (UI only). Parent screen will refresh from server.
        setState(() {
          if (_seatsRemaining > 0) _seatsRemaining = _seatsRemaining - 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Registration submitted successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );

        // Pop with success so parent screen can mark 'registered' flag
        if (mounted) Navigator.pop(context, {'registered': true});
        return;
      }

      // If failed, try to extract message
      String msg = 'Registration failed';
      if (res is Map<String, dynamic>) {
        msg = res['message']?.toString() ?? res['error']?.toString() ?? msg;
      }
      setState(() {
        _error = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text(msg),
            ],
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } catch (e) {
      final msg = 'Network error: ${e.toString()}';
      setState(() {
        _error = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white),
              const SizedBox(width: 8),
              Text(msg),
            ],
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _topHeaderContent() {
    final title = _competition != null ? _competition!['title']?.toString() ?? 'Register' : 'Register';
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(gradient: AppTheme.gradient, shape: BoxShape.circle),
          child: ClipOval(
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.how_to_reg, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              // Removed the duplicate icon here to avoid showing two icons next to the title.
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        )
      ],
    );
  }

  /// Small custom pill-like option used instead of ChoiceChip to avoid
  /// unwanted white fill on dark translucent backgrounds.
  Widget _optionPill({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.white.withOpacity(0.08) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use full width so gradient covers entire screen and there are no black margins.
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: Theme.of(context).appBarTheme.systemOverlayStyle,
        title: const SizedBox.shrink(), // keep AppBar minimal; header inside body
        leading: Container(),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
            padding: const EdgeInsets.all(14.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Top translucent card (same style as competitions top header)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: _topHeaderContent(),
                  ),
                  const SizedBox(height: 12),

                  // If error show error + retry
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                          TextButton.icon(
                            onPressed: _loadCompetition,
                            icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                            label: const Text('Retry', style: TextStyle(color: Colors.white70)),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Main translucent card with details + form
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
                        if (_competition != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // use neutral icon color to match UI
                              const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _competition!['description']?.toString() ?? '',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            if (_competition!['start_date'] != null && _competition!['end_date'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withOpacity(0.01)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_month, size: 14, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${DateFormat('d MMM').format(DateTime.parse(_competition!['start_date']))} → ${DateFormat('d MMM').format(DateTime.parse(_competition!['end_date']))}',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            // Seats pill: make translucent (no bright green/red)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.01)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_seat, size: 14, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text('Seats: $_seatsRemaining', style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                            ),
                            // Team limit pill: translucent
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.01)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.people, size: 14, color: Colors.white70),
                                  SizedBox(width: 4),
                                  // Text below uses string interpolation because _maxTeamSize is variable
                                ],
                              ),
                            ),
                            // team limit text rendered separately to allow interpolation
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              child: Text('Team limit: $_maxTeamSize', style: const TextStyle(color: Colors.white70)),
                            ),
                          ]),
                          const SizedBox(height: 16),
                        ],

                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 20, color: Colors.white70),
                                  const SizedBox(width: 8),
                                  const Text('Registration Type', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _optionPill(
                                    label: 'Individual',
                                    icon: Icons.person,
                                    selected: _type == _RegType.individual,
                                    onTap: () => setState(() => _type = _RegType.individual),
                                  ),
                                  const SizedBox(width: 8),
                                  _optionPill(
                                    label: 'Team',
                                    icon: Icons.group,
                                    selected: _type == _RegType.team,
                                    onTap: () => setState(() => _type = _RegType.team),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Team fields
                              if (_type == _RegType.team) ...[
                                // Team name field (translucent)
                                TextFormField(
                                  controller: teamNameCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  validator: (v) {
                                    if (_type == _RegType.team && (v == null || v.trim().length < 3)) return 'Team name (3+ chars)';
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Enter your team name',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.02),
                                    prefixIcon: const Icon(Icons.group, color: Colors.white70),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // add member emails
                                Row(
                                  children: [
                                    const Icon(Icons.person_add, size: 16, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    const Text('Team Members', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: memberEmailCtrl,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: 'Add member email address',
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.02),
                                          prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // make Add button translucent / subtle
                                    TextButton.icon(
                                      onPressed: _addMemberEmail,
                                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                      label: const Text('Add', style: TextStyle(color: Colors.white)),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.06),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_memberEmails.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.people, size: 16, color: Colors.white70),
                                      const SizedBox(width: 6),
                                      Text('Team Members (${_memberEmails.length})', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: List.generate(_memberEmails.length, (i) {
                                      final e = _memberEmails[i];
                                      // use translucent pill instead of bright Chip
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.02),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white.withOpacity(0.01)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.person, size: 16, color: Colors.white70),
                                            const SizedBox(width: 8),
                                            Text(e, style: const TextStyle(color: Colors.white70)),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => _removeMemberEmail(i),
                                              child: const Icon(Icons.close, size: 16, color: Colors.white70),
                                            )
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],

                              // abstract / description
                              Row(
                                children: [
                                  const Icon(Icons.description_outlined, size: 20, color: Colors.white70),
                                  const SizedBox(width: 8),
                                  const Text('Project Abstract', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 4),
                                  const Text('(Optional)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: abstractCtrl,
                                minLines: 3,
                                maxLines: 6,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Describe your project idea, approach, or solution...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.02),
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(top: 12, left: 12),
                                    child: Icon(Icons.edit_note, color: Colors.white70),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              if (_error != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade800.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error, color: Colors.redAccent, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              CustomButton(
                                text: _submitting ? 'Submitting Registration...' : 'Submit Registration',
                                enabled: !_submitting,
                                onPressed: _submitting ? null : _submitRegistration,
                              ),
                              const SizedBox(height: 8),

                              Center(
                                child: TextButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white70),
                                  label: const Text('Back to Competition', style: TextStyle(color: Colors.white70)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AuthChoice { cancel, login, register }
