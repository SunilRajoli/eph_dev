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
    // nothing here — real init happens in didChangeDependencies so we can read args
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
      } else {
        setState(() {
          _loading = false;
          _error = 'Invalid competition';
        });
      }
    } else {
      setState(() {
        _loading = false;
        _error = 'Missing competition data';
      });
    }
  }

  @override
  void dispose() {
    teamNameCtrl.dispose();
    abstractCtrl.dispose();
    memberEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompetition() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.getCompetitionDetails(competitionId);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>?;
        final comp = data != null && data['competition'] != null ? Map<String, dynamic>.from(data['competition']) : null;
        if (comp != null) {
          setState(() {
            _competition = comp;
            _maxTeamSize = (comp['max_team_size'] ?? comp['maxTeamSize'] ?? 1) as int;
            _seatsRemaining = (comp['seats_remaining'] ?? comp['seatsRemaining'] ?? 0) as int;
            _loading = false;
          });
          return;
        }
      }
      setState(() {
        _error = res['message'] ?? 'Failed to load competition';
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
          title: const Text('Login required', style: TextStyle(color: Colors.white)),
          content: const Text('You must be logged in to register. Login or register now?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(_AuthChoice.cancel), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(_AuthChoice.register), child: const Text('Register')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(_AuthChoice.login), child: const Text('Login')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    // check duplicates
    if (_memberEmails.contains(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email already added')));
      return;
    }
    // check against max team size (leader + members)
    final newSize = 1 + _memberEmails.length + 1; // leader + existing + new
    if (newSize > _maxTeamSize) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Max team size is $_maxTeamSize')));
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
    if (_type == _RegType.team && _memberEmails.isEmpty && (teamNameCtrl.text.trim().isEmpty)) {
      // team must have at least a team name and ideally members (but some competitions allow 1-person team)
      // We'll allow single-member team if server supports it; still require team name.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team name is required for team registration')));
      return;
    }

    // check seats
    if (_seatsRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No seats remaining for this competition')));
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final payload = <String, dynamic>{
        'type': _type == _RegType.individual ? 'individual' : 'team',
        if (_type == _RegType.team) 'team_name': teamNameCtrl.text.trim(),
        if (_memberEmails.isNotEmpty) 'members': _memberEmails,
        if (abstractCtrl.text.trim().isNotEmpty) 'abstract': abstractCtrl.text.trim(),
      };

      final res = await ApiService.registerForCompetition(competitionId, payload);
      if (res['success'] == true) {
        // optionally update UI / seats
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration submitted')));
        // navigate back to competitions or to my registrations
        if (mounted) {
          // refresh competitions list by popping back to competitions
          Navigator.pushNamedAndRemoveUntil(context, '/competitions', (route) => false);
        }
      } else {
        final msg = res['message'] ?? 'Registration failed';
        setState(() {
          _error = msg;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      final msg = 'Network error: ${e.toString()}';
      setState(() {
        _error = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildHeader() {
    final title = _competition != null ? _competition!['title']?.toString() ?? '' : 'Register';
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.94;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Competition Registration'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Container(
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
                  Container(
                    width: width,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 8),
                        if (_competition != null) ...[
                          Text(
                            _competition!['description']?.toString() ?? '',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (_competition!['start_date'] != null && _competition!['end_date'] != null)
                                Chip(
                                  label: Text(
                                    '${DateFormat('d MMM').format(DateTime.parse(_competition!['start_date']))} → ${DateFormat('d MMM').format(DateTime.parse(_competition!['end_date']))}',
                                  ),
                                  backgroundColor: Colors.white.withOpacity(0.02),
                                  labelStyle: const TextStyle(color: Colors.white70),
                                ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text('Seats: $_seatsRemaining'),
                                backgroundColor: Colors.white.withOpacity(0.02),
                                labelStyle: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text('Team limit: $_maxTeamSize'),
                                backgroundColor: Colors.white.withOpacity(0.02),
                                labelStyle: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Registration type', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('Individual'),
                                    selected: _type == _RegType.individual,
                                    onSelected: (v) => setState(() {
                                      _type = _RegType.individual;
                                    }),
                                    selectedColor: Colors.white.withOpacity(0.06),
                                    backgroundColor: Colors.white.withOpacity(0.03),
                                    labelStyle: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('Team'),
                                    selected: _type == _RegType.team,
                                    onSelected: (v) => setState(() {
                                      _type = _RegType.team;
                                    }),
                                    selectedColor: Colors.white.withOpacity(0.06),
                                    backgroundColor: Colors.white.withOpacity(0.03),
                                    labelStyle: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Team fields
                              if (_type == _RegType.team) ...[
                                TextFormField(
                                  controller: teamNameCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  validator: (v) {
                                    if (_type == _RegType.team && (v == null || v.trim().length < 3)) return 'Team name (3+ chars)';
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Team name',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.02),
                                    prefixIcon: const Icon(Icons.group, color: Colors.white70),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // add member emails
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: memberEmailCtrl,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: 'Add member email',
                                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.02),
                                          prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _addMemberEmail,
                                      child: const Text('Add'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.06)),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_memberEmails.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: List.generate(_memberEmails.length, (i) {
                                      final e = _memberEmails[i];
                                      return Chip(
                                        label: Text(e, style: const TextStyle(color: Colors.white70)),
                                        backgroundColor: Colors.white.withOpacity(0.02),
                                        onDeleted: () => _removeMemberEmail(i),
                                      );
                                    }),
                                  ),
                                const SizedBox(height: 12),
                              ],

                              // abstract / description
                              TextFormField(
                                controller: abstractCtrl,
                                minLines: 3,
                                maxLines: 6,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Project abstract / summary (optional)',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.02),
                                  prefixIcon: const Icon(Icons.description_outlined, color: Colors.white70),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (_error != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.red.shade800.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                                ),
                                const SizedBox(height: 12),
                              ],

                              CustomButton(
                                text: _submitting ? 'Submitting...' : 'Submit registration',
                                enabled: !_submitting,
                                onPressed: _submitting ? null : _submitRegistration,
                              ),
                              const SizedBox(height: 8),

                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                              ),
                            ],
                          ),
                        ),
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

enum _AuthChoice { cancel, login, register }
