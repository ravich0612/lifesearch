import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/indexing_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final indexingService = ref.read(indexingServiceProvider);
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Already fully indexed → go home
    final isComplete = await indexingService.isIndexingComplete();
    if (isComplete) {
      if (mounted) context.go('/home');
      return;
    }

    // 2. Check existing permission status
    final photoStatus = await Permission.photos.status;
    final storageStatus = await Permission.storage.status;
    final hasAnyPermission = photoStatus.isGranted || storageStatus.isGranted;
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    // Check if user previously chose limited mode
    final choseLimitedMode = prefs.getBool('limited_mode') ?? false;
    
    if (mounted) {
      if (hasAnyPermission) {
        // Has permission but indexing not done — resume
        context.go('/indexing');
      } else if (choseLimitedMode) {
        // User previously said "Not Now" — drop them at home
        context.go('/home');
      } else if (seenOnboarding) {
        // Seen onboarding, but no permissions/limited mode yet — back to permissions
        context.go('/permissions');
      } else {
        // Brand new user
        await prefs.setBool('seen_onboarding', true);
        if (mounted) context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.indigoAccent.withValues(alpha: 0.4),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2.seconds, curve: Curves.easeInOut),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'LifeSearch',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: Colors.white,
                letterSpacing: 2,
                fontSize: 48,
                fontWeight: FontWeight.w800,
              ),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
            const SizedBox(height: 12),
            Text(
              'SEARCH YOUR LIFE INSTANTLY',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textTertiary,
                letterSpacing: 6,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}
