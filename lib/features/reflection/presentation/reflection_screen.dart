import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/home_providers.dart' as hp;
import '../../../core/theme/app_colors.dart';
import 'dart:io';
import 'dart:math' as math;

class ReflectionScreen extends ConsumerWidget {
  const ReflectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentMemoriesAsync = ref.watch(hp.recentMemoriesProvider);
    final pulseAsync = ref.watch(hp.lifePulseProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // ── THE NEBULA BACKGROUND ──
          Positioned.fill(
            child: _NebulaBackground(pulseAsync: pulseAsync),
          ),

          // ── THE MEMORY CONSTELLATION ──
          recentMemoriesAsync.when(
            data: (memories) {
              if (memories.isEmpty) return const _EmptyState();
              return _MemoryConstellation(memories: memories);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white24)),
            error: (_, __) => const _EmptyState(),
          ),

          // ── OVERLAY HUD ──
          Positioned(
            top: 60,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIFE REFLECTION',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                        fontSize: 12,
                      ),
                    ).animate().fadeIn().slideX(begin: -0.2),
                    const SizedBox(height: 4),
                    Container(
                      width: 40,
                      height: 2,
                      color: AppColors.cyanAccent,
                    ).animate().scaleX(duration: 1.seconds),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                ),
              ],
            ),
          ),
          
          // ── BOTTOM CAPTION ──
          Positioned(
            bottom: 50,
            left: 40,
            right: 40,
            child: const Text(
              'A cinematic view of your digital journey. Your memories, drifting in harmony.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(delay: 1.seconds),
          ),
        ],
      ),
    );
  }
}

class _NebulaBackground extends StatelessWidget {
  final AsyncValue<Map<String, double>> pulseAsync;
  const _NebulaBackground({required this.pulseAsync});

  @override
  Widget build(BuildContext context) {
    return pulseAsync.when(
      data: (pulse) {
        String dominant = 'GENERAL';
        double max = 0.0;
        pulse.forEach((k, v) { if (v > max) { max = v; dominant = k.toUpperCase(); } });
        final moodColor = AppColors.moodColors[dominant] ?? AppColors.deepIndigo;

        return Stack(
          children: [
             // Deep Gradient
            Container(color: AppColors.backgroundDark),
            
            // Pulsing Glow 1
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: moodColor.withValues(alpha: 0.15),
                ),
              ).animate(onPlay: (c) => c.repeat())
               .scale(duration: 10.seconds, begin: const Offset(1, 1), end: const Offset(1.5, 1.5), curve: Curves.easeInOut)
               .then()
               .scale(duration: 10.seconds, begin: const Offset(1.5, 1.5), end: const Offset(1, 1)),
            ),

            // Pulsing Glow 2
            Positioned(
              bottom: -150,
              left: -50,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyanAccent.withValues(alpha: 0.1),
                ),
              ).animate(onPlay: (c) => c.repeat())
               .scale(duration: 12.seconds, begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8), curve: Curves.easeInOut)
               .then()
               .scale(duration: 12.seconds, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)),
            ),
          ],
        );
      },
      loading: () => Container(color: AppColors.backgroundDark),
      error: (_, __) => Container(color: AppColors.backgroundDark),
    );
  }
}

class _MemoryConstellation extends StatelessWidget {
  final List<Map<String, dynamic>> memories;
  const _MemoryConstellation({required this.memories});

  @override
  Widget build(BuildContext context) {
    final filtered = memories.where((m) {
      final path = m['file_path'] as String? ?? '';
      final isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');
      return path.isNotEmpty && File(path).existsSync() && !isVideo;
    }).toList();

    return Stack(
      children: filtered.take(15).map((m) => _EtherealMemory(memory: m)).toList(),
    );
  }
}

class _EtherealMemory extends StatelessWidget {
  final Map<String, dynamic> memory;
  const _EtherealMemory({required this.memory});

  @override
  Widget build(BuildContext context) {
    final random = math.Random();
    final startX = 20.0 + random.nextDouble() * 280;
    final startY = 100.0 + random.nextDouble() * 500;
    final duration = 15 + random.nextInt(20);
    final size = 80.0 + random.nextInt(120);
    final path = memory['file_path'] as String;

    return Positioned(
      left: startX,
      top: startY,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.4),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: -10,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ).animate(onPlay: (c) => c.repeat())
       .moveY(begin: 0, end: -150, duration: duration.seconds, curve: Curves.easeInOutSine)
       .then()
       .moveY(begin: -150, end: 0, duration: duration.seconds, curve: Curves.easeInOutSine)
       .animate(onPlay: (c) => c.repeat())
       .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: (duration/2).seconds, curve: Curves.easeInOutSine)
       .then()
       .scale(begin: const Offset(1.1, 1.1), end: const Offset(0.9, 0.9), duration: (duration/2).seconds, curve: Curves.easeInOutSine)
       .animate()
       .fadeIn(duration: 2.seconds),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'The reflection is quiet today.\nGather more memories to see them drift.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white24, fontSize: 14),
      ),
    );
  }
}
