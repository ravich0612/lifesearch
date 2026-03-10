import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/database_service.dart';

final databaseServiceProvider = Provider((ref) => DatabaseService());

final timelineEventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getTimelineEvents();
});

final timelineEventItemsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getTimelineEventItems(eventId);
});
