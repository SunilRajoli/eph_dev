// lib/screens/feed_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _videos = [];
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _refreshing = false;
  String? _error;
  int _page = 1;
  final int _limit = 12;
  String _currentFilter = 'recent';

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fetchInitial();
    _scrollController.addListener(_onScroll);
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _videos.clear();
    });
    try {
      await _fetchPage(page: 1);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchPage({required int page}) async {
    if (!_hasMore && page != 1) return;
    if (page > 1) setState(() => _loadingMore = true);

    try {
      final token = await AuthService.getToken();
      final res = await ApiService.getFeed(
        page: page,
        limit: _limit,
        token: token,
        filter: _currentFilter,
      );

      if (res == null || res['success'] != true) {
        throw Exception(res != null ? (res['message'] ?? 'Failed to load feed') : 'No response from API');
      }

      final data = res['data'] ?? {};
      final List vids = data['videos'] ?? [];
      final pagination = data['pagination'] ?? {};
      final bool hasNext = pagination['hasNextPage'] ?? (vids.length == _limit);

      if (page == 1) _videos.clear();

      for (final v in vids) {
        _videos.add(Map<String, dynamic>.from(v));
      }

      setState(() {
        _hasMore = hasNext;
        _page = page;
      });
    } catch (e) {
      rethrow;
    } finally {
      if (mounted) setState(() {
        _loadingMore = false;
        _refreshing = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    final threshold = 200.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (maxScroll - current <= threshold) {
      _fetchPage(page: _page + 1).catchError((e) {
        _showSnackBar('Failed to load more: ${e.toString()}', isError: true);
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await _fetchPage(page: 1);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  void _onFilterChanged(String filter) {
    if (_currentFilter != filter) {
      setState(() => _currentFilter = filter);
      _fetchInitial();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openVideoDetail(String videoId) {
    Navigator.pushNamed(context, '/video', arguments: {'id': videoId});
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'recent', 'label': 'Recent', 'icon': Icons.schedule},
      {'key': 'trending', 'label': 'Trending', 'icon': Icons.trending_up},
      {'key': 'featured', 'label': 'Featured', 'icon': Icons.star},
    ];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _currentFilter == filter['key'];

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.black87 : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.black87 : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              onSelected: (_) => _onFilterChanged(filter['key'] as String),
              selectedColor: Colors.amberAccent.shade400,
              backgroundColor: Colors.white.withOpacity(0.08),
              checkmarkColor: Colors.black87,
              side: BorderSide(
                color: isSelected ? Colors.amberAccent.shade400 : Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> v, int index) {
    final uploader = v['uploader'] ?? {};
    final thumbnail = v['thumbnail_url'] ?? v['thumbnailUrl'] ?? '';
    final title = (v['title'] ?? '').toString();
    final uploaderName = (uploader['name'] ?? 'Unknown').toString();
    final views = _formatCount(v['views_count'] ?? 0);
    final likes = _formatCount(v['likes_count'] ?? 0);
    final length = v['length_sec'] != null ? _formatDuration(v['length_sec']) : '';
    final isVerified = uploader['verified'] == true;
    final college = uploader['college']?.toString() ?? '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, animation, child) {
        return Transform.scale(
          scale: animation,
          child: Opacity(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _openVideoDetail(v['id'].toString()),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail with enhanced overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: thumbnail.isNotEmpty
                        ? Image.network(
                      thumbnail,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderThumbnail(),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return _buildPlaceholderThumbnail(showProgress: true);
                      },
                    )
                        : _buildPlaceholderThumbnail(),
                  ),

                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Play button with ripple effect
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openVideoDetail(v['id'].toString()),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Duration badge
                  if (length.isNotEmpty)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          length,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Content section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 12),

                    // Uploader info and stats
                    Row(
                      children: [
                        // Avatar with border
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.amberAccent.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage: uploader['profile_pic_url'] != null
                                ? NetworkImage(uploader['profile_pic_url'])
                                : null,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            child: uploader['profile_pic_url'] == null
                                ? const Icon(Icons.person, color: Colors.white60, size: 20)
                                : null,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      uploaderName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.verified,
                                      size: 16,
                                      color: Colors.amberAccent.shade400,
                                    ),
                                  ],
                                ],
                              ),
                              if (college.isNotEmpty)
                                Text(
                                  college,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),

                        // Stats row
                        Row(
                          children: [
                            _buildStatChip(Icons.visibility, views),
                            const SizedBox(width: 8),
                            _buildStatChip(Icons.favorite_border, likes),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderThumbnail({bool showProgress = false}) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[800]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: Center(
        child: showProgress
            ? const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white60),
        )
            : const Icon(
          Icons.videocam_outlined,
          color: Colors.white38,
          size: 48,
        ),
      ),
    );
  }

  String _formatDuration(dynamic secRaw) {
    final int sec = (secRaw is int) ? secRaw : int.tryParse(secRaw?.toString() ?? '0') ?? 0;
    if (sec <= 0) return '';
    final minutes = sec ~/ 60;
    final seconds = sec % 60;
    if (minutes > 0) return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    return '0:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatCount(dynamic countRaw) {
    final int count = (countRaw is int) ? countRaw : int.tryParse(countRaw?.toString() ?? '0') ?? 0;
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    }
    return count.toString();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No videos yet',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Videos will appear here once they\'re uploaded',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchInitial,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent.shade400,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Feed',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
              _showSnackBar('Search functionality not implemented yet');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: _loading
                    ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: Colors.amberAccent,
                  child: _error != null
                      ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error: $_error',
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchInitial,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                      : _videos.isEmpty
                      ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      _buildEmptyState(),
                    ],
                  )
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 100),
                    itemCount: _videos.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, idx) {
                      if (idx >= _videos.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                            ),
                          ),
                        );
                      }
                      final v = _videos[idx];
                      return _buildVideoCard(Map<String, dynamic>.from(v), idx);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          backgroundColor: Colors.amberAccent.shade400,
          foregroundColor: Colors.black87,
          onPressed: () => Navigator.pushNamed(context, '/submit'),
          icon: const Icon(Icons.add),
          label: const Text(
            'Submit',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}