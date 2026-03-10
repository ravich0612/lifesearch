import 'database_service.dart';

class SearchService {
  final DatabaseService _db = DatabaseService();

  /// The main entry point for searching.
  /// Follows a 6-step pipeline: Normalize, Intent, FTS Search, Metadata Merge, Rerank, Shape.
  Future<List<Map<String, dynamic>>> search(String query, {String? bucket}) async {
    // Step 1: Query Normalization
    if (query.isEmpty) {
      return await _db.getRecentMemories(limit: 50, bucket: bucket);
    }
    
    final normalizedQuery = _normalizeQuery(query);
    if (normalizedQuery.isEmpty) {
      return await _db.getRecentMemories(limit: 50, bucket: bucket);
    }

    // Step 2: Light Query Understanding (Intent)
    final intent = _determineIntent(normalizedQuery);
    
    // Step 3 & 4: FTS Search + Metadata Merge
    // Note: DatabaseService.searchMemories already joins metadata
    final rawResults = await _db.searchMemories(normalizedQuery, bucket: bucket);

    // Step 5: Reranking
    final rerankedResults = _rerankResults(rawResults, normalizedQuery, intent);

    // Step 6: Result Shaping (Preparing for UI)
    return rerankedResults;
  }

  String _normalizeQuery(String query) {
    return query
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // collapse spaces
        .replaceAll(RegExp(r'[^\w\s]'), ''); // strip punctuation for FTS comfort
  }

  String _determineIntent(String query) {
    if (query.contains('wifi') || query.contains('password')) return 'DOC_SCREENSHOT';
    if (query.contains('receipt') || query.contains('amazon') || query.contains('walmart')) return 'RECEIPT';
    if (query.contains('passport') || query.contains('insurance') || query.contains('form')) return 'DOCUMENT';
    if (query.contains('parking') || query.contains('car')) return 'LOCATION_IMAGE';
    return 'GENERIC';
  }

  List<Map<String, dynamic>> _rerankResults(
    List<Map<String, dynamic>> results, 
    String query, 
    String intent
  ) {
    // Conversion to mutable list for sorting
    final mutableResults = List<Map<String, dynamic>>.from(results);

    // Scoring logic
    final scoredResults = mutableResults.map((item) {
      double score = 1.0;

      final title = (item['title'] ?? '').toString().toLowerCase();
      final snippet = (item['matching_snippet'] ?? '').toString().toLowerCase();
      final bucket = (item['source_bucket'] ?? '').toString();

      // 1. Exact Title Match Boost
      if (title.contains(query)) score += 2.0;

      // 2. Intent-based Source Boosting
      if (intent == 'DOC_SCREENSHOT' && bucket == 'SCREENSHOTS') score += 1.5;
      if (intent == 'RECEIPT' && bucket == 'RECEIPTS') score += 1.5;
      if (intent == 'DOCUMENT' && (bucket == 'DOCUMENTS' || bucket == 'DOWNLOADS')) score += 1.5;

      // 3. Recency Boost (Linear decay - very simple)
      final createdAt = item['created_at'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ageInDays = (now - createdAt) / (1000 * 60 * 60 * 24);
      if (ageInDays < 7) score += 0.5; // recent items

      // 4. Highlight Density (If many highlights in snippet, higher confidence)
      final highlightCount = '[highlight]'.allMatches(snippet).length;
      score += (highlightCount * 0.1);

      return {...item, 'internal_score': score};
    }).toList();

    // Final Sort
    scoredResults.sort((a, b) {
      final scoreA = a['internal_score'] as double;
      final scoreB = b['internal_score'] as double;
      return scoreB.compareTo(scoreA);
    });

    return scoredResults;
  }
}
