import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.gradient),
      child: const Center(
        child: Text('Feed Screen', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
