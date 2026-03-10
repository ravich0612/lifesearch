import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../home/providers/home_providers.dart' as hp;
import '../../../core/services/memory_trigger_engine.dart';
import '../../../core/services/life_timeline_engine.dart';
import '../../../core/services/indexing_service.dart';

// Provider for full dev stats
final developerStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dbService = ref.read(hp.databaseServiceProvider);
  final db = await dbService.database;

  final memories   = await db.rawQuery('SELECT COUNT(*) as count FROM memory_items');
  final fts        = await db.rawQuery('SELECT COUNT(*) as count FROM memory_items_fts');
  final queues     = await db.rawQuery('SELECT COUNT(*) as count FROM processing_queue');
  final triggers   = await db.rawQuery('SELECT COUNT(*) as count FROM memory_triggers');
  final timelines  = await db.rawQuery('SELECT COUNT(*) as count FROM timeline_events');
  final ocrDone    = await db.rawQuery('SELECT COUNT(*) as count FROM memory_items WHERE is_ocr_complete = 1');
  final buckets    = await db.rawQuery('SELECT source_bucket, COUNT(*) as cnt FROM memory_items GROUP BY source_bucket ORDER BY cnt DESC');
  final queueByStatus = await db.rawQuery('SELECT task_type, status, COUNT(*) as cnt FROM processing_queue GROUP BY task_type, status ORDER BY cnt DESC');
  final recentTimelines = await db.rawQuery('SELECT id, title, event_type, item_count, start_time FROM timeline_events ORDER BY start_time DESC LIMIT 5');
  final recentTriggers  = await db.rawQuery('SELECT trigger_type, is_dismissed, is_accepted, COUNT(*) as cnt FROM memory_triggers GROUP BY trigger_type, is_dismissed, is_accepted');
  final recentItems = await db.rawQuery('SELECT id, source_bucket, title, is_ocr_complete FROM memory_items ORDER BY created_at DESC LIMIT 5');
  final recentFts   = await db.rawQuery('SELECT title, content FROM memory_items_fts ORDER BY rowid DESC LIMIT 10');
  final avgConf = await db.rawQuery('SELECT AVG(confidence_score) as avg FROM memory_items');

  return {
    'counts': {
      'memories': memories.first['count'],
      'fts_entries': fts.first['count'],
      'queue': queues.first['count'],
      'triggers': triggers.first['count'],
      'timelines': timelines.first['count'],
      'ocr_done': ocrDone.first['count'],
    },
    'avg_confidence': avgConf.first['avg'],
    'buckets': buckets,
    'queue_by_status': queueByStatus,
    'recent_timelines': recentTimelines,
    'trigger_summary': recentTriggers,
    'recent_items': recentItems,
    'recent_fts': recentFts,
  };
});

class DeveloperToolsScreen extends ConsumerStatefulWidget {
  const DeveloperToolsScreen({super.key});

