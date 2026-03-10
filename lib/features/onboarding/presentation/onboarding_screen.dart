import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/gradient_icon.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Search your life\ninstantly',
      subtitle: 'Find screenshots, documents, photos, and memories in seconds.',
      icon: Icons.search_rounded,
    ),
    OnboardingData(
      title: 'Your phone\nremembers everything',
      subtitle: 'LifeSearch builds a private memory index so you can retrieve anything quickly.',
      icon: Icons.memory_rounded,
    ),
    OnboardingData(
      title: 'Private by\ndefault',
      subtitle: 'Everything is indexed locally on your device unless you choose future cloud features.',
      icon: Icons.lock_outline_rounded,
    ),
    OnboardingData(
      title: 'Built for\nspeed',
      subtitle: 'Recent items are indexed first so you can start searching immediately.',
      icon: Icons.bolt_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _OnboardingPage(data: _pages[index]);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index 
                                  ? AppColors.deepIndigo 
                                  : AppColors.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ).animate(target: _currentPage == index ? 1 : 0).scaleX(),
                        ),
                      ),
                      const SizedBox(height: 32),
                      PrimaryGradientButton(
                        onPressed: () {
                          if (_currentPage < _pages.length - 1) {
                            _pageController.nextPage(
                              duration: 400.ms,
                              curve: Curves.easeInOutCubic,
                            );
                          } else {
                            context.go('/permissions');
                          }
                        },
                        child: Text(
                          _currentPage == _pages.length - 1 ? 'Get Started' : 'Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 16,
              right: 24,
              child: TextButton(
                onPressed: () => context.go('/permissions'),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.backgroundElevated,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final IconData icon;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated,
              shape: BoxShape.circle,
            ),
            child: GradientIcon(
              data.icon,
              size: 80,
            ),
          ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
          const SizedBox(height: 64),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge,
          ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}
