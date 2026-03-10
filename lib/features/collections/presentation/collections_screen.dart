import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../home/providers/home_providers.dart' as hp;
import '../../search/providers/search_providers.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucketCountsAsync = ref.watch(hp.bucketCountsProvider);
    final totalCountAsync = ref.watch(hp.memoryCountProvider);

    final systemBuckets = [
      _BucketMeta(
        key: 'SCREENSHOTS',
        title: 'Screenshots',
        icon: Icons.smartphone_rounded,
        color: const Color(0xFF5C6BC0),
      ),
      _BucketMeta(
        key: 'DOCUMENTS',
        title: 'Documents',
        icon: Icons.description_rounded,
        color: const Color(0xFF00897B),
      ),
      _BucketMeta(
        key: 'PHOTOS',
        title: 'Photos',
        icon: Icons.photo_library_rounded,
        color: const Color(0xFFF57C00),
      ),
      _BucketMeta(
        key: 'DOWNLOADS',
        title: 'Downloads',
        icon: Icons.download_rounded,
        color: const Color(0xFF7B1FA2),
      ),
      _BucketMeta(
        key: 'RECEIPTS',
        title: 'Receipts',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF388E3C),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.backgroundLight,
            elevation: 0,
            centerTitle: false,
            title: const GradientText(
              'Collections',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Summary row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: totalCountAsync.when(
                data: (count) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.primaryShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$count memories mapped',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Text(
                              'Browsing your life archive',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
              ),
            ).animate().fadeIn(delay: 100.ms),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Section header
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Text(
                'BY SOURCE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Bucket grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: bucketCountsAsync.when(
              data: (counts) => SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final bucket = systemBuckets[index];
                    final count = counts[bucket.key] ?? 0;
                    return _CollectionCard(
                      title: bucket.title,
                      icon: bucket.icon,
                      count: count,
                      color: bucket.color,
                      onTap: () => _navigateToSearch(context, ref, bucket.key),
                    ).animate().fadeIn(delay: Duration(milliseconds: 80 * index)).slideY(begin: 0.08);
                  },
                  childCount: systemBuckets.length,
                ),
              ),
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                )),
              ),
              error: (e, s) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  void _navigateToSearch(BuildContext context, WidgetRef ref, String bucket) {
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(activeBucketProvider.notifier).state = bucket;
    context.go('/home');
  }
}

class _BucketMeta {
  final String key;
  final String title;
  final IconData icon;
  final Color color;
  _BucketMeta({required this.key, required this.title, required this.icon, required this.color});
}

class _CollectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.title,
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              count == 0 ? 'Nothing yet' : '$count items',
              style: TextStyle(
                color: count == 0 ? AppColors.textTertiary : color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
