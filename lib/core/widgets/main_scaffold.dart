import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import 'gradient_icon.dart';
import 'gradient_text.dart';

class MainScaffold extends StatefulWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/timeline')) return 1;
    if (location.startsWith('/collections')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/timeline');
        break;
      case 2:
        context.go('/collections');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBarItem(
              icon: Icons.search_rounded,
              label: 'Search',
              isSelected: _calculateSelectedIndex(context) == 0,
              onTap: () => _onItemTapped(0, context),
            ),
            _NavBarItem(
              icon: Icons.timeline_rounded,
              label: 'Timeline',
              isSelected: _calculateSelectedIndex(context) == 1,
              onTap: () => _onItemTapped(1, context),
            ),
            _NavBarItem(
              icon: Icons.folder_copy_outlined,
              label: 'Collections',
              isSelected: _calculateSelectedIndex(context) == 2,
              onTap: () => _onItemTapped(2, context),
            ),
            _NavBarItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              isSelected: _calculateSelectedIndex(context) == 3,
              onTap: () => _onItemTapped(3, context),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected) 
            GradientIcon(icon, size: 26)
          else
            Icon(
              icon,
              color: AppColors.textTertiary,
              size: 26,
            ),
          const SizedBox(height: 4),
          if (isSelected) 
            GradientText(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))
          else
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
