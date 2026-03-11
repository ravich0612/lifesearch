import 'dart:typed_data';
import 'database_service.dart';
import 'semantic_service.dart';

class SearchService {
  final DatabaseService _db = DatabaseService();
  final SemanticService _semantic = SemanticService();

  /// The main entry point for searching.
  /// Follows a 7-step pipeline: Normalize, Intent, FTS Search, Neural Boost, Metadata Merge, Rerank, Shape.
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
    
    // Step 3: FTS Search
    final rawResults = await _db.searchMemories(normalizedQuery, bucket: bucket);

    // Step 4: Neural Boost (Semantic Reranking)
    final neuralResults = await _neuralBoost(rawResults, normalizedQuery);

    // Step 5 & 6: Intent-based Reranking & Final Scoring
    final rerankedResults = _rerankResults(neuralResults, normalizedQuery, intent);

    // Step 7: Entity & Action Extraction (Magic Cards)
    final actionableResults = _extractActions(rerankedResults);

    return actionableResults;
  }

  List<Map<String, dynamic>> _extractActions(List<Map<String, dynamic>> results) {
    return results.map((item) {
      final text = ("${item['title']} ${item['matching_snippet']}").toLowerCase();
      final actions = <Map<String, String>>[];

      // 1. Phone Numbers
      final phoneRegex = RegExp(r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}');
      final phoneMatch = phoneRegex.firstMatch(text);
      if (phoneMatch != null) {
        actions.add({'type': 'phone', 'value': phoneMatch.group(0)!, 'label': 'Call'});
      }

      // 2. Emails
      final emailRegex = RegExp(r'[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+\.[a-z]{2,3}');
      final emailMatch = emailRegex.firstMatch(text);
      if (emailMatch != null) {
        actions.add({'type': 'email', 'value': emailMatch.group(0)!, 'label': 'Email'});
      }
      
      // 3. Dates (Upcoming/Events)
      final dateRegex = RegExp(r'(\d{1,2}/\d{1,2}/\d{2,4})|(\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{2,4})');
      final dateMatch = dateRegex.firstMatch(text);
      if (dateMatch != null) {
        actions.add({'type': 'date', 'value': dateMatch.group(0)!, 'label': 'Add to Calendar'});
      }

      return {...item, 'magic_actions': actions};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _neuralBoost(List<Map<String, dynamic>> results, String query) async {
    if (query.length < 3) return results; // Skip neural for tiny queries

    try {
      final queryVector = await _semantic.embed(query);
      final embeddings = await _db.getSummaryOfEmbeddings();
      
      if (embeddings.isEmpty) return results;

      // Create a map for fast lookup
      final Map<String, double> semanticScores = {};
      
      for (var row in embeddings) {
        final id = row['id'] as String;
        final blob = row['embedding_blob'] as Uint8List;
        final memoryVector = Float32List.view(blob.buffer).toList();
        
        final similarity = _semantic.calculateRelevance(queryVector, memoryVector);
        semanticScores[id] = similarity;
      }

      // Merge scores into results
      return results.map((item) {
        final id = item['id'] as String;
        final semanticScore = semanticScores[id] ?? 0.0;
        return {...item, 'semantic_score': semanticScore};
      }).toList();
    } catch (e) {
      print('[SearchService] Neural boost failed: $e');
      return results;
    }
  }

  String _normalizeQuery(String query) {
    return query
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') 
        .replaceAll(RegExp(r'[^\w\s]'), ''); 
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
    final mutableResults = List<Map<String, dynamic>>.from(results);

    final scoredResults = mutableResults.map((item) {
      double score = 1.0;

      final title = (item['title'] ?? '').toString().toLowerCase();
      final snippet = (item['matching_snippet'] ?? '').toString().toLowerCase();
      final bucket = (item['source_bucket'] ?? '').toString();
      final semanticScore = item['semantic_score'] as double? ?? 0.0;

      // 1. Semantic Match Boost (Significant weight)
      score += (semanticScore * 4.0);

      // 2. Exact Title Match Boost
      if (title.contains(query)) score += 2.0;

      // 3. Intent-based Source Boosting
      if (intent == 'DOC_SCREENSHOT' && bucket == 'SCREENSHOTS') score += 1.5;
      if (intent == 'RECEIPT' && bucket == 'RECEIPTS') score += 1.5;
      if (intent == 'DOCUMENT' && (bucket == 'DOCUMENTS' || bucket == 'DOWNLOADS')) score += 1.5;

      // 4. Recency Boost
      final createdAt = item['created_at'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ageInDays = (now - createdAt) / (1000 * 60 * 60 * 24);
      if (ageInDays < 7) score += 0.5;

      // 5. Highlight Density
      final highlightCount = '[highlight]'.allMatches(snippet).length;
      score += (highlightCount * 0.1);

      return {...item, 'internal_score': score};
    }).toList();

    scoredResults.sort((a, b) {
      final scoreA = a['internal_score'] as double;
      final scoreB = b['internal_score'] as double;
      return scoreB.compareTo(scoreA);
    });

    return scoredResults;
  }
}
