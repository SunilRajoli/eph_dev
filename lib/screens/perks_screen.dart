import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PerksScreen extends StatelessWidget {
  const PerksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.gradient),
      child: const Center(
        child: Text('Perks Screen', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
