import 'package:flutter/material.dart';
import '../../models/person_score.dart';
import '../../widgets/person_score_tile.dart';

class RatingsTab extends StatefulWidget {
  final List<PersonScore> sortedScores;
  final VoidCallback onOpenBlacklist;
  final VoidCallback onFlagChanged;

  const RatingsTab({
    super.key,
    required this.sortedScores,
    required this.onOpenBlacklist,
    required this.onFlagChanged,
  });

  @override
  State<RatingsTab> createState() => _RatingsTabState();
}

class _RatingsTabState extends State<RatingsTab> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _queryNotifier = ValueNotifier('');
  late final ValueNotifier<List<PersonScore>> _scoresNotifier;

  bool _isSearching = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _scoresNotifier = ValueNotifier(widget.sortedScores);
  }

  @override
  void didUpdateWidget(RatingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sortedScores != oldWidget.sortedScores) {
      _scoresNotifier.value = widget.sortedScores;
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _queryNotifier.dispose();
    _scoresNotifier.dispose();
    super.dispose();
  }

  void _openSearch() {
    if (_isSearching) return;
    setState(() => _isSearching = true);
    _overlayEntry = OverlayEntry(
      builder: (_) => _SearchOverlay(
        searchController: _searchController,
        queryNotifier: _queryNotifier,
        scoresNotifier: _scoresNotifier,
        onFlagChanged: widget.onFlagChanged,
        onClose: _closeSearch,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _closeSearch() {
    _removeOverlay();
    _searchController.clear();
    _queryNotifier.value = '';
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sortedScores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No ratings yet',
                style:
                    TextStyle(fontSize: 18, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Fetch and analyze posts to see ratings',
                style:
                    TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    final visibleScores =
        widget.sortedScores.where((s) => !s.isBlacklisted).toList();
    final blacklistedCount =
        widget.sortedScores.where((s) => s.isBlacklisted).length;
    final favorites = visibleScores.where((s) => s.isFavorite).toList();
    final rest = visibleScores.where((s) => !s.isFavorite).toList();
    final items = _buildItems(favorites, rest);

    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GestureDetector(
            onTap: _openSearch,
            child: AbsorbPointer(
              child: TextField(
                controller: _searchController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Search people…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  isDense: true,
                ),
              ),
            ),
          ),
        ),

        // ── Toolbar ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${visibleScores.length} of ${widget.sortedScores.length} shown'
                    '${favorites.isNotEmpty ? ' • ${favorites.length} ★' : ''}',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              TextButton.icon(
                onPressed: widget.onOpenBlacklist,
                icon: const Icon(Icons.block, size: 16),
                label: const Text('Manage Blacklist'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ],
          ),
        ),

        // ── Blacklisted banner ───────────────────────────────────────────────
        if (blacklistedCount > 0)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.red.shade700, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$blacklistedCount person(s) blacklisted — hiding from list',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        // ── Full list ────────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item is _SectionHeader) return _buildSectionHeader(item);
              if (item is _ScoreItem) {
                return PersonScoreTile(
                  score: item.score,
                  rank: item.rank,
                  onBlacklistToggle: widget.onFlagChanged,
                  onFavoriteToggle: widget.onFlagChanged,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  List<_ListItem> _buildItems(
      List<PersonScore> favorites, List<PersonScore> rest) {
    final items = <_ListItem>[];
    if (favorites.isNotEmpty) {
      items.add(_SectionHeader(
          label: 'Favorites',
          icon: Icons.star,
          color: Colors.amber,
          count: favorites.length));
      for (int i = 0; i < favorites.length; i++) {
        items.add(_ScoreItem(score: favorites[i], rank: i + 1));
      }
    }
    if (rest.isNotEmpty) {
      items.add(_SectionHeader(
          label: 'All People',
          icon: Icons.people,
          color: Colors.grey.shade600,
          count: rest.length));
      for (int i = 0; i < rest.length; i++) {
        items.add(_ScoreItem(score: rest[i], rank: i + 1));
      }
    }
    return items;
  }

  Widget _buildSectionHeader(_SectionHeader header) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Icon(header.icon, size: 16, color: header.color),
          const SizedBox(width: 6),
          Text(header.label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: header.color,
                  letterSpacing: 0.4)),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: header.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${header.count}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: header.color)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Divider(color: header.color.withOpacity(0.25))),
        ],
      ),
    );
  }
}

// ── Full-screen search overlay ────────────────────────────────────────────────

