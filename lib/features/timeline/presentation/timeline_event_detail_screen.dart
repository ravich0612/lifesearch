import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/timeline_providers.dart';

class TimelineEventDetailScreen extends ConsumerWidget {
  final String eventId;

  const TimelineEventDetailScreen({required this.eventId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventItemsAsync = ref.watch(timelineEventItemsProvider(eventId));
    final allEventsAsync = ref.watch(timelineEventsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: allEventsAsync.when(
        data: (events) {
          final event = events.firstWhere((e) => e['id'] == eventId, orElse: () => {});
          if (event.isEmpty) return const Center(child: Text('Event not found.'));

          final title = event['title'] as String;
          final timestamp = event['start_time'] as int;
          final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(timestamp));
          final previewPath = event['preview_image'] as String?;
          final type = (event['event_type'] as String? ?? 'GENERAL').toUpperCase();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── PREMIUM HEADER ──
              SliverAppBar(
                expandedHeight: 340,
                pinned: true,
                elevation: 0,
                stretch: true,
                backgroundColor: Colors.white,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                  centerTitle: false,
                  titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.5,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                        ),
                      ),
                      Text(
                        dateStr.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                        ),
                      ),
                    ],
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (previewPath != null && previewPath.isNotEmpty && File(previewPath).existsSync())
                        Image.file(File(previewPath), fit: BoxFit.cover)
                      else
                        Container(
                          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                          child: const Center(child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 48)),
                        ),
                      // Sophisticated Gradient Overlay
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black38,
                              Colors.black87,
                            ],
                            stops: [0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── INFO & STATS ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    children: [
                      _StatChip(icon: Icons.collections_rounded, label: '${event['item_count']} Memories'),
                      const SizedBox(width: 8),
                      _StatChip(icon: Icons.label_important_rounded, label: type),
                    ],
                  ),
                ),
              ),

              // ── PHOTO GRID ──
              eventItemsAsync.when(
                data: (items) {
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.0,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = items[index];
                          final path = item['file_path'] as String;
                          return GestureDetector(
                            onTap: () => context.push('/detail/${item['id']}'),
                            child: Hero(
                              tag: 'memory_${item['id']}',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  image: DecorationImage(
                                    image: FileImage(File(path)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ).animate()
                            .fadeIn(duration: 400.ms, delay: (50 * index).ms)
                            .scale(begin: const Offset(0.9, 0.9));
                        },
                        childCount: items.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                error: (e, s) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
