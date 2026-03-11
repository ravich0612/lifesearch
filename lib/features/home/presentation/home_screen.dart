import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/indexing_service.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../search/providers/search_providers.dart';
import '../providers/home_providers.dart' as hp;

// Triggering re-compilation after fixing syntax.

final scrollOffsetProvider = StateProvider<double>((ref) => 0.0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentMemoriesAsync = ref.watch(hp.recentMemoriesProvider);
    final statusStream = ref.watch(indexingServiceProvider).indexingStatus;
    final totalCountAsync = ref.watch(hp.memoryCountProvider);
    final progressAsync = ref.watch(hp.indexingProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            ref.read(scrollOffsetProvider.notifier).state = notification.metrics.pixels;
          }
          return false;
        },
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.backgroundLight,
            elevation: 0,
            centerTitle: false,
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF7B66FF), // Vibrant Purple
                  Color(0xFF4AC7FA), // Electric Blue
                  Color(0xFF00D2FF), // Bright Cyan
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'LifeSearch',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
            ],
          ),
          
          // Indexing Status Banner
          StreamBuilder<Map<String, dynamic>>(
            stream: statusStream,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null || (data['progress'] ?? 0.0) >= 1.0) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              
              final progress = data['progress'] as double;
              final message = data['message'] as String;

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.deepIndigo.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.deepIndigo.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepIndigo),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(message, style: const TextStyle(color: AppColors.deepIndigo, fontWeight: FontWeight.bold, fontSize: 13))),
                            Text('${(progress * 100).toInt()}%', style: const TextStyle(color: AppColors.deepIndigo, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: AppColors.deepIndigo.withValues(alpha: 0.1),
                            color: AppColors.deepIndigo,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Limited Mode Banner (shows when no data yet and not actively indexing)
          SliverToBoxAdapter(
            child: totalCountAsync.when(
              data: (count) => count == 0
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('limited_mode', false);
                        if (context.mounted) context.go('/permissions');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade600, Colors.deepOrange.shade400],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Limited Mode Active',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Tap to grant access and unlock full search',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(),
                  )
                : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            ),
          ),

          // ── REAL-TIME OCR ANALYSIS PROGRESS CARD ──────────────────
          SliverToBoxAdapter(
            child: progressAsync.when(
              data: (p) {
                if (p.total == 0 || p.isComplete) return const SizedBox.shrink();
                final pct = (p.progressPercent * 100).toInt();
                final gradColor = Color.lerp(
                  const Color(0xFF7B66FF),
                  const Color(0xFF00D2FF),
                  p.progressPercent,
                )!;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: GestureDetector(
                    onTap: () => ref.invalidate(hp.indexingProgressProvider),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.deepIndigo.withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 16),
                              ).animate(onPlay: (c) => c.repeat())
                                .rotate(duration: 3.seconds, curve: Curves.easeInOut),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Refining your memories',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      '${p.pending} tasks remaining to unlock full search',
                                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              ShaderMask(
                                shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                                child: Text(
                                  '$pct%',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: p.progressPercent,
                              minHeight: 6,
                              backgroundColor: AppColors.deepIndigo.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(gradColor),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _StatPill(
                                Icons.text_snippet_rounded,
                                '${p.withExtractedText} text extracted',
                                const Color(0xFF5C6BC0),
                              ),
                              const SizedBox(width: 8),
                              _StatPill(
                                Icons.auto_awesome_rounded,
                                '${p.triggers} smart moments',
                                const Color(0xFF00897B),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _StoryHighlightsBar(),
                  const SizedBox(height: 28),
                  
                  // Ultra-Prominent Hero Search Bar
                  GestureDetector(
                    onTap: () {
                      HapticService.medium();
                      context.push('/search');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.deepIndigo.withValues(alpha: 0.12), 
                            blurRadius: 40, 
                            offset: const Offset(0, 15),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: AppColors.deepIndigo.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.transparent,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Gradient Border Effect
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7B66FF), // Vibrant Purple
                                    Color(0xFF00D2FF), // Bright Cyan
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                          // Inner Content Container
                          Container(
                            margin: const EdgeInsets.all(2.5), // The border thickness
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFF7B66FF), Color(0xFF00D2FF)],
                                  ).createShader(bounds),
                                  child: const Icon(Icons.search_rounded, color: Colors.white, size: 30),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Search across ${totalCountAsync.value ?? "900+"} memories...',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textPrimary.withValues(alpha: 0.6),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.deepIndigo.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.tune_rounded, size: 18, color: AppColors.deepIndigo),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 600.ms).scale(
                    begin: const Offset(0.95, 0.95), 
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                  ),
                  
                  const SizedBox(height: 24),
                  const _LifeHorizonsSection(),
                  const SizedBox(height: 32),
                  
                  GradientText('Recently Mapped', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20)).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: recentMemoriesAsync.when(
              data: (memories) => memories.isEmpty 
                ? const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Connecting to your memories...'))))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _MemoryListItem(memory: memories[index]).animate().fadeIn(delay: (200 + (index * 50)).ms),
                      childCount: memories.length,
                    ),
                  ),
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
            ),
          ),
        ],
      ),
    ],
  ),
),
);
  }
}

// Removed _CoverageCard and _FilterChip to clean up UI

