import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/nebula_background.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import '../providers/search_providers.dart';
import 'dart:io';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(searchQueryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
  }

  void _onSearchSubmitted(String query) {
    if (query.isNotEmpty) {
      HapticFeedback.mediumImpact();
      ref.read(databaseServiceProvider).saveSearch(query);
      final _ = ref.refresh(searchHistoryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final historyAsync = ref.watch(searchHistoryProvider);
    final activeBucket = ref.watch(activeBucketProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Positioned.fill(child: NebulaBackground()),
          SafeArea(
            child: Column(
              children: [
                // Search Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      Expanded(
                        child: Hero(
                          tag: 'search_bar',
                          child: Material(
                            color: Colors.transparent,
                            child: TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              onChanged: _onQueryChanged,
                              onSubmitted: _onSearchSubmitted,
                              decoration: InputDecoration(
                                hintText: 'Search memories...',
                                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.deepIndigo),
                                suffixIcon: query.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onQueryChanged('');
                                      },
                                    )
                                  : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Source Filters
                if (query.isNotEmpty)
                  _SearchFiltersRow(activeBucket: activeBucket),

                const SizedBox(height: 12),

                // Content Area
                Expanded(
                  child: query.isEmpty
                    ? _buildRecentAndSuggestions(historyAsync)
                    : _buildSearchResults(resultsAsync),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAndSuggestions(AsyncValue<List<String>> historyAsync) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 16),
        historyAsync.when(
          data: (history) => history.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECENT SEARCHES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 12),
                  ...history.take(5).map((q) => _HistoryTile(
                    query: q,
                    onTap: () {
                      _searchController.text = q;
                      _onQueryChanged(q);
                    }
                  )),
                  const SizedBox(height: 32),
                ],
              ),
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => const SizedBox.shrink(),
        ),
        Text(
          'SEARCH SUGGESTIONS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary, letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        _SuggestionTile(title: 'wifi password', icon: Icons.wifi_password_rounded, onTap: () => _applySuggestion('wifi password')),
        _SuggestionTile(title: 'passport photo', icon: Icons.portrait_rounded, onTap: () => _applySuggestion('passport photo')),
        _SuggestionTile(title: 'amazon receipt', icon: Icons.shopping_bag_rounded, onTap: () => _applySuggestion('amazon receipt')),
        _SuggestionTile(title: 'parking lot', icon: Icons.local_parking_rounded, onTap: () => _applySuggestion('parking lot')),
      ],
    ).animate().fadeIn();
  }

  void _applySuggestion(String suggestion) {
    _searchController.text = suggestion;
    _onQueryChanged(suggestion);
    _onSearchSubmitted(suggestion);
  }

  Widget _buildSearchResults(AsyncValue<List<Map<String, dynamic>>> resultsAsync) {
    return resultsAsync.when(
      data: (results) => results.isEmpty
        ? const _EmptyResultsState()
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              return _SearchResultCard(memory: results[index])
                  .animate()
                  .fadeIn(delay: (index * 50).ms)
                  .slideY(begin: 0.05);
            },
          ),
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (err, _) => Center(child: Text('Search error: $err')),
    );
  }
}

