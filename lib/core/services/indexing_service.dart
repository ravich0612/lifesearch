import 'package:photo_manager/photo_manager.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'database_service.dart';
import 'semantic_service.dart';
import 'memory_trigger_engine.dart';
import 'life_timeline_engine.dart';

import '../utils/file_utils.dart';
import 'notification_service.dart';
import '../../features/home/providers/home_providers.dart' show indexingProgressProvider;

final indexingServiceProvider = Provider((ref) => IndexingService(ref));

enum BucketType { screenshots, documents, photos, receipts, downloads }

class IndexingService {
  final Ref _ref;
  final DatabaseService _db = DatabaseService();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImageLabeler _imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.6));
  final MemoryTriggerEngine _triggerEngine = MemoryTriggerEngine();
  final LifeTimelineEngine _timelineEngine = LifeTimelineEngine();
  final SemanticService _semanticService = SemanticService();

  IndexingService(this._ref);
  
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get indexingStatus => _statusController.stream;

  bool _isProcessing = false;

  Future<void> startIndexing() async {
    if (_isProcessing) return;
    _isProcessing = true;
    
    // Initialize the neural brain
    await _semanticService.initialize();

    try {
      final PermissionState permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        _emitStatus('Permissions required', 0.0);
        _isProcessing = false;
        return;
      }

      // 1. FAST METADATA INDEXING (Layer 1)
      await _runPriorityPhase();
      
      // 2. FULL DISCOVERY (Layer 1 - Remainder)
      await _runDiscoveryPhase();
      
      // 3. FILE SYSTEM DISCOVERY (P2/P4)
      await _runFileSystemDiscovery();

      // 4. BACKGROUND DEEP PROCESSING (Layer 2, 3, 4)
      unawaited(_runBackgroundProcessing());
    } catch (e) {
      debugPrint('Indexing error: $e');
      _emitStatus('Indexing paused', 0.0, fact: 'Checking connection to your life ledger...');
    } finally {
      _isProcessing = false;
    }
  }

  final List<String> _discoveryFacts = [
    'Mapping neural connections...',
    'Building your digital sanctuary...',
    'Linking moments through time...',
    'Organizing a decade of thoughts...',
    'Securing your private memories...',
    'Synthesizing life patterns...',
    'Finding the beauty in your data...',
    'Creating your second brain...',
    'Indexing the colors of your past...',
    'Almost ready for reflection...',
  ];

  String get _randomFact => (List.from(_discoveryFacts)..shuffle()).first;

  Future<void> _runFileSystemDiscovery() async {
    _emitStatus('Scanning your storage...', 0.45);
    
    final List<String> pathsToScan = [];
    if (Platform.isAndroid) {
      // The user granted MANAGE_EXTERNAL_STORAGE, so we scan the root
      pathsToScan.add('/storage/emulated/0');
    }

    // Common system folders to skip for privacy and performance
    final excludedFolders = [
      'Android',
      'data',
      'obb',
      '.', // Hidden folders
      'cache',
    ];

    for (var path in pathsToScan) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          final List<FileSystemEntity> entities = dir.listSync(recursive: false);
          for (var entity in entities) {
            final name = p.basename(entity.path);
            if (excludedFolders.any((excluded) => name == excluded || name.startsWith('.'))) continue;
            
            if (entity is Directory) {
              await _scanDirectory(entity);
            } else if (entity is File) {
              await _tryIndexFile(entity);
            }
          }
        } catch (e) {
          debugPrint('Storage scan restricted for $path: $e');
        }
      }
    }
  }

  Future<void> _scanDirectory(Directory directory) async {
    try {
      final List<FileSystemEntity> entities = directory.listSync(recursive: true);
      for (var entity in entities) {
        if (entity is File) {
          await _tryIndexFile(entity);
        }
      }
    } catch (e) {
      // Quietly skip folders we can't access
    }
  }

  Future<void> _tryIndexFile(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    // High-value document extensions
    const docExtensions = ['.pdf', '.doc', '.docx', '.txt', '.rtf', '.xls', '.xlsx', '.csv'];
    const imgExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'];
    
    if (docExtensions.contains(ext)) {
      await _discoverFile(file, BucketType.documents);
    } else if (imgExtensions.contains(ext)) {
      // Catch older images that might not be in the media gallery database
      await _discoverFile(file, BucketType.photos);
    }
  }

  Future<void> _discoverFile(File file, BucketType bucket) async {
    final id = 'file_${file.path.hashCode}';
    final bool exists = await _db.isMemoryIndexed(id);

    // Basic Change Detection
    final stats = await file.stat();
    
    if (exists) return;

    final Map<String, dynamic> item = {
      'id': id,
      'source_type': 'FILE',
      'source_bucket': bucket.name.toUpperCase(),
      'source_id': file.path,
      'file_path': file.path,
      'mime_type': _getMimeType(file.path),
      'title': p.basename(file.path),
      'created_at': stats.changed.millisecondsSinceEpoch,
      'modified_at': stats.modified.millisecondsSinceEpoch,
      'size_bytes': stats.size,
      'is_indexed': 1,
      'confidence_score': 1.0, 
    };

    await _db.upsertMemoryItem(item);
    
    // Immediate title indexing for instant searchability
    await _db.updateFTS(id, '', p.basename(file.path), bucket.name.toUpperCase());

    // Queue for OCR if it's text-based
    await _db.addToQueue(id, 'OCR', 5);
  }

  String _getMimeType(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.pdf': return 'application/pdf';
      case '.txt': return 'text/plain';
      case '.doc': return 'application/msword';
      case '.docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.rtf': return 'application/rtf';
      case '.xls': return 'application/vnd.ms-excel';
      case '.xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.csv': return 'text/csv';
      default: return 'application/octet-stream';
    }
  }

  /// Phase 1: High Priority Discovery (Screenshots & Recent Docs)
  Future<void> _runPriorityPhase() async {
    _emitStatus('Finding your recent memories...', 0.05);
    
    // Recent Screenshots (High Value P1)
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );
    
    final screenshotAlbums = albums.where((a) => a.name.toLowerCase().contains('screenshot')).toList();
    for (var album in screenshotAlbums) {
      final assets = await album.getAssetListRange(start: 0, end: 50);
      for (var asset in assets) {
        await _discoverAsset(asset, BucketType.screenshots, priority: 5);
        // Yield to keep UI responsive during discovery
        await Future.delayed(Duration.zero);
      }
    }

    // Recent Documents/Receipts (P2/P4)
    // For now we use album naming heuristics, later expanded to file system
    final docAlbums = albums.where((a) => 
      a.name.toLowerCase().contains('doc') || 
      a.name.toLowerCase().contains('receipt') ||
      a.name.toLowerCase().contains('scan')
    ).toList();
    
    for (var album in docAlbums) {
      final assets = await album.getAssetListRange(start: 0, end: 50);
      for (var asset in assets) {
        final type = album.name.toLowerCase().contains('receipt') ? BucketType.receipts : BucketType.documents;
        await _discoverAsset(asset, type, priority: 8);
      }
    }

    _emitStatus('Recent screenshots searchable!', 0.2);
  }

  /// Phase 2: Full discovery of all other media
  Future<void> _runDiscoveryPhase() async {
    _emitStatus('Mapping your gallery...', 0.3);
    
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image | RequestType.video,
    );

    for (var album in albums) {
      final assetCount = await album.assetCountAsync;
      for (int i = 0; i < assetCount; i += 100) {
        final assets = await album.getAssetListRange(start: i, end: i + 100);
        for (var asset in assets) {
          final bucket = _classifyBucket(asset, album.name);
          await _discoverAsset(asset, bucket, priority: 1);
          // Yield frequently during deep discovery
          if (i % 10 == 0) await Future.delayed(Duration.zero);
        }
      }
    }
    
    _emitStatus('All memories discovered', 0.5);
  }

  /// Phase 3: Background queue runner (OCR, Classification, Enrichment)
  Future<void> _runBackgroundProcessing() async {
    bool hasQueue = true;
    while (hasQueue) {
      // Smaller batch (3 instead of 5) to minimize block time per loop iteration
      final tasks = await _db.getNextQueueTasks(limit: 3);
      if (tasks.isEmpty) {
        hasQueue = false;
        break;
      }

      for (var task in tasks) {
        // Yield before starting a heavy task
        await Future.delayed(const Duration(milliseconds: 10));

        // Check battery/pause settings before each task
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('battery_mode') == true) {
          await Future.delayed(const Duration(seconds: 1));
        }

        final taskId = task['id'] as int;
        final itemId = task['memory_item_id'] as String;
        
        await _db.updateQueueStatus(taskId, 'PROCESSING');
        
        try {
          // targeted OCR based on classification
          await _processTask(itemId, task['task_type'] as String);
          await _db.updateQueueStatus(taskId, 'DONE');
          
          // Try generating memory triggers after updates
          unawaited(_triggerEngine.processItem(itemId));
          
          // CRITICAL: Mandatory breathing room after every heavy OCR/ML operation
          // This allows Flutter to process UI interactions, clicks, and animations.
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          debugPrint('Task Failed ($itemId): $e');
          await _db.updateQueueStatus(taskId, 'ERROR');
        }
      }
      
      // Gradually updating progress
      _emitStatus('Deep searching memories...', 0.6);
      // Extra breathing room between batches
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    // Once queue is finished, generate timeline locally
    _emitStatus('Organizing life history...', 0.85);
    await _timelineEngine.processRecentItemsForTimeline();
    
    // Backfill triggers across ALL already-OCR'd items
    // This ensures triggers are detected even on items indexed before engine improvements
    _emitStatus('Detecting smart moments...', 0.92);
    final triggerCount = await _triggerEngine.reprocessAllItems();
    debugPrint('[IndexingService] Trigger backfill complete: $triggerCount items processed');
    
    await _setIndexingComplete();
    _emitStatus('Indexing complete', 1.0);

    // Show completion notification
    await NotificationService().showNotification(
      id: 100,
      title: 'Genesis Synthesis Complete 🧠✨',
      body: 'Your neural pathways have been formed. Your life history is now instantly searchable.',
    );
  }

  // --- Helpers ---

  Future<void> _discoverAsset(AssetEntity asset, BucketType bucket, {int priority = 1}) async {
    final bool exists = await _db.isMemoryIndexed(asset.id);
    
    // Change Detection: Check if modification date changed
    if (exists) {
      // Logic for re-indexing changed items could go here
      return; 
    }

    final Map<String, dynamic> item = {
      'id': asset.id,
      'source_type': 'MEDIA',
      'source_bucket': bucket.name.toUpperCase(),
      'source_id': asset.id,
      'file_path': (await asset.file)?.path ?? '',
      'mime_type': asset.mimeType ?? 'image/jpeg',
      'title': asset.title ?? 'Untitled',
      'created_at': asset.createDateTime.millisecondsSinceEpoch,
      'modified_at': asset.modifiedDateTime.millisecondsSinceEpoch,
      'size_bytes': 0,
      'is_indexed': 1,
      'confidence_score': bucket == BucketType.screenshots ? 1.0 : 0.8,
      'metadata_json': '{"width": ${asset.width}, "height": ${asset.height}}',
    };

    await _db.upsertMemoryItem(item);

    // Immediate title indexing for instant searchability
    await _db.updateFTS(asset.id, '', asset.title ?? 'Untitled', bucket.name.toUpperCase());

    // Layer 2: Queue appropriate tasks
    final mimeType = asset.mimeType ?? '';
    final path = (await asset.file)?.path ?? '';
    if (!mimeType.startsWith('video/') && !FileUtils.isVideo(path)) {
      // 1. Text heavy assets get OCR priority
      if (bucket == BucketType.screenshots || bucket == BucketType.receipts || bucket == BucketType.documents) {
        await _db.addToQueue(asset.id, 'OCR', priority);
      } else {
        // 2. Regular photos get Image Labeling (e.g. "Beach", "Dog")
        await _db.addToQueue(asset.id, 'LABEL', priority);
        // They might still have text, so we add OCR at lower priority
        await _db.addToQueue(asset.id, 'OCR', 1);
      }
    }
  }

  Future<void> _processTask(String itemId, String taskType) async {
    if (taskType == 'OCR') {
      await _performTargetedOCR(itemId);
    } else if (taskType == 'LABEL') {
      await _performImageLabeling(itemId);
    } else if (taskType == 'EMBED') {
      await _performEmbedding(itemId);
    }
    // Future: CLASSIFY, ENRICH etc
  }

  Future<void> _performTargetedOCR(String itemId) async {
    final db = await _db.database;
    final results = await db.query('memory_items', where: 'id = ?', whereArgs: [itemId]);
    if (results.isEmpty) return;

    final path = results.first['file_path'] as String;
    final mime = (results.first['mime_type'] as String?) ?? '';
    if (path.isEmpty || !File(path).existsSync()) return;

    // ML Kit Text Recognition only supports images
    final isImage = FileUtils.canBeLoadedAsImage(path, mime);

    if (!isImage) {
      // Mark as "OCR attempted" so we don't waste time re-processing
      await db.update('memory_items', {'is_ocr_complete': 1}, where: 'id = ?', whereArgs: [itemId]);
      debugPrint('[OCR] Skipping non-image: $path');
      return;
    }

    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text.trim();
      
      debugPrint('[OCR] $itemId → ${text.length} chars extracted');

      await _db.updateFTS(
        itemId,
        text, // empty string is fine — clears stale content
        (results.first['title'] as String?) ?? '',
        (results.first['source_bucket'] as String?) ?? '',
      );

      await db.update('memory_items', {'is_ocr_complete': 1}, where: 'id = ?', whereArgs: [itemId]);

      // Immediately run trigger detection on freshly OCR'd text
      if (text.isNotEmpty) {
        unawaited(_triggerEngine.processItem(itemId));
        // Queue embedding task now that we have text content
        await _db.addToQueue(itemId, 'EMBED', 3);
      }
    } catch (e) {
      debugPrint('[OCR] Failed for $itemId: $e');
      // Still mark as attempted so we don't loop
      await db.update('memory_items', {'is_ocr_complete': 1}, where: 'id = ?', whereArgs: [itemId]);
    }
  }

  Future<void> _performImageLabeling(String itemId) async {
    final db = await _db.database;
    final results = await db.query('memory_items', where: 'id = ?', whereArgs: [itemId]);
    if (results.isEmpty) return;

    final path = results.first['file_path'] as String;
    final mime = (results.first['mime_type'] as String?) ?? '';
    if (path.isEmpty || !File(path).existsSync() || !FileUtils.canBeLoadedAsImage(path, mime)) return;

    try {
      final inputImage = InputImage.fromFilePath(path);
      final labels = await _imageLabeler.processImage(inputImage);
      
      // Lowered threshold to 0.5 to be more generous with semantic matches
      final labelStrings = labels
          .where((l) => l.confidence > 0.5)
          .map((l) => l.label)
          .toList();
      
      if (labelStrings.isNotEmpty) {
        final tags = labelStrings.join(', ');
        debugPrint('[LABEL] $itemId → $tags');

        // Fetch existing OCR content to avoid overwriting it
        final currentFts = await db.query('memory_items_fts', where: 'memory_item_id = ?', whereArgs: [itemId]);
        final String existingContent = currentFts.isNotEmpty ? (currentFts.first['content'] as String? ?? '') : '';

        await _db.updateFTS(
          itemId,
          existingContent,
          (results.first['title'] as String?) ?? '',
          tags, // Store visual labels as searchable tags
        );

        // Queue embedding task for visual concepts
        await _db.addToQueue(itemId, 'EMBED', 2);
      }
    } catch (e) {
      debugPrint('[LABEL] Failed for $itemId: $e');
    }
  }

  BucketType _classifyBucket(AssetEntity asset, String albumName) {
    final albumLower = albumName.toLowerCase();
    // Check album name first
    if (albumLower.contains('screenshot')) return BucketType.screenshots;
    if (albumLower.contains('receipt')) return BucketType.receipts;
    if (albumLower.contains('document') || albumLower.contains('scan')) return BucketType.documents;
    if (albumLower.contains('download')) return BucketType.downloads;
    
    // Also check the asset title/filename — some devices store screenshots in Camera roll
    final titleLower = (asset.title ?? '').toLowerCase();
    if (titleLower.startsWith('screenshot') || titleLower.contains('_screenshot')) {
      return BucketType.screenshots;
    }
    if (titleLower.contains('receipt') || titleLower.contains('invoice')) {
      return BucketType.receipts;
    }
    
    return BucketType.photos;
  }

  void _emitStatus(String message, double progress, {String? fact}) {
    _statusController.add({
      'message': message,
      'progress': progress,
      'fact': fact ?? _randomFact,
    });
    // Triggers the Home Screen progress card to refresh
    _ref.invalidate(indexingProgressProvider);
  }

  Future<void> _setIndexingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('indexing_completed', true);
  }

  Future<bool> isIndexingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('indexing_completed') ?? false;
  }

  Future<void> resetIndexing() async {
    await _db.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('indexing_completed');
  }

  Future<void> _performEmbedding(String itemId) async {
    final db = await _db.database;
    final results = await db.query('memory_items', where: 'id = ?', whereArgs: [itemId]);
    if (results.isEmpty) return;

    final item = results.first;
    final title = item['title'] as String? ?? 'Untitled';
    
    // Get content from FTS
    final ftsResults = await db.query('memory_items_fts', where: 'memory_item_id = ?', whereArgs: [itemId]);
    final ocrContent = ftsResults.isNotEmpty ? (ftsResults.first['content'] as String? ?? '') : '';
    final tags = ftsResults.isNotEmpty ? (ftsResults.first['tags'] as String? ?? '') : '';

    // Create a rich context string for the neural engine
    final richContext = "$title. $tags. $ocrContent".trim();
    if (richContext.isEmpty) return;

    try {
      final vector = await _semanticService.embed(richContext);
      await _db.saveEmbedding(itemId, vector, 'bert-mini-v1');
      debugPrint('[EMBED] Neural synthesis complete for $itemId');
    } catch (e) {
      debugPrint('[EMBED] Neural synthesis failed for $itemId: $e');
    }
  }

  void dispose() {
    _textRecognizer.close();
    _imageLabeler.close();
    _statusController.close();
  }
}
