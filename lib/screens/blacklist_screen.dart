import 'package:flutter/material.dart';
import '../models/person_score.dart';
import '../services/profile_storage_service.dart';

class BlacklistScreen extends StatefulWidget {
  final String userId;

  /// All current scores — passed in so the screen can read & mutate them.
  final List<PersonScore> scores;

  /// Called when the screen pops so the caller can refresh its own state.
  final VoidCallback? onChanged;

  const BlacklistScreen({
    super.key,
    required this.userId,
    required this.scores,
    this.onChanged,
  });

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProfileStorageService _profileStorage = ProfileStorageService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<PersonScore> get _blacklisted =>
      widget.scores.where((s) => s.isBlacklisted).toList();

  List<PersonScore> get _notBlacklisted =>
      widget.scores.where((s) => !s.isBlacklisted).toList();

  List<PersonScore> _applySearch(List<PersonScore> list) {
    if (_searchQuery.isEmpty) return list;
    return list
        .where((s) => s.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  void _toggle(PersonScore score, bool blacklist) {
    setState(() {
      score.isBlacklisted = blacklist;
      _hasChanges = true;
    });
  }

  void _removeAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove all from blacklist?'),
        content: Text(
            'This will un-blacklist all ${_blacklisted.length} people. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                for (final s in _blacklisted) {
                  s.isBlacklisted = false;
                }
                _hasChanges = true;
              });
            },
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove all'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndPop() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = await _profileStorage.loadUserProfile(widget.userId);
      if (profile != null) {
        final updatedProfile = profile.copyWith(
          favorites: widget.scores
              .where((s) => s.isFavorite)
              .map((s) => s.name)
              .toSet(),
          blacklist: widget.scores
              .where((s) => s.isBlacklisted)
              .map((s) => s.name)
              .toSet(),
        );
        await _profileStorage.saveUserProfile(updatedProfile);
      }
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final blacklisted = _applySearch(_blacklisted);
    final available = _applySearch(_notBlacklisted);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blacklist Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 18),
                  const SizedBox(width: 6),
                  Text('Blacklisted (${_blacklisted.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, size: 18),
                  const SizedBox(width: 6),
                  Text('Everyone (${_notBlacklisted.length})'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _saveAndPop,
              icon: Icon(
                _hasChanges ? Icons.save : Icons.check,
                color: Colors.white,
              ),
              label: Text(
                _hasChanges ? 'Save' : 'Done',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search people…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),

          // Change indicator banner
          if (_hasChanges)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'You have unsaved changes',
                    style: TextStyle(
                        fontSize: 12, color: Colors.orange.shade800),
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: Blacklisted ──────────────────────────────
                blacklisted.isEmpty
                    ? _emptyState(
                        icon: Icons.check_circle_outline,
                        title: _searchQuery.isNotEmpty
                            ? 'No results'
                            : 'Blacklist is empty',
                        subtitle: _searchQuery.isNotEmpty
                            ? 'Try a different search'
                            : 'Add people from the Everyone tab',
                        iconColor: Colors.green,
                      )
                    : Column(
                        children: [
                          // "Remove all" action
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${blacklisted.length} person${blacklisted.length == 1 ? '' : 's'} blocked',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600),
                                ),
                                if (_searchQuery.isEmpty &&
                                    _blacklisted.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: _removeAll,
                                    icon: const Icon(Icons.delete_sweep,
                                        size: 18),
                                    label: const Text('Remove all'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: blacklisted.length,
                              itemBuilder: (_, i) => _BlacklistTile(
                                score: blacklisted[i],
                                isBlacklisted: true,
                                onToggle: () =>
                                    _toggle(blacklisted[i], false),
                              ),
                            ),
                          ),
                        ],
                      ),

                // ── Tab 2: Everyone (not blacklisted) ───────────────
                available.isEmpty
                    ? _emptyState(
                        icon: Icons.block,
                        title: _searchQuery.isNotEmpty
                            ? 'No results'
                            : 'Everyone is blacklisted',
                        subtitle: _searchQuery.isNotEmpty
                            ? 'Try a different search'
                            : 'Remove people from the Blacklisted tab',
                        iconColor: Colors.red,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: available.length,
                        itemBuilder: (_, i) => _BlacklistTile(
                          score: available[i],
                          isBlacklisted: false,
                          onToggle: () => _toggle(available[i], true),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: iconColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle,
              style:
                  TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

// ─── Individual tile ────────────────────────────────────────────────────────

class _BlacklistTile extends StatelessWidget {
  final PersonScore score;
  final bool isBlacklisted;
  final VoidCallback onToggle;

  const _BlacklistTile({
    required this.score,
    required this.isBlacklisted,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isBlacklisted
              ? Colors.red.shade200
              : Colors.grey.shade200,
        ),
      ),
      color: isBlacklisted ? Colors.red.shade50 : null,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor:
              score.scoreColor.withValues(alpha: 0.15),
          child: Text(
            score.name.isNotEmpty
                ? score.name[0].toUpperCase()
                : '?',
            style: TextStyle(
                color: score.scoreColor,
                fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          score.name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration:
                isBlacklisted ? TextDecoration.none : null,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: score.scoreColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${score.score}/100',
                style: TextStyle(
                    fontSize: 11,
                    color: score.scoreColor,
                    fontWeight: FontWeight.w600),
              ),
            ),
            if (score.isFavorite) ...[
              const SizedBox(width: 6),
              const Icon(Icons.star,
                  size: 14, color: Colors.amber),
            ],
          ],
        ),
        trailing: isBlacklisted
            ? TextButton.icon(
                onPressed: onToggle,
                icon: const Icon(Icons.remove_circle_outline,
                    size: 18),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700),
              )
            : TextButton.icon(
                onPressed: onToggle,
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Block'),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700),
              ),
      ),
    );
  }
}