  @override
  ConsumerState<DeveloperToolsScreen> createState() => _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends ConsumerState<DeveloperToolsScreen> {
  bool _runningTriggers = false;
  bool _runningTimeline = false;
  bool _runningLabeling = false;
  String? _lastActionMessage;

  Future<void> _runVisualReindex() async {
    setState(() { _runningLabeling = true; _lastActionMessage = null; });
    final dbService = ref.read(hp.databaseServiceProvider);
    final count = await dbService.requeueAllPhotosForLabeling();
    
    // Kick off the background processing for the new queue items
    ref.read(indexingServiceProvider).startIndexing();
    
    if (mounted) {
      setState(() {
        _runningLabeling = false;
        _lastActionMessage = '✅ Visual re-index queued: $count photos added';
      });
      ref.invalidate(developerStatsProvider);
      ref.invalidate(hp.indexingProgressProvider);
    }
  }

  Future<void> _runTriggerBackfill() async {
    setState(() { _runningTriggers = true; _lastActionMessage = null; });
    final engine = MemoryTriggerEngine();
    final count = await engine.reprocessAllItems();
    if (mounted) {
      setState(() {
        _runningTriggers = false;
        _lastActionMessage = '✅ Trigger backfill done: $count items processed';
      });
      ref.invalidate(developerStatsProvider);
    }
  }

  Future<void> _runTimelineRebuild() async {
    setState(() { _runningTimeline = true; _lastActionMessage = null; });
    final engine = LifeTimelineEngine();
    await engine.processRecentItemsForTimeline();
    if (mounted) {
      setState(() {
        _runningTimeline = false;
        _lastActionMessage = '✅ Timeline rebuilt successfully';
      });
      ref.invalidate(developerStatsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(developerStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const GradientText('Dev Tools', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.backgroundLight,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(developerStatsProvider),
            tooltip: 'Refresh stats',
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {
          final counts = stats['counts'] as Map<String, dynamic>;
          final buckets = stats['buckets'] as List<Map<String, dynamic>>;
          final queueStatus = stats['queue_by_status'] as List<Map<String, dynamic>>;
          final timelines = stats['recent_timelines'] as List<Map<String, dynamic>>;
          final triggerSummary = stats['trigger_summary'] as List<Map<String, dynamic>>;
          final recentItems = stats['recent_items'] as List<Map<String, dynamic>>;
          final avgConf = (stats['avg_confidence'] as double?) ?? 0.0;

          final ocrDone = counts['ocr_done'] as int;
          final total   = counts['memories'] as int;
          final ocrPct  = total > 0 ? (ocrDone / total * 100).toStringAsFixed(1) : '0';

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
            children: [

              if (_lastActionMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.deepIndigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_lastActionMessage!, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.deepIndigo)),
                ),
              ],

              // ── ACTIONS ─────────────────────────────────────────────
              _SectionHeader('⚡ Actions'),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: _runningTriggers ? 'Running...' : 'Run Trigger Backfill',
                      icon: Icons.auto_awesome_rounded,
                      isLoading: _runningTriggers,
                      color: const Color(0xFF5C6BC0),
                      onTap: _runningTriggers ? null : _runTriggerBackfill,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: _runningTimeline ? 'Running...' : 'Rebuild Timeline',
                      icon: Icons.timeline_rounded,
                      isLoading: _runningTimeline,
                      color: const Color(0xFF00897B),
                      onTap: _runningTimeline ? null : _runTimelineRebuild,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ActionButton(
                label: _runningLabeling ? 'Running...' : 'Run Visual Re-index (for Beach/Objects)',
                icon: Icons.visibility_rounded,
                isLoading: _runningLabeling,
                color: const Color(0xFF673AB7),
                onTap: _runningLabeling ? null : _runVisualReindex,
              ),
              const SizedBox(height: 24),

              // ── TABLE COUNTS ─────────────────────────────────────────
              _SectionHeader('📊 Table Counts'),
              _StatRow('Total Memories',  '${counts['memories']}'),
              _StatRow('FTS Entries',     '${counts['fts_entries']}'),
              _StatRow('OCR Complete',    '$ocrDone / $total ($ocrPct%)', accent: ocrPct == '100.0'),
              _StatRow('Queue Tasks',     '${counts['queue']}'),
              _StatRow('Triggers',        '${counts['triggers']}', highlight: (counts['triggers'] as int) == 0),
              _StatRow('Timeline Events', '${counts['timelines']}'),
              _StatRow('Avg Confidence',  avgConf.toStringAsFixed(3)),
              const SizedBox(height: 24),

              // ── BUCKETS ──────────────────────────────────────────────
              _SectionHeader('🗂️ Source Buckets'),
              ...buckets.map((b) => _StatRow('${b['source_bucket']}', '${b['cnt']}')),
              const SizedBox(height: 24),

              // ── QUEUE STATUS ─────────────────────────────────────────
              _SectionHeader('⏳ Queue by Status'),
              if (queueStatus.isEmpty)
                const Text('Queue is empty', style: TextStyle(color: AppColors.textTertiary))
              else
                ...queueStatus.map((q) => _StatRow('${q['task_type']} / ${q['status']}', '${q['cnt']}')),
              const SizedBox(height: 24),

              // ── TRIGGERS ─────────────────────────────────────────────
              _SectionHeader('🎯 Memory Triggers'),
              if (triggerSummary.isEmpty)
                const Text('No triggers found yet — run backfill above', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500))
              else
                ...triggerSummary.map((t) => _StatRow(
                  '${t['trigger_type']}',
                  '${t['cnt']} (dismissed=${t['is_dismissed']}, accepted=${t['is_accepted']})',
                )),
              const SizedBox(height: 24),

              // ── TIMELINE EVENTS ──────────────────────────────────────
              _SectionHeader('📅 Recent Timeline Events'),
              if (timelines.isEmpty)
                const Text('No timeline events yet', style: TextStyle(color: AppColors.textTertiary))
              else
                ...timelines.map((e) {
                  final ts = (e['start_time'] as int?) ?? 0;
                  final dateStr = ts > 0 ? DateFormat('MMM d, HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts)) : '?';
                  return _DevCard('[$dateStr] ${e['title']} (${e['event_type']}, ${e['item_count']} items)');
                }),
              const SizedBox(height: 24),

              // ── RECENT ITEMS ─────────────────────────────────────────
              _SectionHeader('🕐 Recently Indexed Items'),
              ...recentItems.map((item) => _DevCard(
                '[${item['source_bucket']}] ${item['title']}\nocr=${item['is_ocr_complete']}',
              )),
              const SizedBox(height: 24),

              // ── DEEP SEARCH SAMPLES ──────────────────────────────────
              _SectionHeader('🧠 Deep Search Index (FTS)'),
              if ((stats['recent_fts'] as List).isEmpty)
                const Text('No text data indexed yet', style: TextStyle(color: Colors.red))
              else
                ...(stats['recent_fts'] as List).map((f) => _DevCard(
                  '${f['title']}\nTEXT: ${(f['content']?.toString() ?? '').split('\n').take(3).join(' ')}...',
                )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepIndigo)),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool accent;

  const _StatRow(this.label, this.value, {this.highlight = false, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: highlight
                  ? Colors.orange.withValues(alpha: 0.12)
                  : accent
                      ? Colors.green.withValues(alpha: 0.12)
                      : AppColors.deepIndigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: highlight ? Colors.orange : accent ? Colors.green : AppColors.deepIndigo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevCard extends StatelessWidget {
  final String text;
  const _DevCard(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
            else
              Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
