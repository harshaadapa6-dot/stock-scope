import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../shell/main_shell.dart';

/// Brief branded splash, then the main shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.duration = const Duration(milliseconds: 1400)});

  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _continue);
  }

  void _continue() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.seed,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.show_chart, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.tagline,
              style: TextStyle(
                color: AppColors.alpha(Colors.white, 0.75),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
