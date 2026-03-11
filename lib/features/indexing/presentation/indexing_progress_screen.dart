import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
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
      initialData: const {'message': 'Initializing...', 'progress': 0.0, 'fact': 'Igniting neural pathways...'},
      builder: (context, snapshot) {
        final data = snapshot.data!;
        final double progress = data['progress'] ?? 0.0;
        final String message = data['message'] ?? 'Processing...';
        final String fact = data['fact'] ?? 'Constructing your second brain...';
        
        if (progress >= 1.0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             context.go('/home');
          });
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // 1. Cinematic Nebula Background
              const _NebulaBackground(),
              
              const _EnergyParticles(),

              // 2. The Main Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      
                      // The Central Core (The "Brain" forming)
                      _FormationCore(progress: progress),
                      
                      const Spacer(),
                      
                      // Status Text
                      Column(
                        children: [
                          Text(
                            'GENESIS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8,
                            ),
                          ).animate().fadeIn().slideY(begin: 0.2),
                          const SizedBox(height: 16),
                          Text(
                            message.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ).animate(key: ValueKey(message))
                            .fadeIn(duration: 600.ms)
                            .scale(begin: const Offset(0.95, 0.95)),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: 800.ms,
                            child: Text(
                              fact,
                              key: ValueKey(fact),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Progress Bar (Premium Thin Style)
                      Column(
                        children: [
                          Container(
                            height: 4,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress.clamp(0.01, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7B66FF), Color(0xFF00D2FF)],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7B66FF).withValues(alpha: 0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${(progress * 100).toInt()}% READY',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      
                      const Spacer(),

                      // Background indexing CTA
                      TextButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('background_indexing_enabled', true);
                          if (mounted) context.go('/home');
                        },
                        child: Column(
                          children: [
                            Text(
                              'NOTIFY ME WHEN DONE',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 1,
                              width: 40,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 2.seconds),
                      
                      const SizedBox(height: 40),
                      
                      Text(
                        'This is a one-time synthesis.\nYour memories stay private and on-device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FormationCore extends StatefulWidget {
  final double progress;
  const _FormationCore({required this.progress});

  @override
  State<_FormationCore> createState() => _FormationCoreState();
}

class _FormationCoreState extends State<_FormationCore> with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing Core with Lottie
        SizedBox(
          width: 300,
          height: 300,
          child: Lottie.asset(
            'assets/animations/Global.json',
            fit: BoxFit.contain,
          ),
        ),
          
        // Rotating Orbitals using native Ticker for maximum smoothness under load
        AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationController.value * 2 * 3.14159,
              child: CustomPaint(
                size: const Size(260, 260),
                painter: _OrbitalPainter(
                  progress: widget.progress,
                  rotation: _rotationController.value,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _OrbitalPainter extends CustomPainter {
  final double progress;
  final double rotation;
  _OrbitalPainter({required this.progress, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final orbitPaint = Paint()
      ..color = const Color(0xFF00D2FF).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    canvas.drawCircle(center, radius, orbitPaint);
    
    // Draw "Memory Particle" on the orbit
    // We draw it at the end of the orbit (at width, height/2) 
    // because the entire canvas is already being rotated by the Transform.rotate widget
    final dotPaint = Paint()
      ..color = const Color(0xFF00D2FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(Offset(size.width, size.height / 2), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitalPainter oldDelegate) => 
      oldDelegate.rotation != rotation;
}

class _NebulaBackground extends StatelessWidget {
  const _NebulaBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: Colors.black),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7B66FF).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .move(duration: 10.seconds, begin: const Offset(0, 0), end: const Offset(-50, 50)),
            
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D2FF).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .move(duration: 8.seconds, begin: const Offset(0, 0), end: const Offset(40, -40)),
        ],
      ),
    );
  }
}

class _EnergyParticles extends StatelessWidget {
  const _EnergyParticles();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: List.generate(20, (i) {
            final x = (i * 17) % 100 / 100.0;
            final y = (i * 23) % 100 / 100.0;
            final size = (i % 3 + 1).toDouble();

            return Positioned(
              left: MediaQuery.of(context).size.width * x,
              top: MediaQuery.of(context).size.height * y,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ).animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 2.seconds)
                .then()
                .fadeOut(duration: 2.seconds)
                .scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 2.seconds),
            );
          }),
        ),
      ),
    );
  }
}
