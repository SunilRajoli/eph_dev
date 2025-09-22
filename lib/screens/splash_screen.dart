// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScaleAnim;
  late final Animation<double> _logoFadeAnim;
  late final Animation<Offset> _cardSlideAnim;

  double _progress = 0.0;
  Timer? _progressTimer;

  final Duration totalDuration = const Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.05).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    ]).animate(_logoController);

    _logoFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _cardSlideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _logoController.forward();

    // Start progress animation
    _startProgress();

    // Check token and decide navigation
    _attemptAutoLogin();
  }

  void _startProgress() {
    final int ticks = 18;
    final int tickMs = (totalDuration.inMilliseconds / ticks).round();

    _progressTimer?.cancel();
    _progress = 0.0;

    _progressTimer = Timer.periodic(Duration(milliseconds: tickMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress += 1 / ticks;
        if (_progress >= 0.95) {
          _progress = 0.95; // hold until validation finishes
          timer.cancel();
        }
      });
    });
  }

  Future<void> _attemptAutoLogin() async {
    try {
      final token = await AuthService.getToken();

      // If there's no token, show the animation then goto competitions (unauthenticated)
      if (token == null) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        setState(() => _progress = 1.0);
        await Future.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/competitions');
        return;
      }

      // Validate token by calling profile endpoint
      final res = await ApiService.getProfile(token);
      if (res['success'] == true) {
        // token valid - optionally save user again
        final data = res['data'] as Map<String, dynamic>?;
        final user = data != null && data['user'] != null ? Map<String, dynamic>.from(data['user']) : null;
        if (user != null) {
          await AuthService.saveUser(user);
        }

        // Complete progress, then navigate to competitions (or dashboard)
        if (!mounted) return;
        setState(() => _progress = 1.0);
        await Future.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/competitions');
      } else {
        // token invalid -> clear storage and go to competitions (unauthenticated)
        await AuthService.clearToken();
        if (!mounted) return;
        setState(() => _progress = 1.0);
        await Future.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/competitions');
      }
    } catch (e) {
      // Network error or other -> fallback to unauthenticated flow
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _progress = 1.0);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/competitions');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  Widget _buildLogo(double size) {
    const String assetPath = 'assets/logo.png';
    return ScaleTransition(
      scale: _logoScaleAnim,
      child: FadeTransition(
        opacity: _logoFadeAnim,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.06),
          ),
          child: ClipOval(
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, err, stack) {
                return Center(
                  child: Icon(
                    Icons.engineering,
                    size: size * 0.55,
                    color: Colors.white.withOpacity(0.95),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width * 0.86;
    final logoSize = cardWidth * 0.28;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.gradient),
        child: SafeArea(
          child: Center(
            child: SlideTransition(
              position: _cardSlideAnim,
              child: Container(
                width: cardWidth,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(logoSize),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'EPH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          '(Engineering Projects Hub)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Showcase projects, connect with hiring teams and investors, and participate in competitions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: _progress,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _progress >= 1.0 ? 'Ready' : 'Checking session...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(_progress * 100).clamp(0, 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: 0.85,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.info_outline, size: 14, color: Colors.white70),
                          SizedBox(width: 6),
                          Text(
                            'Tip: Use your college email to register for competitions.',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
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
      ),
    );
  }
}