class _MemoryListItem extends StatelessWidget {
  final Map<String, dynamic> memory;
  const _MemoryListItem({required this.memory});

  @override
  Widget build(BuildContext context) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(memory['created_at'] ?? 0);
    final String timeAgo = DateFormat.yMMMd().format(date);
    final String path = memory['file_path'] ?? '';
    final String bucket = memory['source_bucket'] ?? 'GALLERY';

    return GestureDetector(
      onTap: () {
        HapticService.selection();
        context.push('/detail/${memory['id']}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(24), 
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.backgroundDark.withValues(alpha: 0.05), 
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _buildPreview(path, memory['mime_type'] ?? ''),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.deepIndigo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bucket, 
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.deepIndigo, letterSpacing: 0.5),
                        ),
                      ),
                      Text(timeAgo, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    memory['title'] ?? 'Untitled', 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.divider),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(String path, String mimeType) {
    if (path.isEmpty || !File(path).existsSync()) {
      return const Icon(Icons.description_outlined, color: AppColors.textTertiary);
    }
    
    if (FileUtils.isVideo(path) || mimeType.startsWith('video/')) {
      return Container(
        color: AppColors.backgroundDark.withValues(alpha: 0.1),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.videocam_rounded, color: AppColors.textTertiary, size: 24),
            Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
          ],
        ),
      );
    }

    if (FileUtils.isImage(path) || mimeType.startsWith('image/')) {
       return Image.file(File(path), fit: BoxFit.cover);
    }

    // Handle Documents/Others
    final pathLower = path.toLowerCase();
    final isPdf = mimeType.contains('pdf') || pathLower.endsWith('.pdf');
    final isSpreadsheet = mimeType.contains('spreadsheet') || mimeType.contains('csv') || pathLower.endsWith('.xlsx') || pathLower.endsWith('.xls') || pathLower.endsWith('.csv');

    IconData icon = Icons.description_rounded;
    Color color = AppColors.deepIndigo.withValues(alpha: 0.7);
    
    if (isPdf) {
      icon = Icons.picture_as_pdf_rounded;
      color = Colors.red.withValues(alpha: 0.7);
    } else if (isSpreadsheet) {
      icon = Icons.table_chart_rounded;
      color = Colors.green.withValues(alpha: 0.7);
    }

    return Container(
      color: AppColors.backgroundDark.withValues(alpha: 0.05),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _StoryHighlightsBar extends ConsumerWidget {
  const _StoryHighlightsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flashbacksAsync = ref.watch(hp.flashbackMemoriesProvider);

    return flashbacksAsync.when(
      data: (flashbacks) {
        if (flashbacks.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: flashbacks.length,
            itemBuilder: (context, index) {
              final memory = flashbacks[index];
              final years = memory['flashback_years'];
              final path = memory['file_path'] as String? ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: GestureDetector(
                  onTap: () {
                    HapticService.medium();
                    context.push('/detail/${memory['id']}');
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF7B66FF),
                              const Color(0xFF00D2FF),
                              years == 1 ? Colors.orange : Colors.pinkAccent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(35),
                            child: path.isNotEmpty && File(path).existsSync()
                                ? Image.file(File(path), fit: BoxFit.cover)
                                : const Icon(Icons.history_rounded, color: AppColors.deepIndigo),
                          ),
                        ),
                      ).animate(onPlay: (c) => c.repeat())
                        .shimmer(duration: 3.seconds, delay: (index * 500).ms),
                      const SizedBox(height: 6),
                      Text(
                        '${years}y ago',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}


class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatPill(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifeHorizonsSection extends ConsumerWidget {
  const _LifeHorizonsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(hp.bucketCountsProvider);
    final previewsAsync = ref.watch(hp.bucketPreviewsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIFE HORIZONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textTertiary,
                  letterSpacing: 1.5,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/collections'),
                child: const Text(
                  'VIEW ALL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.deepIndigo),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: countsAsync.when(
            data: (counts) => previewsAsync.when(
              data: (previews) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: counts.entries.map((entry) {
                  final bucket = entry.key;
                  final count = entry.value;
                  final preview = previews[bucket];
                  final color = AppColors.moodColors[bucket.toUpperCase()] ?? AppColors.deepIndigo;

                  return _HorizonCard(
                    bucket: bucket,
                    count: count,
                    previewPath: preview,
                    color: color,
                  );
                }).toList(),
              ),
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _HorizonCard extends ConsumerWidget {
  final String bucket;
  final int count;
  final String? previewPath;
  final Color color;

  const _HorizonCard({
    required this.bucket,
    required this.count,
    this.previewPath,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = bucket[0] + bucket.substring(1).toLowerCase();

    return GestureDetector(
      onTap: () {
        HapticService.selection();
        ref.read(searchQueryProvider.notifier).state = '';
        ref.read(activeBucketProvider.notifier).state = bucket;
        context.push('/search');
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Image/Placeholder
            Positioned.fill(
              child: previewPath != null && File(previewPath!).existsSync()
                  ? Image.file(File(previewPath!), fit: BoxFit.cover)
                  : Container(color: color.withValues(alpha: 0.1)),
            ),
            // Glass Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Content
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  Text(
                    '$count items',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().scale(begin: const Offset(0.9, 0.9), delay: 200.ms),
    );
  }
}
