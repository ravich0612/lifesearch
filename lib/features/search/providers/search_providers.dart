import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/search_service.dart';

final databaseServiceProvider = Provider((ref) => DatabaseService());
final searchServiceProvider = Provider((ref) => SearchService());

final searchQueryProvider = StateProvider<String>((ref) => '');
final activeBucketProvider = StateProvider<String>((ref) => 'ALL');

final searchResultsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final bucket = ref.watch(activeBucketProvider);
  
  if (query.isEmpty) return [];
  
  final searchService = ref.read(searchServiceProvider);
  return await searchService.search(query, bucket: bucket);
});

final searchHistoryProvider = FutureProvider<List<String>>((ref) async {
  final dbService = ref.read(databaseServiceProvider);
  return await dbService.getSearchHistory();
});
