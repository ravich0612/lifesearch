import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'package:intl/intl.dart';

class LifeTimelineEngine {
  final DatabaseService _db = DatabaseService();

  /// Processes indexed items to group them into meaningful life events.
  /// Improved with OCR text analysis for better naming.
  Future<void> processRecentItemsForTimeline({bool clearFirst = false}) async {
    try {
      final db = await _db.database;
      
      if (clearFirst) {
        await db.delete('timeline_events');
        await db.delete('timeline_event_items');
      }

      // Get all indexed items for clustering (limit to 1000 for performance)
      final results = await db.query(
        'memory_items',
        where: 'is_indexed = 1',
        orderBy: 'created_at DESC',
        limit: 1000,
      );
      
      if (results.isEmpty) return;
      
      // Basic grouping algorithm: Time proximity (e.g., within 5 hours)
      final maxProximityMs = 5 * 60 * 60 * 1000; 

      List<List<Map<String, dynamic>>> clusters = [];
      
      int clusterYieldCount = 0;
      for (final item in results) {
        final createdAt = item['created_at'] as int?;
        if (createdAt == null) continue;
        
        bool clustered = false;
        for (var cluster in clusters) {
          final clusterFirstTime = cluster.first['created_at'] as int;
          if ((createdAt - clusterFirstTime).abs() <= maxProximityMs) {
            cluster.add(item);
            clustered = true;
            break;
          }
        }
        
        if (!clustered) {
          clusters.add([item]);
        }

        // Yield every 50 items during group creation
        clusterYieldCount++;
        if (clusterYieldCount % 50 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      // Process clusters into events
      for (final cluster in clusters) {
        // Yield for every cluster as _analyzeCluster has its own DB queries
        await Future.delayed(const Duration(milliseconds: 5));
        
        // Only form events for groups of items (noise filter)
        // Except for high-value items like documents or explicit screenshots
        bool isHighValue = cluster.any((e) => e['source_bucket'] == 'DOCUMENTS' || e['source_bucket'] == 'RECEIPTS');
        if (cluster.length < 3 && !isHighValue) continue;
        
        final startTime = cluster.map((e) => e['created_at'] as int).reduce((a, b) => a < b ? a : b);
        final endTime = cluster.map((e) => e['created_at'] as int).reduce((a, b) => a > b ? a : b);
        
        // Skip if already exists
        if (!clearFirst) {
          final exists = await _db.doesEventExistByTimeRange(startTime, endTime);
          if (exists) continue;
        }

        // Deep analysis for naming
        final eventInfo = await _analyzeCluster(cluster);
        
        final eventId = 'event_${startTime}_${cluster.length}';
        
        await _db.insertTimelineEvent({
          'id': eventId,
          'title': eventInfo.title,
          'event_type': eventInfo.type,
          'start_time': startTime,
          'end_time': endTime,
          'location_lat': 0.0,
          'location_lng': 0.0,
          'preview_image': eventInfo.previewPath,
          'item_count': cluster.length,
          'confidence_score': 0.85,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        }, cluster.map((e) => e['id'] as String).toList());
      }
      
    } catch (e) {
      debugPrint('LifeTimelineEngine processing error: $e');
    }
  }

  Future<_ClusterInfo> _analyzeCluster(List<Map<String, dynamic>> cluster) async {
    final db = await _db.database;
    
    // Aggregate text from FTS for all items in cluster
    StringBuffer clusterText = StringBuffer();
    for (var item in cluster) {
      final fts = await db.query(
        'memory_items_fts', 
        where: 'memory_item_id = ?', 
        whereArgs: [item['id']],
        columns: ['content']
      );
      // Yield to keep the UI smooth during deep cluster analysis
      await Future.delayed(Duration.zero);
      if (fts.isNotEmpty) {
        clusterText.write(' ${fts.first['content'] ?? ''}');
      }
      clusterText.write(' ${item['title'] ?? ''}');
    }
    
    final text = clusterText.toString().toLowerCase();
    final bucketCount = <String, int>{};
    for (var item in cluster) {
      final b = item['source_bucket'] as String? ?? 'PHOTOS';
      bucketCount[b] = (bucketCount[b] ?? 0) + 1;
    }

    String title = 'Memory Collection';
    String type = 'GENERAL';

    // Heuristics
    if (text.contains('flight') || text.contains('boarding') || text.contains('ticket')) {
      title = 'Travel Trip';
      type = 'TRAVEL';
    } else if (text.contains('restaurant') || text.contains('dinner') || text.contains('lunch') || text.contains('menu')) {
      title = 'Dining Out';
      type = 'DINING';
    } else if (bucketCount['RECEIPTS'] != null && bucketCount['RECEIPTS']! >= 1) {
      title = 'Shopping & Expenses';
      type = 'SHOPPING';
    } else if (text.contains('social security') || text.contains('passport') || text.contains('identity')) {
      title = 'Document Organization';
      type = 'DOCUMENTS';
    } else if (text.contains('parking') || text.contains('garage') || text.contains('level')) {
      title = 'Parking & Outing';
      type = 'OUTING';
    } else if (bucketCount['SCREENSHOTS'] != null && bucketCount['SCREENSHOTS']! > cluster.length / 2) {
      title = 'Screen Browsing';
      type = 'WORK';
    }

    // Attempt to extract a more specific title if possible
    if (type == 'DINING' && text.contains('menu')) {
       // Future: logic to extract restaurant name
    }

    // Use a pretty date if it's a general collection
    if (title == 'Memory Collection') {
      final date = DateTime.fromMillisecondsSinceEpoch(cluster.first['created_at'] as int);
      title = 'Memories from ${DateFormat('MMMM d').format(date)}';
    }

    // Select preview image
    String preview = '';
    for (var item in cluster) {
      final path = item['file_path'] as String? ?? '';
      if (path.isNotEmpty) {
        preview = path;
        // Prefer photos over screenshots for previews
        if (item['source_bucket'] == 'PHOTOS') break;
      }
    }

    return _ClusterInfo(title, type, preview);
  }
}

class _ClusterInfo {
  final String title;
  final String type;
  final String previewPath;
  _ClusterInfo(this.title, this.type, this.previewPath);
}
