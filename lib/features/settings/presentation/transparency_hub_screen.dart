import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/nebula_background.dart';

class TransparencyHubScreen extends ConsumerWidget {
  const TransparencyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: NebulaBackground()),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainPrivacyCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('NEURAL METRICS'),
                        const SizedBox(height: 12),
                        _buildMetricRow(
                          icon: Icons.psychology_outlined,
                          label: 'AI computations total',
                          value: '14,208',
                          subtitle: 'All processed locally on your Neural Engine',
                        ),
                        _buildMetricRow(
                          icon: Icons.cloud_off_rounded,
                          label: 'Data leaked to cloud',
                          value: '0 bytes',
                          subtitle: 'Strict zero-server policy enforced',
                          highlight: true,
                        ),
                        _buildMetricRow(
                          icon: Icons.security_rounded,
                          label: 'Encryption standard',
                          value: 'AES-256',
                          subtitle: 'Military-grade on-device storage',
                        ),
                        const SizedBox(height: 32),
                        _buildActionCard(
                          title: 'Export My Neural Profile',
                          description: 'Take your conceptual understanding data with you.',
                          icon: Icons.download_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildActionCard(
                          title: 'Nuclear Reset',
                          description: 'Wipe all local indices and AI models instantly.',
                          icon: Icons.delete_forever_rounded,
                          isDangerous: true,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => context.pop(),
      ),
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'Transparency Hub',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMainPrivacyCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepIndigo.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.green, size: 40),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: 2.seconds,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 20),
          const Text(
            'Your Mind is Yours',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'LifeSearch is built on a foundation of Absolute Privacy. Every OCR scan, Every conceptual embedding, and Every search happens exclusively in this device\'s secure memory.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: AppColors.textTertiary,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (highlight ? Colors.green : AppColors.deepIndigo).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: highlight ? Colors.green : AppColors.deepIndigo, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: highlight ? Colors.green : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    bool isDangerous = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDangerous ? Colors.red.shade50.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDangerous ? Colors.red.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDangerous ? Colors.red : AppColors.deepIndigo),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDangerous ? Colors.red : AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
