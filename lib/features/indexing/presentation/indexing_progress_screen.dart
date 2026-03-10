import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/indexing_service.dart';

class IndexingProgressScreen extends ConsumerStatefulWidget {
  const IndexingProgressScreen({super.key});

  @override
  ConsumerState<IndexingProgressScreen> createState() => _IndexingProgressScreenState();
}

class _IndexingProgressScreenState extends ConsumerState<IndexingProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(indexingServiceProvider).startIndexing();
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusStream = ref.watch(indexingServiceProvider).indexingStatus;

    return StreamBuilder<Map<String, dynamic>>(
      stream: statusStream,
      initialData: const {'message': 'Initializing...', 'progress': 0.0},
      builder: (context, snapshot) {
        final data = snapshot.data!;
        final double progress = data['progress'] ?? 0.0;
        final String message = data['message'] ?? 'Processing...';
        
        if (progress >= 1.0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             context.go('/home');
          });
        } else if (message == 'Permissions required') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             context.go('/permissions');
          });
        }

        _StageData stage = _getStage(progress);

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double screenHeight = constraints.maxHeight;
                final double topPadding = screenHeight * 0.1; // Responsive top padding
                final double ringSize = (screenHeight * 0.3).clamp(180.0, 240.0);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      SizedBox(height: topPadding),
                      
                      // Playful Progress Ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: SizedBox(
                              width: ringSize,
                              height: ringSize,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 10,
                                backgroundColor: AppColors.backgroundElevated,
                                color: stage.color,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                          ),
                          
                          AnimatedSwitcher(
                            duration: 800.ms,
                            child: Container(
                              key: ValueKey(stage.icon),
                              padding: EdgeInsets.all(ringSize * 0.15),
                              decoration: BoxDecoration(
                                color: stage.color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                stage.icon,
                                size: ringSize * 0.35,
                                color: stage.color,
                              ),
                            ),
                          ).animate(onPlay: (c) => c.repeat(reverse: true))
                            .move(begin: const Offset(0, -5), end: const Offset(0, 5), duration: 1.5.seconds, curve: Curves.easeInOut),
                        ],
                      ),
                      
                      SizedBox(height: screenHeight * 0.05),
                      
                      // Text Content
                      AnimatedSwitcher(
                        duration: 500.ms,
                        child: Column(
                          key: ValueKey(message),
                          children: [
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: (screenHeight * 0.03).clamp(18.0, 24.0),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              progress < 0.3 ? 'Prioritizing screenshots and docs' : 'Finishing in the background...',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: (screenHeight * 0.02).clamp(12.0, 16.0),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),
                      
                      // Progress Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final bool isPast = progress >= (index / 4);
                          return AnimatedContainer(
                            duration: 400.ms,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isPast ? 12 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isPast ? stage.color : AppColors.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 24),
                      
                      // Status Tracking Info
                      if (progress > 0.2 && progress < 1.0)
                        TextButton(
                          onPressed: () => context.go('/home'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Search ready • Finishing up...',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: (screenHeight * 0.016).clamp(12.0, 14.0),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 14),
                            ],
                          ),
                        ).animate().fadeIn()
                      else
                        Text(
                          '${(progress * 100).toInt()}% indexed',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ).animate().fadeIn(),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  _StageData _getStage(double progress) {
    if (progress < 0.3) {
      return _StageData(icon: Icons.auto_awesome_rounded, color: Colors.indigoAccent);
    } else if (progress < 0.6) {
      return _StageData(icon: Icons.document_scanner_rounded, color: Colors.cyanAccent.shade700);
    } else {
      return _StageData(icon: Icons.memory_rounded, color: Colors.deepPurpleAccent);
    }
  }
}

class _StageData {
  final IconData icon;
  final Color color;

  _StageData({required this.icon, required this.color});
}
