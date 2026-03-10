import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/home_providers.dart' as hp;
import '../../../core/services/indexing_service.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/services/haptic_service.dart';

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
      body: Stack(
        children: [
          const _AnimatedMoodBackground(),
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
                      color: AppColors.deepIndigo.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.deepIndigo.withValues(alpha: 0.1)),
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
                  const SizedBox(height: 24),
                  const _LifeSynthesisSection(),
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
                  const _LifePulseSection(),
                  
                  const SizedBox(height: 24),
                  const _MemoryTriggerCards(),
                  const SizedBox(height: 24),
                  
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
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
          ),
        ],
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
    
    if (mimeType.startsWith('video/')) {
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

    final pathLower = path.toLowerCase();
    final isWordDoc = mimeType.contains('word') || mimeType.contains('officedocument') || pathLower.endsWith('.docx') || pathLower.endsWith('.doc');
    final isPdf = mimeType.contains('pdf') || pathLower.endsWith('.pdf');
    final isSpreadsheet = mimeType.contains('spreadsheet') || mimeType.contains('csv') || pathLower.endsWith('.xlsx') || pathLower.endsWith('.xls') || pathLower.endsWith('.csv');
    final isText = mimeType.contains('text') || pathLower.endsWith('.txt') || pathLower.endsWith('.rtf');

    if (isWordDoc || isPdf || isSpreadsheet || isText) {
      IconData icon;
      Color color;
      
      if (isPdf) {
        icon = Icons.picture_as_pdf_rounded;
        color = Colors.red.withValues(alpha: 0.7);
      } else if (isSpreadsheet) {
        icon = Icons.table_chart_rounded;
        color = Colors.green.withValues(alpha: 0.7);
      } else {
        icon = Icons.description_rounded;
        color = AppColors.deepIndigo.withValues(alpha: 0.7);
      }

      return Container(
        color: AppColors.backgroundDark.withValues(alpha: 0.05),
        child: Icon(icon, color: color, size: 28),
      );
    }
    
    return Image.file(File(path), fit: BoxFit.cover);
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

class _LifePulseSection extends ConsumerWidget {
  const _LifePulseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulseAsync = ref.watch(hp.lifePulseProvider);

    return pulseAsync.when(
      data: (pulse) {
        if (pulse.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Text(
                    'Your Life Pulse',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5),
                  ),
                  const Spacer(),
                  Text(
                    'Last 50 memories',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                children: pulse.entries.map((entry) {
                  final color = _getPulseColor(entry.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.key.toUpperCase(),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 0.5),
                            ),
                            const Spacer(),
                            Text(
                              '${(entry.value * 100).toInt()}%',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: entry.value,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.6)]),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: [
                                    BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                              ).animate().shimmer(duration: 2.seconds, delay: 500.ms),
                            ).animate().scaleX(begin: 0, end: 1, duration: 1200.ms, curve: Curves.easeOutCubic),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Color _getPulseColor(String bucket) {
    switch (bucket.toUpperCase()) {
      case 'DOCUMENTS': return const Color(0xFF6366F1);
      case 'RECEIPTS': return const Color(0xFF10B981);
      case 'GALLERY': return const Color(0xFFF59E0B);
      default: return AppColors.deepIndigo;
    }
  }
}

class _LifeSynthesisSection extends ConsumerWidget {
  const _LifeSynthesisSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulseAsync = ref.watch(hp.lifePulseProvider);

    return pulseAsync.when(
      data: (pulse) {
        if (pulse.isEmpty) return const SizedBox.shrink();

        final narrative = _generateNarrative(pulse);
        final dominant = _getDominant(pulse);
        final moodColor = AppColors.moodColors[dominant] ?? AppColors.deepIndigo;

        return Center(
          child: Column(
            children: [
              GestureDetector(
                onLongPress: () {
                  HapticService.heavy();
                  context.push('/reflection');
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                     // The Halo
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: moodColor.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat())
                      .scale(duration: 3.seconds, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), curve: Curves.easeInOutSine)
                      .then()
                      .scale(duration: 3.seconds, begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8)),
  
                    // The Orb
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.9),
                            moodColor.withValues(alpha: 0.3),
                            moodColor,
                          ],
                          center: const Alignment(-0.3, -0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _getNarrativeIcon(dominant),
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat())
                     .shimmer(duration: 4.seconds, color: Colors.white.withValues(alpha: 0.4))
                     .blur(begin: const Offset(0,0), end: const Offset(2,2), duration: 2.seconds)
                     .then()
                     .blur(begin: const Offset(2,2), end: const Offset(0,0), duration: 2.seconds),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Text(
                      narrative.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: moodColor,
                      ),
                    ).animate().fadeIn(duration: 1.seconds),
                    const SizedBox(height: 8),
                    Text(
                      'Your Life Reflection',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hold the orb for a mirror reflection',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ).animate(onPlay: (c) => c.repeat())
                     .shimmer(duration: 3.seconds, delay: 2.seconds)
                     .moveY(begin: 0, end: 2, duration: 2.seconds, curve: Curves.easeInOut)
                     .then()
                     .moveY(begin: 2, end: 0, duration: 2.seconds, curve: Curves.easeInOut),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  String _getDominant(Map<String, double> pulse) {
    String dominant = 'GENERAL';
    double max = 0.0;
    pulse.forEach((k, v) { if (v > max) { max = v; dominant = k.toUpperCase(); } });
    return dominant;
  }

  String _generateNarrative(Map<String, double> pulse) {
    final dominant = _getDominant(pulse);
    switch (dominant) {
      case 'TRAVEL': return "A season of wide horizons";
      case 'DOCUMENTS': return "Focused intent and growth";
      case 'RECEIPTS': return "Investment in your journey";
      case 'GALLERY': return "Capturing color and light";
      default: return "A steady, flowing pulse";
    }
  }

  IconData _getNarrativeIcon(String dominant) {
    switch (dominant) {
      case 'TRAVEL': return Icons.explore_rounded;
      case 'DOCUMENTS': return Icons.auto_awesome_mosaic_rounded;
      case 'RECEIPTS': return Icons.account_balance_wallet_rounded;
      default: return Icons.bubble_chart_rounded;
    }
  }
}

class _AnimatedMoodBackground extends ConsumerWidget {
  const _AnimatedMoodBackground();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulseAsync = ref.watch(hp.lifePulseProvider);

    return pulseAsync.when(
      data: (pulse) {
        // Find dominant color based on densest category
        String dominant = 'GENERAL';
        double maxDensity = 0.0;
        pulse.forEach((k, v) {
          if (v > maxDensity) {
            maxDensity = v;
            dominant = k.toUpperCase();
          }
        });

        final moodColor = AppColors.moodColors[dominant] ?? AppColors.deepIndigo;

        return Positioned.fill(
          child: AnimatedContainer(
            duration: 5.seconds,
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.8, -0.7),
                radius: 1.5,
                colors: [
                  moodColor.withValues(alpha: 0.08),
                  Colors.white,
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

class _MemoryTriggerCards extends ConsumerWidget {
  const _MemoryTriggerCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggersAsync = ref.watch(hp.activeTriggersProvider);

    return triggersAsync.when(
      data: (triggers) {
        if (triggers.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Smart Suggestions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: triggers.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final trigger = triggers[index];
                  return _TriggerCardItem(trigger: trigger);
                },
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _TriggerCardItem extends ConsumerWidget {
  final Map<String, dynamic> trigger;
  
  const _TriggerCardItem({required this.trigger});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = trigger['trigger_type'] as String;
    String title = '';
    String description = '';
    String actionLabel = '';
    IconData icon = Icons.auto_awesome_rounded;
    Color color = AppColors.deepIndigo;
    
    switch (type) {
      case 'FLIGHT':
        title = 'Flight Detected';
        description = 'Add flight to your calendar.';
        actionLabel = 'Add Event';
        icon = Icons.flight_takeoff_rounded;
        color = Colors.blueAccent;
        break;
      case 'PARKING':
        title = 'Parking Location';
        description = 'Save your parking spot.';
        actionLabel = 'Save Spot';
        icon = Icons.local_parking_rounded;
        color = Colors.orange;
        break;
      case 'PACKAGE':
        title = 'Track Package';
        description = 'Shipment tracking number detected.';
        actionLabel = 'Track';
        icon = Icons.local_shipping_rounded;
        color = Colors.brown;
        break;
      case 'RECEIPT':
        title = 'Save Receipt';
        description = 'Purchase detected.';
        actionLabel = 'Save';
        icon = Icons.receipt_long_rounded;
        color = Colors.green;
        break;
      case 'OTP':
        title = 'Verification Code';
        description = 'Temporary code detected.';
        actionLabel = 'Copy';
        icon = Icons.password_rounded;
        color = Colors.purpleAccent;
        break;
      case 'ADDRESS':
        title = 'Location Found';
        description = 'Address detected in image.';
        actionLabel = 'Open Maps';
        icon = Icons.map_rounded;
        color = Colors.redAccent;
        break;
      default:
        title = 'Suggestion';
        description = 'Tap to review this item.';
        actionLabel = 'Review';
    }

    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await ref.read(hp.databaseServiceProvider).dismissTrigger(trigger['id'] as String);
                  ref.invalidate(hp.activeTriggersProvider);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.divider, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary), maxLines: 1),
          const Spacer(),
          ElevatedButton(
            onPressed: () async {
              // Mark as accepted and refresh UI
              await ref.read(hp.databaseServiceProvider).acceptTrigger(trigger['id'] as String);
              ref.invalidate(hp.activeTriggersProvider);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Action "$actionLabel" executed! (Demo)')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.1),
              foregroundColor: color,
              elevation: 0,
              minimumSize: const Size(double.infinity, 36),
              padding: EdgeInsets.zero,
            ),
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
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
