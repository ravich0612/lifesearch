import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'lifesearch_v2.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  /// Called when the DB is opened (every launch) — ensures new tables exist
  /// even if somehow missed by onCreate/onUpgrade.
  Future<void> _onOpen(Database db) async {
    await _ensureTablesExist(db);
  }

  /// Migrate existing databases to newer schema versions.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _ensureTablesExist(db);
    }
  }

  /// Idempotently create any tables that may be missing (safe to call multiple times).
  Future<void> _ensureTablesExist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS timeline_events (
        id TEXT PRIMARY KEY,
        title TEXT,
        event_type TEXT,
        start_time INTEGER,
        end_time INTEGER,
        location_lat REAL,
        location_lng REAL,
        preview_image TEXT,
        item_count INTEGER DEFAULT 0,
        confidence_score REAL,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS timeline_event_items (
        event_id TEXT,
        memory_item_id TEXT,
        PRIMARY KEY (event_id, memory_item_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS memory_triggers (
        id TEXT PRIMARY KEY,
        memory_item_id TEXT,
        trigger_type TEXT,
        confidence_score REAL,
        trigger_data_json TEXT,
        created_at INTEGER,
        is_dismissed INTEGER DEFAULT 0,
        is_accepted INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Core metadata table
    await db.execute('''
      CREATE TABLE memory_items (
        id TEXT PRIMARY KEY,
        source_type TEXT,        -- 'MEDIA', 'FILE', 'IMPORT'
        source_bucket TEXT,      -- 'SCREENSHOTS', 'DOCUMENTS', 'GALLERY', 'DOWNLOADS'
        source_id TEXT,          -- Original identifier from OS or provider
        file_path TEXT,
        thumbnail_path TEXT,
        preview_path TEXT,
        mime_type TEXT,
        title TEXT,
        created_at INTEGER,
        modified_at INTEGER,
        latitude REAL,
        longitude REAL,
        size_bytes INTEGER,
        is_favorite INTEGER DEFAULT 0,
        is_indexed INTEGER DEFAULT 0,
        is_ocr_complete INTEGER DEFAULT 0,
        is_enriched INTEGER DEFAULT 0,
        confidence_score REAL DEFAULT 1.0,
        last_seen_hash TEXT,
        tags_json TEXT,          -- JSON list of tags
        entities_json TEXT,      -- JSON list of detected entities
        metadata_json TEXT
      )
    ''');

    // 2. FTS4 Virtual table for fast searching
    await db.execute('''
      CREATE VIRTUAL TABLE memory_items_fts USING fts4(
        memory_item_id,
        content,
        title,
        tags,
        entities,
        tokenize=unicode61
      )
    ''');

    // 3. Search History
    await db.execute('''
      CREATE TABLE search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT UNIQUE,
        searched_at INTEGER
      )
    ''');

    // 4. Indexing Jobs tracking
    await db.execute('''
      CREATE TABLE indexing_jobs (
        id TEXT PRIMARY KEY,
        source_name TEXT,
        status TEXT,
        total_items INTEGER DEFAULT 0,
        indexed_items INTEGER DEFAULT 0,
        failed_items INTEGER DEFAULT 0,
        started_at INTEGER,
        updated_at INTEGER,
        completed_at INTEGER
      )
    ''');

    // 5. Processing Queue
    await db.execute('''
      CREATE TABLE processing_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        memory_item_id TEXT,
        task_type TEXT,
        priority INTEGER DEFAULT 1,
        status TEXT,
        attempts INTEGER DEFAULT 0,
        scheduled_at INTEGER
      )
    ''');

    // 6. Memory Triggers
    await db.execute('''
      CREATE TABLE memory_triggers (
        id TEXT PRIMARY KEY,
        memory_item_id TEXT,
        trigger_type TEXT,
        confidence_score REAL,
        trigger_data_json TEXT,
        created_at INTEGER,
        is_dismissed INTEGER DEFAULT 0,
        is_accepted INTEGER DEFAULT 0
      )
    ''');
    
    // 7. Timeline Events
    await db.execute('''
      CREATE TABLE timeline_events (
        id TEXT PRIMARY KEY,
        title TEXT,
        event_type TEXT,
        start_time INTEGER,
        end_time INTEGER,
        location_lat REAL,
        location_lng REAL,
        preview_image TEXT,
        item_count INTEGER DEFAULT 0,
        confidence_score REAL,
        created_at INTEGER
      )
    ''');

    // 8. Timeline Event items
    await db.execute('''
      CREATE TABLE timeline_event_items (
        event_id TEXT,
        memory_item_id TEXT,
        PRIMARY KEY (event_id, memory_item_id)
      )
    ''');
  }

  // --- CRUD Operations ---

  Future<void> upsertMemoryItem(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert('memory_items', item, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateFTS(String id, String content, String title, String tags, {String entities = ''}) async {
    final db = await database;
    await db.transaction((txn) async {
      // Clean up any existing entries for this ID to prevent duplicates in index
      await txn.delete('memory_items_fts', where: 'memory_item_id = ?', whereArgs: [id]);
      await txn.insert('memory_items_fts', {
        'memory_item_id': id,
        'content': content,
        'title': title,
        'tags': tags,
        'entities': entities,
      });
    });
  }

  Future<void> saveSearch(String query) async {
    final db = await database;
    await db.insert(
      'search_history',
      {'query': query, 'searched_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> getSearchHistory({int limit = 10}) async {
    final db = await database;
    final results = await db.query(
      'search_history',
      orderBy: 'searched_at DESC',
      limit: limit,
    );
    return results.map((e) => e['query'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> searchMemories(String query, {String? bucket}) async {
    final db = await database;
    final cleanQuery = query.replaceAll('\'', '\'\'').trim();
    if (cleanQuery.isEmpty) return [];

    // Tokenize query for better multi-word matching
    // "red car" becomes "red* AND car*" for FTS4
    final tokens = cleanQuery.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (tokens.isEmpty && cleanQuery.isNotEmpty) {
      // Fallback for very short queries
      tokens.add(cleanQuery);
    }
    
    final ftsQuery = tokens.map((t) => '$t*').join(' ');

    // FTS4 match query with snippet support
    // Using full table name for snippet and MATCH to ensure compatibility across all SQLite versions
    String sql = '''
      SELECT m.*, 
             snippet(memory_items_fts, '[highlight]', '[/highlight]', '...', -1, 15) as matching_snippet
      FROM memory_items m
      JOIN memory_items_fts ON m.id = memory_items_fts.memory_item_id
      WHERE memory_items_fts MATCH ?
    ''';

    List<dynamic> args = [ftsQuery];

    if (bucket != null && bucket != 'ALL') {
      sql += ' AND m.source_bucket = ?';
      args.add(bucket.toUpperCase());
    }

    // Basic ordering: Favorites first, then by recency
    sql += ' ORDER BY m.is_favorite DESC, m.created_at DESC';

    return await db.rawQuery(sql, args);
  }

  Future<List<Map<String, dynamic>>> getRecentMemories({int limit = 10, String? bucket}) async {
    final db = await database;
    if (bucket != null && bucket != 'ALL') {
      return await db.query(
        'memory_items',
        where: 'source_bucket = ?',
        whereArgs: [bucket.toUpperCase()],
        orderBy: 'created_at DESC',
        limit: limit,
      );
    }
    return await db.query(
      'memory_items',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<bool> isMemoryIndexed(String id) async {
    final db = await database;
    final results = await db.query(
      'memory_items',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('memory_items');
    await db.delete('memory_items_fts');
    await db.delete('indexing_jobs');
    await db.delete('processing_queue');
    await db.delete('memory_triggers');
    await db.delete('search_history');
    await db.delete('timeline_events');
    await db.delete('timeline_event_items');
  }

  // --- Queue Management ---

  Future<void> addToQueue(String itemId, String taskType, int priority) async {
    final db = await database;
    await db.insert('processing_queue', {
      'memory_item_id': itemId,
      'task_type': taskType,
      'priority': priority,
      'status': 'QUEUED',
      'scheduled_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> requeueAllPhotosForLabeling() async {
    final db = await database;
    final items = await db.query(
      'memory_items',
      columns: ['id'],
      where: 'source_bucket = ?',
      whereArgs: ['PHOTOS'],
    );

    int count = 0;
    final batch = db.batch();
    for (var item in items) {
      final id = item['id'] as String;
      batch.insert('processing_queue', {
        'memory_item_id': id,
        'task_type': 'LABEL',
        'priority': 1,
        'status': 'QUEUED',
        'scheduled_at': DateTime.now().millisecondsSinceEpoch,
      });
      count++;
    }
    await batch.commit(noResult: true);
    return count;
  }

  Future<List<Map<String, dynamic>>> getNextQueueTasks({int limit = 5}) async {
    final db = await database;
    return await db.query(
      'processing_queue',
      where: 'status = ?',
      whereArgs: ['QUEUED'],
      orderBy: 'priority DESC, scheduled_at ASC',
      limit: limit,
    );
  }

  Future<void> updateQueueStatus(int id, String status) async {
    final db = await database;
    await db.update('processing_queue', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  // --- Memory Triggers Management ---

  Future<void> insertTrigger(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('memory_triggers', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getActiveTriggers({int limit = 10}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, m.file_path, m.title, m.source_bucket 
      FROM memory_triggers t
      JOIN memory_items m ON t.memory_item_id = m.id
      WHERE t.is_dismissed = 0 AND t.is_accepted = 0
      ORDER BY t.created_at DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<void> dismissTrigger(String triggerId) async {
    final db = await database;
    await db.update('memory_triggers', {'is_dismissed': 1}, where: 'id = ?', whereArgs: [triggerId]);
  }

  Future<void> acceptTrigger(String triggerId) async {
    final db = await database;
    await db.update('memory_triggers', {'is_accepted': 1}, where: 'id = ?', whereArgs: [triggerId]);
  }

  // --- Timeline Management ---

  Future<void> insertTimelineEvent(Map<String, dynamic> event, List<String> memoryItemIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('timeline_events', event, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final memoryId in memoryItemIds) {
        await txn.insert('timeline_event_items', {
          'event_id': event['id'],
          'memory_item_id': memoryId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getTimelineEvents({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'timeline_events',
      orderBy: 'start_time DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getTimelineEventItems(String eventId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT m.* FROM memory_items m
      JOIN timeline_event_items t ON m.id = t.memory_item_id
      WHERE t.event_id = ?
      ORDER BY m.created_at ASC
    ''', [eventId]);
  }

  Future<bool> doesEventExistByTimeRange(int startTime, int endTime) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT id FROM timeline_events 
      WHERE (start_time BETWEEN ? AND ?) 
      OR (end_time BETWEEN ? AND ?)
      LIMIT 1
    ''', [startTime, endTime, startTime, endTime]);
    return results.isNotEmpty;
  }

  // --- Intelligence Engine ---

  /// Finds memories related to the current one based on:
  /// 1. Close time proximity (+/- 1 hour)
  /// 2. Shared visual labels (if available)
  Future<List<Map<String, dynamic>>> getRelatedMemories(String memoryId, {int limit = 5}) async {
    final db = await database;
    
    // 1. Get current item's data
    final current = await db.query('memory_items', where: 'id = ?', whereArgs: [memoryId], limit: 1);
    if (current.isEmpty) return [];
    
    final item = current.first;
    final time = item['created_at'] as int;
    final labels = item['labels'] as String? ?? '';
    
    // 2. Query for items nearby in time OR items with similar labels (FTS)
    // We prioritize items that are NOT the current one
    final labelList = labels.split(',').where((l) => l.isNotEmpty).take(3);
    String labelQuery = '';
    if (labelList.isNotEmpty) {
      labelQuery = 'OR labels LIKE ${labelList.map((l) => "'%$l%'").join(' OR labels LIKE ')}';
    }

    return await db.rawQuery('''
      SELECT * FROM memory_items 
      WHERE id != ? 
      AND (
        (created_at BETWEEN ? AND ?)
        $labelQuery
      )
      ORDER BY created_at DESC
      LIMIT ?
    ''', [memoryId, time - (3600 * 1000), time + (3600 * 1000), limit]);
  }

  /// Analyzes the last 50 items to determine the "Pulse" of the user's life
  /// Returns a map of category densities (e.g., {'travel': 0.4, 'work': 0.2})
  Future<Map<String, double>> getLifePulse() async {
    final db = await database;
    final recent = await db.query('memory_items', orderBy: 'created_at DESC', limit: 50);
    if (recent.isEmpty) return {'General': 1.0};

    Map<String, int> counts = {};
    for (var item in recent) {
      final bucket = item['source_bucket'] as String;
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }

    final total = recent.length;
    return counts.map((k, v) => MapEntry(k, v / total));
  }
}
