import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../widgets/main_scaffold.dart';
import '../../features/home/presentation/splash_screen.dart';
import '../../features/permissions/presentation/permissions_screen.dart';
import '../../features/indexing/presentation/indexing_progress_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/collections/presentation/collections_screen.dart';
import '../../features/search/presentation/result_detail_screen.dart';
import '../../features/timeline/presentation/timeline_screen.dart';
import '../../features/timeline/presentation/timeline_event_detail_screen.dart';
import '../../features/settings/presentation/developer_tools_screen.dart';
import '../../features/reflection/presentation/reflection_screen.dart';
import '../../features/settings/presentation/transparency_hub_screen.dart';

final navigationKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: navigationKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/permissions',
      builder: (context, state) => const PermissionsScreen(),
    ),
    GoRoute(
      path: '/indexing',
      builder: (context, state) => const IndexingProgressScreen(),
    ),
    GoRoute(
      path: '/reflection',
      builder: (context, state) => const ReflectionScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/timeline',
          builder: (context, state) => const TimelineScreen(),
        ),
        GoRoute(
          path: '/collections',
          builder: (context, state) => const CollectionsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/transparency',
          builder: (context, state) => const TransparencyHubScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/detail/:id',
          builder: (context, state) => ResultDetailScreen(itemId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/timeline_detail/:id',
          builder: (context, state) => TimelineEventDetailScreen(eventId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/developer',
          builder: (context, state) => const DeveloperToolsScreen(),
        ),
      ],
    ),
  ],
);