class _SearchOverlay extends StatefulWidget {
  final TextEditingController searchController;
  final ValueNotifier<String> queryNotifier;
  final ValueNotifier<List<PersonScore>> scoresNotifier;
  final VoidCallback onFlagChanged;
  final VoidCallback onClose;

  const _SearchOverlay({
    required this.searchController,
    required this.queryNotifier,
    required this.scoresNotifier,
    required this.onFlagChanged,
    required this.onClose,
  });

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus when overlay appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  List<_ListItem> _buildItems(List<PersonScore> scores, String query) {
    final filtered = query.isEmpty
        ? scores
        : scores
            .where((s) =>
                s.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
    final visible = filtered.where((s) => !s.isBlacklisted).toList();
    final favorites = visible.where((s) => s.isFavorite).toList();
    final rest = visible.where((s) => !s.isFavorite).toList();

    final items = <_ListItem>[];
    if (favorites.isNotEmpty) {
      items.add(_SectionHeader(
          label: 'Favorites',
          icon: Icons.star,
          color: Colors.amber,
          count: favorites.length));
      for (int i = 0; i < favorites.length; i++) {
        items.add(_ScoreItem(score: favorites[i], rank: i + 1));
      }
    }
    if (rest.isNotEmpty) {
      items.add(_SectionHeader(
          label: query.isEmpty ? 'All People' : 'Results',
          icon: Icons.people,
          color: Colors.grey.shade600,
          count: rest.length));
      for (int i = 0; i < rest.length; i++) {
        items.add(_ScoreItem(score: rest[i], rank: i + 1));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dim background
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          ),

          // Search panel
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: keyboardHeight,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    // Search field — real keyboard input here
                    TextField(
                      controller: widget.searchController,
                      focusNode: _focusNode,
                      onChanged: (val) =>
                          widget.queryNotifier.value = val.trim(),
                      decoration: InputDecoration(
                        hintText: 'Search people…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: widget.onClose,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: ValueListenableBuilder<List<PersonScore>>(
                        valueListenable: widget.scoresNotifier,
                        builder: (context, scores, _) {
                          return ValueListenableBuilder<String>(
                            valueListenable: widget.queryNotifier,
                            builder: (context, query, _) {
                              final items = _buildItems(scores, query);
                              final visibleCount =
                                  items.whereType<_ScoreItem>().length;

                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.12),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  child: query.isNotEmpty &&
                                          visibleCount == 0
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                            children: [
                                              Icon(Icons.search_off,
                                                  size: 48,
                                                  color: Colors
                                                      .grey.shade300),
                                              const SizedBox(height: 8),
                                              Text(
                                                  'No results for "$query"',
                                                  style: TextStyle(
                                                      color: Colors.grey
                                                          .shade500)),
                                            ],
                                          ),
                                        )
                                      : ListView.builder(
                                          padding:
                                              const EdgeInsets.all(8),
                                          itemCount: items.length,
                                          itemBuilder:
                                              (context, index) {
                                            final item = items[index];
                                            if (item is _SectionHeader) {
                                              return Padding(
                                                padding: const EdgeInsets
                                                    .only(
                                                    top: 8, bottom: 4),
                                                child: Row(children: [
                                                  Icon(item.icon,
                                                      size: 14,
                                                      color: item.color),
                                                  const SizedBox(
                                                      width: 6),
                                                  Text(item.label,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700,
                                                          color: item
                                                              .color)),
                                                  const SizedBox(
                                                      width: 6),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 1),
                                                    decoration: BoxDecoration(
                                                        color: item.color
                                                            .withOpacity(
                                                                0.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    8)),
                                                    child: Text(
                                                        '${item.count}',
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color: item
                                                                .color)),
                                                  ),
                                                ]),
                                              );
                                            }
                                            if (item is _ScoreItem) {
                                              return PersonScoreTile(
                                                score: item.score,
                                                rank: item.rank,
                                                onBlacklistToggle: widget
                                                    .onFlagChanged,
                                                onFavoriteToggle: widget
                                                    .onFlagChanged,
                                              );
                                            }
                                            return const SizedBox
                                                .shrink();
                                          },
                                        ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Flat-list item types ──────────────────────────────────────────────────────

abstract class _ListItem {}

class _SectionHeader extends _ListItem {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  _SectionHeader(
      {required this.label,
      required this.icon,
      required this.color,
      required this.count});
}

class _ScoreItem extends _ListItem {
  final PersonScore score;
  final int rank;
  _ScoreItem({required this.score, required this.rank});
}