class _SearchFiltersRow extends ConsumerWidget {
  final String activeBucket;
  const _SearchFiltersRow({required this.activeBucket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ['ALL', 'SCREENSHOTS', 'DOCUMENTS', 'RECEIPTS', 'PHOTOS'];

    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = activeBucket == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter[0] + filter.substring(1).toLowerCase()),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) ref.read(activeBucketProvider.notifier).state = filter;
              },
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              selectedColor: AppColors.deepIndigo,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  const _HistoryTile({required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.history_rounded, color: AppColors.textTertiary, size: 20),
      title: Text(query, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.north_west_rounded, color: AppColors.textTertiary, size: 16),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _SuggestionTile({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.deepIndigo, size: 18),
            ),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            const Spacer(),
            const Icon(Icons.add_rounded, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> memory;
  const _SearchResultCard({required this.memory});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> memory = this.memory;
    final double semanticScore = memory['semantic_score'] as double? ?? 0.0;

    final String path = memory['file_path'] ?? '';
    final String snippet = memory['matching_snippet'] ?? '';
    final String bucket = (memory['source_bucket'] ?? 'GENERAL').toUpperCase();
    final String mimeType = memory['mime_type'] ?? '';

    // Get category-specific color
    final categoryColor = AppColors.moodColors[bucket] ?? AppColors.deepIndigo;

    return GestureDetector(
      onTap: () => context.push('/detail/${memory['id']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: categoryColor.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: categoryColor.withValues(alpha: 0.15), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'memory_thumb_${memory['id']}',
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.05),
                    ),
                    child: _buildPreview(path, mimeType),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                bucket,
                                style: TextStyle(
                                  color: categoryColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(memory['created_at'])),
                              style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          memory['title'] ?? 'Untitled Memory',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (semanticScore > 0.6)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome, color: categoryColor, size: 10),
                                const SizedBox(width: 4),
                                Text(
                                  'SMART MATCH',
                                  style: TextStyle(
                                    color: categoryColor,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        if ((memory['magic_actions'] as List?)?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Wrap(
                              spacing: 8,
                              children: (memory['magic_actions'] as List).map((action) {
                                final act = action as Map<String, dynamic>;
                                return _MagicActionButton(
                                  label: act['label']!,
                                  type: act['type']!,
                                  value: act['value']!,
                                  color: categoryColor,
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (snippet.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundElevated.withValues(alpha: 0.5),
                  border: Border(top: BorderSide(color: categoryColor.withValues(alpha: 0.05))),
                ),
                child: _RichSnippet(snippet: snippet),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(String path, String mimeType) {
    if (path.isEmpty || !File(path).existsSync()) {
      return const Icon(Icons.description_outlined, color: AppColors.textTertiary);
    }
    
    if (mimeType.startsWith('video/')) {
      return const Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.videocam_rounded, color: AppColors.textTertiary, size: 24),
          Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
        ],
      );
    }

    final pathLower = path.toLowerCase();
    final isWordDoc = mimeType.contains('word') || mimeType.contains('officedocument') || pathLower.endsWith('.docx') || pathLower.endsWith('.doc');
    final isPdf = mimeType.contains('pdf') || pathLower.endsWith('.pdf');
    final isSpreadsheet = mimeType.contains('spreadsheet') || mimeType.contains('csv') || pathLower.endsWith('.xlsx') || pathLower.endsWith('.xls') || pathLower.endsWith('.csv');
    final isText = mimeType.contains('text') || pathLower.endsWith('.txt') || pathLower.endsWith('.rtf');

    if (isWordDoc || isPdf || isSpreadsheet || isText) {
      IconData icon;
      Color color;
      
      if (isPdf) {
        icon = Icons.picture_as_pdf_rounded;
        color = Colors.red.withValues(alpha: 0.5);
      } else if (isSpreadsheet) {
        icon = Icons.table_chart_rounded;
        color = Colors.green.withValues(alpha: 0.5);
      } else {
        icon = Icons.description_rounded;
        color = AppColors.deepIndigo.withValues(alpha: 0.5);
      }

      return Icon(icon, color: color, size: 24);
    }
    
    
    return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.error));
  }
}

class _RichSnippet extends StatelessWidget {
  final String snippet;
  const _RichSnippet({required this.snippet});

  @override
  Widget build(BuildContext context) {
    // Basic parser for [highlight] tags from FTS4 snippet()
    final List<TextSpan> spans = [];
    
    // We need to re-scan to know which index is highlighted because snippet() wraps matches
    final pattern = RegExp(r'\[highlight\](.*?)\[/highlight\]');
    int lastMatchEnd = 0;
    
    for (final match in pattern.allMatches(snippet)) {
      // Add text before match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: snippet.substring(lastMatchEnd, match.start)));
      }
      // Add highlighted text
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(color: AppColors.deepIndigo, fontWeight: FontWeight.bold, backgroundColor: Color(0xFFE8EAF6)),
      ));
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd < snippet.length) {
      spans.add(TextSpan(text: snippet.substring(lastMatchEnd)));
    }

    if (spans.isEmpty && snippet.isNotEmpty) {
      spans.add(TextSpan(text: snippet));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
        children: spans,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _EmptyResultsState extends ConsumerWidget {
  const _EmptyResultsState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final bucket = ref.watch(activeBucketProvider);

    String title = 'No matches found';
    String subtitle = 'Try different keywords or check your spelling';
    IconData icon = Icons.search_off_rounded;

    if (query.isEmpty) {
      title = 'Nothing here yet';
      subtitle = bucket == 'ALL' 
          ? 'Connecting to your memories...' 
          : 'No items found in ${bucket.toLowerCase()}';
      icon = Icons.auto_awesome_mosaic_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.divider),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _MagicActionButton extends StatelessWidget {
  final String label;
  final String type;
  final String value;
  final Color color;

  const _MagicActionButton({
    required this.label,
    required this.type,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case 'phone': icon = Icons.phone_forwarded_rounded; break;
      case 'email': icon = Icons.alternate_email_rounded; break;
      case 'date': icon = Icons.event_available_rounded; break;
      default: icon = Icons.bolt_rounded;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _performAction(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _performAction(BuildContext context) async {
    try {
      if (type == 'phone') {
        final uri = Uri.parse('tel:$value');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      } else if (type == 'email') {
        final uri = Uri.parse('mailto:$value');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      } else if (type == 'date') {
        final event = Event(
          title: 'LifeSearch Memory Event',
          description: 'Created from your memories',
          location: '',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(hours: 1)),
        );
        Add2Calendar.addEvent2Cal(event);
      }
    } catch (e) {
      debugPrint('Action failed: $e');
    }
  }
}
