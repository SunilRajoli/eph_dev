// lib/screens/perks_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // Track expanded cards and redeemed perks
  Set<String> _expandedPerks = {};
  Set<String> _redeemedPerks = {};

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

  Future<void> _redeem(String id, int index) async {
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
      setState(() {
        _redeemedPerks.add(id);
        // Update the perk in the list to show as redeemed
        if (index < _perks.length) {
          _perks[index]['can_redeem'] = false;
          _perks[index]['is_redeemed'] = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Perk redeemed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final message = res['message'] ?? 'Failed to redeem';
      final reasons = res['reasons'];
      final text = reasons != null ? '$message: ${(reasons as List).join(', ')}' : message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open link: $e')),
      );
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

  Widget _buildRedemptionDetails(Map<String, dynamic> perk) {
    final redemptionCode = perk['promo_code'] ?? perk['redemption_code'];
    final redemptionUrl = perk['external_url'] ?? perk['redemption_url'];
    final instructions = perk['redemption_instructions'] ?? perk['instructions'];
    final termsConditions = perk['terms_conditions'];

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Redemption Details',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          // Redemption Code
          if (redemptionCode != null && redemptionCode.toString().isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.confirmation_number, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                const Text('Code:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      redemptionCode.toString(),
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _copyToClipboard(redemptionCode.toString(), 'Redemption code'),
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                  tooltip: 'Copy code',
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Redemption URL
          if (redemptionUrl != null && redemptionUrl.toString().isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.link, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                const Text('Link:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _launchUrl(redemptionUrl.toString()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Text(
                        redemptionUrl.toString(),
                        style: const TextStyle(color: Colors.lightBlue, decoration: TextDecoration.underline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _copyToClipboard(redemptionUrl.toString(), 'Redemption link'),
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                  tooltip: 'Copy link',
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Instructions
          if (instructions != null && instructions.toString().isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Text('Instructions:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                instructions.toString(),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Terms and Conditions
          if (termsConditions != null && termsConditions.toString().isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.gavel, color: Colors.white70, size: 20),
                SizedBox(width: 8),
                Text('Terms & Conditions:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                termsConditions.toString(),
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate safe paddings so content doesn't overlap the transparent header or bottom nav.
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // toolbarHeight in _topHeader() is kToolbarHeight + 8
    final headerHeight = kToolbarHeight + 8;
    final topPadding = topInset + headerHeight + 8; // small extra spacing
    final horizontalPadding = 12.0;
    final bottomPadding = bottomInset + 12.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(kToolbarHeight), child: _topHeader()),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        // DON'T place general padding here; apply precise safe-area paddings below.
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, bottomPadding),
          child: Column(
            children: [
              if (_loading) const LinearProgressIndicator(minHeight: 3),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              // Expanded list area
              Expanded(
                child: _perks.isEmpty && !_loading
                    ? const Center(child: Text('No perks available', style: TextStyle(color: Colors.white70)))
                    : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(top: 0, bottom: bottomPadding),
                  itemCount: _perks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final p = _perks[i];
                    final perkId = p['id'].toString();
                    final isExpanded = _expandedPerks.contains(perkId);
                    final isRedeemed = _redeemedPerks.contains(perkId) || p['is_redeemed'] == true;
                    final canRedeem = p['can_redeem'] == true && !isRedeemed;
                    final xpNeeded = p['xp_needed'] ?? 0;

                    return Card(
                      color: Colors.white.withOpacity(0.03),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p['title'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${p['xp_required'] ?? 0} XP',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Description
                            Text(
                              p['description'] ?? '',
                              style: const TextStyle(color: Colors.white70),
                              maxLines: isExpanded ? null : 3,
                              overflow: isExpanded ? null : TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 12),

                            // Status and action row
                            Row(
                              children: [
                                // Status chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: canRedeem ? Colors.green.withOpacity(0.2) :
                                    isRedeemed ? Colors.blue.withOpacity(0.2) :
                                    Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: canRedeem ? Colors.green.withOpacity(0.5) :
                                      isRedeemed ? Colors.blue.withOpacity(0.5) :
                                      Colors.red.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    canRedeem ? 'Available' :
                                    isRedeemed ? 'Redeemed' :
                                    'Needs ${xpNeeded} more XP',
                                    style: TextStyle(
                                      color: canRedeem ? Colors.green :
                                      isRedeemed ? Colors.blue :
                                      Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                                const Spacer(),

                                // Redeem/Show Details button
                                if (isRedeemed || canRedeem) ...[
                                  ElevatedButton.icon(
                                    onPressed: isRedeemed
                                        ? () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedPerks.remove(perkId);
                                        } else {
                                          _expandedPerks.add(perkId);
                                        }
                                      });
                                    }
                                        : () => _redeem(perkId, i),
                                    icon: Icon(
                                      isRedeemed
                                          ? (isExpanded ? Icons.expand_less : Icons.expand_more)
                                          : Icons.redeem,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isRedeemed
                                          ? (isExpanded ? 'Hide Details' : 'Show Details')
                                          : 'Redeem',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isRedeemed
                                          ? Colors.blue.withOpacity(0.8)
                                          : Theme.of(context).primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  ElevatedButton(
                                    onPressed: null,
                                    child: const Text('Insufficient XP'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.withOpacity(0.3),
                                      foregroundColor: Colors.grey,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // Redemption details (shown when expanded and redeemed)
                            if (isRedeemed && isExpanded) _buildRedemptionDetails(p),
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
      ),
    );
  }
}
