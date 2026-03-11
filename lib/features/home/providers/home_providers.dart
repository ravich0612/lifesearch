import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/file_utils.dart';

final databaseServiceProvider = Provider((ref) => DatabaseService());

final recentMemoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getRecentMemories(limit: 20);
});

final memoryCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final database = await db.database;
  final result = await database.rawQuery('SELECT COUNT(*) as count FROM memory_items');
  return (result.first['count'] as int?) ?? 0;
});

final bucketCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final database = await db.database;
  final results = await database.rawQuery(
    'SELECT source_bucket, COUNT(*) as count FROM memory_items GROUP BY source_bucket'
  );
  
  Map<String, int> counts = {};
  for (var row in results) {
    counts[row['source_bucket'] as String] = row['count'] as int;
  }
  return counts;
});

final bucketPreviewsProvider = FutureProvider<Map<String, String?>>((ref) async {
  final dbService = ref.read(databaseServiceProvider);
  final db = await dbService.database;
  final buckets = ['SCREENSHOTS', 'DOCUMENTS', 'PHOTOS', 'RECEIPTS', 'GALLERY'];
  
  Map<String, String?> previews = {};
  for (var bucket in buckets) {
    final results = await db.query(
      'memory_items',
      columns: ['file_path', 'mime_type'],
      where: 'source_bucket = ?',
      whereArgs: [bucket],
      orderBy: 'created_at DESC',
      limit: 50, // Grab a batch to find an image in
    );
    
    String? validImage;
    for (var row in results) {
      final path = row['file_path'] as String?;
      final mime = row['mime_type'] as String?;
      if (path != null && FileUtils.canBeLoadedAsImage(path, mime)) {
        validImage = path;
        break;
      }
    }
    previews[bucket] = validImage;
  }
  return previews;
});

final memoryByIdProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final dbService = ref.read(databaseServiceProvider);
  final db = await dbService.database;
  
  final results = await db.rawQuery('''
    SELECT m.*, f.content FROM memory_items m
    LEFT JOIN memory_items_fts f ON m.id = f.memory_item_id
    WHERE m.id = ?
  ''', [id]);
  
  if (results.isEmpty) return null;
  return results.first;
});

final activeTriggersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getActiveTriggers(limit: 5);
});

final flashbackMemoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dbService = ref.read(databaseServiceProvider);
  final db = await dbService.database;
  
  // Find memories from exactly 1, 2, 3 or 5 years ago today
  final now = DateTime.now();
  final targetYears = [1, 2, 3, 5];
  List<Map<String, dynamic>> flashbacks = [];
  
  for (var year in targetYears) {
    final targetDate = DateTime(now.year - year, now.month, now.day);
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + (24 * 60 * 60 * 1000);
    
    final results = await db.query(
      'memory_items',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
      limit: 20,
    );
    
    for (var row in results) {
       final path = row['file_path'] as String?;
       final mime = row['mime_type'] as String?;
       if (path != null && FileUtils.canBeLoadedAsImage(path, mime)) {
         flashbacks.add({...row, 'flashback_years': year});
         break; // Found one for this year
       }
    }
  }
  return flashbacks;
});

final relatedMemoriesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memoryId) async {
  final dbService = ref.read(databaseServiceProvider);
  return await dbService.getRelatedMemories(memoryId);
});

final lifePulseProvider = FutureProvider<Map<String, double>>((ref) async {
  final dbService = ref.read(databaseServiceProvider);
  return await dbService.getLifePulse();
});

/// Real-time indexing progress stats — queries the DB directly so it reflects
/// what's actually been analyzed, not just what the stream reports.
final indexingProgressProvider = FutureProvider<IndexingProgress>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  final database = await db.database;

  final totalResult = await database.rawQuery('SELECT COUNT(*) as c FROM memory_items');
  final total = (totalResult.first['c'] as int?) ?? 0;

  final ocrResult = await database.rawQuery(
    'SELECT COUNT(*) as c FROM memory_items WHERE is_ocr_complete = 1'
  );
  final ocrDone = (ocrResult.first['c'] as int?) ?? 0;

  final queueResult = await database.rawQuery(
    "SELECT COUNT(*) as c FROM processing_queue WHERE status = 'QUEUED'"
  );
  final queued = (queueResult.first['c'] as int?) ?? 0;

  final triggerResult = await database.rawQuery('SELECT COUNT(*) as c FROM memory_triggers');
  final triggers = (triggerResult.first['c'] as int?) ?? 0;

  final ftsResult = await database.rawQuery(
    "SELECT COUNT(*) as c FROM memory_items_fts WHERE content IS NOT NULL AND LENGTH(content) > 20"
  );
  final withText = (ftsResult.first['c'] as int?) ?? 0;

  // We estimate total work as total memories * 2 (OCR + LABEL)
  final totalWork = total * 2;
  // Completed work is ocrDone + (total - queued/2 approx) 
  // For simplicity, let's just use the inverse of the queue
  final completedWork = (totalWork - queued).clamp(0, totalWork);

  return IndexingProgress(
    total: total,
    ocrDone: ocrDone,
    stillQueued: queued,
    triggers: triggers,
    withExtractedText: withText,
    totalWorkItems: totalWork,
    completedWorkItems: completedWork,
  );
});

class IndexingProgress {
  final int total;
  final int ocrDone;
  final int stillQueued;
  final int triggers;
  final int withExtractedText;
  final int totalWorkItems;
  final int completedWorkItems;

  const IndexingProgress({
    required this.total,
    required this.ocrDone,
    required this.stillQueued,
    required this.triggers,
    required this.withExtractedText,
    required this.totalWorkItems,
    required this.completedWorkItems,
  });

  double get progressPercent => totalWorkItems > 0 ? completedWorkItems / totalWorkItems : 0.0;
  bool get isComplete => stillQueued == 0 && total > 0;
  int get pending => stillQueued;
}
