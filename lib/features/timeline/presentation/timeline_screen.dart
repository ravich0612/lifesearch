import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/timeline_providers.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/services/haptic_service.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(timelineEventsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180.0,
            backgroundColor: const Color(0xFFFBFBFF),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GradientText(
                    'LifeTimeline',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  Text(
                    'Your journey, curated by AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary.withValues(alpha: 0.7),
                      letterSpacing: 0.5,
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.deepIndigo.withValues(alpha: 0.05),
                      const Color(0xFFFBFBFF),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          timelineAsync.when(
            data: (events) {
              if (events.isEmpty) {
                return const _EmptyTimelineView();
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final event = events[index];
                      final isLast = index == events.length - 1;
                      return _CinematicTimelineItem(
                        event: event,
                        isLast: isLast,
                        index: index,
                      );
                    },
                    childCount: events.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, s) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
          ),
        ],
      ),
    );
  }
}

class _EmptyTimelineView extends StatelessWidget {
  const _EmptyTimelineView();

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.deepIndigo.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 80, color: AppColors.divider),
            ),
            const SizedBox(height: 24),
            const Text('Mapping your destiny...', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            const Text('Your AI-mapped events will appear here.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }
}

class _CinematicTimelineItem extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isLast;
  final int index;

  const _CinematicTimelineItem({
    required this.event,
    required this.isLast,
    required this.index,
  });

  Color _getEventColor(String type) {
    switch (type.toUpperCase()) {
      case 'TRAVEL': return const Color(0xFF4F46E5);
      case 'DINING': return const Color(0xFFF59E0B);
      case 'SHOPPING': return const Color(0xFF10B981);
      case 'DOCUMENTS': return const Color(0xFF8B5CF6);
      case 'OUTING': return const Color(0xFFEC4899);
      default: return const Color(0xFF64748B);
    }
  }

  IconData _getEventIcon(String type) {
    switch (type.toUpperCase()) {
      case 'TRAVEL': return Icons.flight_takeoff_rounded;
      case 'DINING': return Icons.restaurant_rounded;
      case 'SHOPPING': return Icons.shopping_cart_rounded;
      case 'DOCUMENTS': return Icons.description_rounded;
      case 'OUTING': return Icons.forest_rounded;
      default: return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = event['title'] as String;
    final timestamp = event['start_time'] as int;
    final itemCount = event['item_count'] as int;
    final previewPath = event['preview_image'] as String?;
    final type = (event['event_type'] as String? ?? 'GENERAL').toUpperCase();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final eventColor = _getEventColor(type);

    return IntrinsicHeight(
      child: Row(
        children: [
          // ── THE LIGHT THREAD (TIMELINE AXIS) ──
          SizedBox(
            width: 40,
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: eventColor, width: 3),
                    boxShadow: [
                      BoxShadow(color: eventColor.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                ).animate(onPlay: (c) => c.repeat())
                  .scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.3, 1.3), curve: Curves.easeInOut)
                  .then()
                  .scale(duration: 2.seconds, begin: const Offset(1.3, 1.3), end: const Offset(1, 1)),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            eventColor.withValues(alpha: 0.8),
                            const Color(0xFF64748B).withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── THE HERO CARD ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48, left: 12),
              child: GestureDetector(
                onTap: () {
                  HapticService.medium();
                  context.push('/timeline_detail/${event['id']}');
                },
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                    border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: eventColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_getEventIcon(type), color: eventColor, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, MMM d').format(date),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textTertiary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Animated Image Preview (The "Visual Hook")
                      if (previewPath != null && previewPath.isNotEmpty && File(previewPath).existsSync())
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: AspectRatio(
                                  aspectRatio: 1.6,
                                  child: Image.file(
                                    File(previewPath),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // Floating Stats Chip
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.blur_on_rounded, color: Colors.white, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$itemCount items',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Semantic Connection Footer
                      if (itemCount > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Row(
                            children: [
                              ...List.generate(3, (i) => 
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Container(
                                    width: 4, height: 4,
                                    decoration: BoxDecoration(color: eventColor.withValues(alpha: 0.5), shape: BoxShape.circle),
                                  ),
                                )
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'AI linked these moments',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: eventColor.withValues(alpha: 0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.arrow_forward_rounded, size: 14, color: eventColor.withValues(alpha: 0.5)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 800.ms, delay: (index * 150).ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
    );
  }
}
