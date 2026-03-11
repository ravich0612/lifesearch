import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/home_providers.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import '../../../core/utils/file_utils.dart';

class ResultDetailScreen extends ConsumerWidget {
  final String itemId;
  const ResultDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoryAsync = ref.watch(memoryByIdProvider(itemId));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.backgroundLight,
            flexibleSpace: FlexibleSpaceBar(
              background: memoryAsync.when(
                data: (memory) {
                   if (memory == null) return Container(color: AppColors.backgroundElevated);
                   final path = memory['file_path'] ?? '';
                   final mime = memory['mime_type'] ?? '';
                   if (!File(path).existsSync()) return Container(color: AppColors.backgroundElevated);


                   final pathLower = path.toLowerCase();
                   final isWordDoc = mime.contains('word') || mime.contains('officedocument') || pathLower.endsWith('.docx') || pathLower.endsWith('.doc');
                   final isPdf = mime.contains('pdf') || pathLower.endsWith('.pdf');
                   final isSpreadsheet = mime.contains('spreadsheet') || mime.contains('csv') || pathLower.endsWith('.xlsx') || pathLower.endsWith('.xls') || pathLower.endsWith('.csv');
                   final isText = mime.contains('text') || pathLower.endsWith('.txt') || pathLower.endsWith('.rtf');

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
                       child: Center(
                         child: Icon(icon, color: color, size: 100),
                       ),
                     );
                   }
                   
                   if (FileUtils.isVideo(path) || mime.startsWith('video/')) {
                     return Container(
                       color: AppColors.backgroundDark.withValues(alpha: 0.1),
                       child: const Center(
                         child: Stack(
                           alignment: Alignment.center,
                           children: [
                             Icon(Icons.videocam_rounded, color: AppColors.textTertiary, size: 80),
                             Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64),
                           ],
                         ),
                       ),
                     );
                   }
                   
                   return Image.file(File(path), fit: BoxFit.cover);
                },
                loading: () => Container(color: AppColors.backgroundElevated),
                error: (err, stack) => Container(color: AppColors.backgroundElevated),
              ),
            ),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border_rounded)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.share_rounded)),
            ],
          ),
          memoryAsync.when(
            data: (memory) {
              if (memory == null) {
                return const SliverFillRemaining(
                  child: Center(child: Text('Memory not found.')),
                );
              }

              final String path = memory['file_path'] ?? '';
              final String content = memory['content'] ?? '';
              final String labels = memory['labels'] as String? ?? '';
              final DateTime date = DateTime.fromMillisecondsSinceEpoch(memory['created_at'] ?? 0);
              final relatedAsync = ref.watch(relatedMemoriesProvider(itemId));

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.deepIndigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              memory['source_bucket'] ?? 'GALLERY',
                              style: const TextStyle(color: AppColors.deepIndigo, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(DateFormat.yMMMd().add_jm().format(date), style: const TextStyle(color: AppColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ).animate().fadeIn(),
                      const SizedBox(height: 16),
                      Text(
                        memory['title'] ?? path.split('/').last,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                      ).animate().fadeIn(delay: 100.ms),
                      
                      if (labels.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _DetailSection(
                          title: 'Visual Context',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: labels.split(',').where((l) => l.isNotEmpty).map((label) => 
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.deepIndigo.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.deepIndigo.withValues(alpha: 0.1)),
                                ),
                                child: Text(
                                  label.trim().toUpperCase(),
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.deepIndigo, letterSpacing: 0.5),
                                ),
                              ),
                            ).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      _DetailSection(
                        title: 'Semantic Discovery',
                        child: relatedAsync.when(
                          data: (related) => related.isEmpty 
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppColors.backgroundElevated, borderRadius: BorderRadius.circular(16)),
                                child: const Text('No related memories found yet.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                              )
                            : SizedBox(
                                height: 120,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: related.length,
                                  separatorBuilder: (c, i) => const SizedBox(width: 12),
                                  itemBuilder: (c, i) {
                                    final rel = related[i];
                                    final relPath = rel['file_path'] as String? ?? '';
                                    return GestureDetector(
                                      onTap: () => Navigator.pushReplacement(
                                        context, 
                                        MaterialPageRoute(builder: (c) => ResultDetailScreen(itemId: rel['id']))
                                      ),
                                      child: Container(
                                        width: 100,
                                        decoration: BoxDecoration(
                                          color: AppColors.backgroundElevated,
                                          borderRadius: BorderRadius.circular(16),
                                          image: relPath.isNotEmpty && File(relPath).existsSync() 
                                            ? DecorationImage(image: FileImage(File(relPath)), fit: BoxFit.cover)
                                            : null,
                                        ),
                                        child: relPath.isEmpty || !File(relPath).existsSync()
                                          ? const Icon(Icons.history_rounded, color: AppColors.divider)
                                          : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, s) => const Text('Error loading related items'),
                        ),
                      ),

                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _DetailSection(
                          title: 'Detected Text',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: SelectableText(
                              content,
                              style: const TextStyle(height: 1.7, fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                      ],

                      const SizedBox(height: 32),
                      _DetailSection(
                        title: 'Operations',
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            children: [
                              _ActionTile(
                                icon: Icons.copy_rounded, 
                                title: 'Copy Content',
                                onTap: () async {
                                  await Clipboard.setData(ClipboardData(text: content));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Copied to clipboard')),
                                    );
                                  }
                                },
                              ),
                              const Divider(height: 1, indent: 56),
                              _ActionTile(
                                icon: Icons.share_rounded, 
                                title: 'Share Memory',
                                onTap: () async {
                                  if (path.isNotEmpty && File(path).existsSync()) {
                                    await Share.shareXFiles([XFile(path)], text: 'LifeSearch Memory');
                                  }
                                },
                              ),
                              const Divider(height: 1, indent: 56),
                              _ActionTile(
                                icon: Icons.open_in_new_rounded, 
                                title: 'Open Original',
                                onTap: () {
                                  if (path.isNotEmpty && File(path).existsSync()) {
                                    OpenFile.open(path);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.deepIndigo),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded),
      contentPadding: EdgeInsets.zero,
    );
  }
}
