// lib/screens/competition_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class CompetitionScreen extends StatelessWidget {
  const CompetitionScreen({super.key});

  // Dummy data — replace with API-driven models later
  List<Map<String, dynamic>> _dummyCompetitions() => [
    {
      'id': 'c1',
      'title': 'Smart Helmet',
      'subtitle': 'IoT safety project for construction workers',
      'postedBy': {'name': 'Team Innovate', 'avatarUrl': null},
      'status': 'ongoing', // ongoing | upcoming | completed
      'startDate': DateTime.now().subtract(const Duration(days: 5)),
      'endDate': DateTime.now().add(const Duration(days: 10)),
      'membersCount': 4,
      'maxTeamSize': 6,
      'seatsRemaining': 10,
      'tags': ['IoT', 'Safety', 'Hardware'],
      'thumbnail': null
    },
    {
      'id': 'c2',
      'title': 'Green Energy Challenge',
      'subtitle': 'Renewables & sustainable innovations',
      'postedBy': {'name': 'EcoLabs', 'avatarUrl': null},
      'status': 'upcoming',
      'startDate': DateTime.now().add(const Duration(days: 4)),
      'endDate': DateTime.now().add(const Duration(days: 34)),
      'membersCount': 1,
      'maxTeamSize': 5,
      'seatsRemaining': 30,
      'tags': ['Climate', 'Sustainability'],
      'thumbnail': null
    },
    {
      'id': 'c3',
      'title': 'Campus App Sprint',
      'subtitle': 'Build apps to improve campus life',
      'postedBy': {'name': 'CS Club', 'avatarUrl': null},
      'status': 'completed',
      'startDate': DateTime.now().subtract(const Duration(days: 60)),
      'endDate': DateTime.now().subtract(const Duration(days: 30)),
      'membersCount': 3,
      'maxTeamSize': 4,
      'seatsRemaining': 0,
      'tags': ['Mobile', 'UX', 'Student'],
      'thumbnail': null
    },
  ];

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

  @override
  Widget build(BuildContext context) {
    final comps = _dummyCompetitions();
    final counts = {
      'ongoing': comps.where((c) => c['status'] == 'ongoing').length,
      'upcoming': comps.where((c) => c['status'] == 'upcoming').length,
      'completed': comps.where((c) => c['status'] == 'completed').length,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('EPH'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Row(
            children: const [
              Icon(Icons.engineering, color: Colors.white),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/roles', arguments: {'mode': 'login'});
            },
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/roles', arguments: {'mode': 'register'});
            },
            child: const Text('Register', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _StatCard(label: 'Ongoing', count: counts['ongoing'] ?? 0, icon: Icons.play_arrow, color: Colors.greenAccent),
                  const SizedBox(width: 10),
                  _StatCard(label: 'Upcoming', count: counts['upcoming'] ?? 0, icon: Icons.schedule, color: Colors.amberAccent),
                  const SizedBox(width: 10),
                  _StatCard(label: 'Completed', count: counts['completed'] ?? 0, icon: Icons.check_circle, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Section header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Competitions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () {
                      // future: open filters
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filter not implemented')));
                    },
                    icon: const Icon(Icons.filter_list, color: Colors.white70),
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: comps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final c = comps[index];
                  final status = (c['status'] as String?) ?? 'upcoming';
                  final postedBy = c['postedBy'] as Map<String, dynamic>? ?? {};
                  final start = c['startDate'] as DateTime?;
                  final end = c['endDate'] as DateTime?;
                  final df = DateFormat('dd MMM');

                  return Card(
                    color: Colors.white.withOpacity(0.03),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + status badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // thumbnail placeholder
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.emoji_objects_outlined, color: Colors.white70),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(c['subtitle'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.circle, size: 8, color: _statusColor(status)),
                                              const SizedBox(width: 6),
                                              Text(_statusLabel(status), style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                        if (start != null && end != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20)),
                                            child: Text('${df.format(start)} → ${df.format(end)}', style: const TextStyle(color: Colors.white70)),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20)),
                                          child: Text('${c['membersCount']} members', style: const TextStyle(color: Colors.white70)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20)),
                                          child: Text('${c['seatsRemaining']} seats left', style: const TextStyle(color: Colors.white70)),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              // register button
                              Column(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      // Navigate to registration flow (route may not exist yet)
                                      final routeName = '/competitions/register';
                                      if (Navigator.canPop(context)) {
                                        // push with arguments
                                        Navigator.pushNamed(context, routeName, arguments: {'competitionId': c['id']});
                                      } else {
                                        // still push
                                        Navigator.pushNamed(context, routeName, arguments: {'competitionId': c['id']});
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _statusColor(status),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Register'),
                                  ),
                                  const SizedBox(height: 8),
                                  IconButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open details (not implemented)')));
                                    },
                                    icon: const Icon(Icons.more_horiz, color: Colors.white70),
                                  )
                                ],
                              )
                            ],
                          ),
                          const Divider(color: Colors.white10),
                          // bottom row: posted by, tags
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white.withOpacity(0.06),
                                child: Text(
                                  (postedBy['name'] as String?)?.substring(0, 1).toUpperCase() ?? '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Posted by ${postedBy['name'] ?? 'Unknown'}', style: const TextStyle(color: Colors.white70)),
                              ),
                              Wrap(
                                spacing: 6,
                                children: (c['tags'] as List<dynamic>).take(3).map((t) {
                                  return Chip(
                                    backgroundColor: Colors.white.withOpacity(0.04),
                                    label: Text(t.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.count, required this.icon, required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 72,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(count.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
