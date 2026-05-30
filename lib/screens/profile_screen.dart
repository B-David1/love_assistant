import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/person_score.dart';
import '../services/ocean_analyzer_service.dart';
import '../services/profile_storage_service.dart';
import '../services/facebook_service.dart';
import 'blacklist_screen.dart';
import 'quiz_screen.dart';
import 'login_screen.dart';
import 'profile/overview_tab.dart';
import 'profile/personality_tab.dart';
import 'profile/ratings_tab.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final int initialTabIndex;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.initialTabIndex = 0,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileStorageService _profileStorage = ProfileStorageService();
  final FacebookService _facebookService = FacebookService();
  final OceanAnalyzerService _oceanAnalyzer = OceanAnalyzerService();

  UserProfile? _profile;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  late int _selectedTabIndex;

  // Countdown to midnight (when next quiz resets)
  Timer? _countdownTimer;
  Duration _timeUntilMidnight = Duration.zero;

  // Pre-computed lists — only rebuilt when _profile changes
  List<PersonScore> _sortedScores = [];
  List<MapEntry<String, int>> _topPeople = [];
  double _averageRating = 0.0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _loadProfile();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Countdown ─────────────────────────────────────────────────────────────

  void _startCountdown() {
    _updateCountdown();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    if (mounted) setState(() => _timeUntilMidnight = midnight.difference(now));
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    _profile = await _profileStorage.loadUserProfile(widget.userId);
    _recomputeDerivedData(rebuildObjects: true);
    setState(() => _isLoading = false);
  }

  /// Rebuilds derived lists from the current profile.
  ///
  /// Pass [rebuildObjects] = true only when [_profile] itself has been
  /// replaced so PersonScore instances need to be recreated. Otherwise
  /// just re-sort in place to preserve any mutated flags.
  void _recomputeDerivedData({bool rebuildObjects = false}) {
    if (_profile == null) return;

    if (rebuildObjects || _sortedScores.isEmpty) {
      final existing = {for (final s in _sortedScores) s.name: s};
      _sortedScores = _profile!.personScores.entries.map((e) {
        final reused = existing[e.key];
        if (reused != null) {
          reused.isFavorite = _profile!.favorites.contains(e.key);
          reused.isBlacklisted = _profile!.blacklist.contains(e.key);
          return reused;
        }
        return PersonScore(
          name: e.key,
          score: e.value,
          isFavorite: _profile!.favorites.contains(e.key),
          isBlacklisted: _profile!.blacklist.contains(e.key),
        );
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
    } else {
      _sortedScores.sort((a, b) => b.score.compareTo(a.score));
    }

    _topPeople = _sortedScores
        .take(5)
        .map((s) => MapEntry(s.name, s.score))
        .toList();

    if (_profile!.personScores.isNotEmpty) {
      final sum = _profile!.personScores.values.reduce((a, b) => a + b);
      _averageRating = sum / _profile!.personScores.length;
    } else {
      _averageRating = 0.0;
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _saveFlags() async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(
      favorites:
          _sortedScores.where((s) => s.isFavorite).map((s) => s.name).toSet(),
      blacklist: _sortedScores
          .where((s) => s.isBlacklisted)
          .map((s) => s.name)
          .toSet(),
    );
    _profile = updated;
    await _profileStorage.saveUserProfile(updated);
  }

  Future<void> _analyzeOceanTraits() async {
    if (_profile == null || _isAnalyzing) return;
    setState(() => _isAnalyzing = true);

    try {
      final oceanScores =
          await _oceanAnalyzer.analyzeOceanTraits(_profile!.personScores);

      final updated = UserProfile(
        userId: _profile!.userId,
        name: _profile!.name,
        email: _profile!.email,
        profilePictureUrl: _profile!.profilePictureUrl,
        oceanScores: oceanScores,
        personScores: _profile!.personScores,
        analyzedPostIds: _profile!.analyzedPostIds,
        lastAnalyzed: DateTime.now(),
        totalCommentsAnalyzed: _profile!.totalCommentsAnalyzed,
      );

      final withClearedDeltas = updated.copyWith(
        clearQuizDeltas: true,
        hasBeenAnalyzed: true,
      );
      await _profileStorage.saveUserProfile(withClearedDeltas);
      _profile = withClearedDeltas;
      _recomputeDerivedData(rebuildObjects: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ocean personality analysis complete!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing personality: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _openQuiz() async {
    if (_profile == null) return;

    UserProfile profileToPass = _profile!;
    if (!profileToPass.programStarted) {
      final today = DateTime.now();
      final dateOnly = DateTime(today.year, today.month, today.day);
      profileToPass = profileToPass.copyWith(programStartDate: dateOnly);
      await _profileStorage.saveUserProfile(profileToPass);
      setState(() => _profile = profileToPass);
    }

    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          profile: profileToPass,
          dayNumber: profileToPass.nextQuizDay,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _profile = updated;
        _recomputeDerivedData(rebuildObjects: true);
      });
    }
  }

  void _openBlacklistManager() {
    if (_profile == null || _sortedScores.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlacklistScreen(
          userId: widget.userId,
          scores: _sortedScores,
          onChanged: () => setState(() {}),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (_profile == null) return;

    // First confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete your account?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently delete:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('• Your profile and personality data',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                  Text('• All ratings (${_profile!.personScores.length} people)',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                  Text('• Quiz progress and OCEAN scores',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                  Text('• All saved posts and comments',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Second confirmation — type the name to confirm
    final nameController = TextEditingController();
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Final Confirmation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type your name "${_profile!.name}" to confirm deletion:',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _profile!.name,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: nameController.text.trim() == _profile!.name
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Delete'),
            ),
          ],
        ),
      ),
    );

    if (doubleConfirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _profileStorage.deleteUserProfile(widget.userId);
      await _facebookService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
      }
    }
  }

  Future<void> _debugNextDay() async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(
      debugAdvanceDay: true,
      lastQuizDate: DateTime(2000),
    );
    await _profileStorage.saveUserProfile(updated);
    setState(() {
      _profile = updated;
      _recomputeDerivedData(rebuildObjects: false);
    });
  }

  Future<void> _debugCompleteQuiz() async {
    if (_profile == null) return;
    final allDays = Set<int>.from(
        List.generate(UserProfile.programLength, (i) => i + 1));
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);
    final updated = _profile!.copyWith(
      quizDaysCompleted: allDays,
      programStartDate: _profile!.programStartDate ?? dateOnly,
      lastQuizDate: dateOnly,
    );
    await _profileStorage.saveUserProfile(updated);
    setState(() {
      _profile = updated;
      _recomputeDerivedData(rebuildObjects: false);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Not Found')),
        body: const Center(child: Text('User profile not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile!.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'blacklist') _openBlacklistManager();
              if (value == 'delete_account') _deleteAccount();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'blacklist',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Manage Blacklist'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete_account',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      'Delete Account',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Profile header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.pink.shade300, Colors.purple.shade400],
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: _profile!.profilePictureUrl != null
                      ? ClipOval(
                          child: Image.network(
                            _profile!.profilePictureUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.pink.shade300,
                            ),
                          ),
                        )
                      : Icon(Icons.person,
                          size: 50, color: Colors.pink.shade300),
                ),
                const SizedBox(height: 16),
                Text(
                  _profile!.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_profile!.totalCommentsAnalyzed} comments analyzed'
                  ' • ${_profile!.personScores.length} people rated',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),

          // ── Tab bar ─────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                _buildTabButton(0, 'Overview'),
                _buildTabButton(1, 'Personality'),
                _buildTabButton(2, 'Match Scores'),
              ],
            ),
          ),

          // ── Tab content ─────────────────────────────────────────────────
          Expanded(child: _buildActiveTab()),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? Colors.pink.shade400
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? Colors.pink.shade400
                  : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    switch (_selectedTabIndex) {
      case 0:
        return OverviewTab(
          profile: _profile!,
          topPeople: _topPeople,
          averageRating: _averageRating,
        );
      case 1:
        return PersonalityTab(
          profile: _profile!,
          isAnalyzing: _isAnalyzing,
          timeUntilMidnight: _timeUntilMidnight,
          onAnalyze: _analyzeOceanTraits,
          onOpenQuiz: _openQuiz,
          onGoFetchPosts: () => Navigator.of(context).pop(),
          onDebugNextDay: _debugNextDay,
          onDebugCompleteQuiz: _debugCompleteQuiz,
        );
      case 2:
        return RatingsTab(
          sortedScores: _sortedScores,
          onOpenBlacklist: _openBlacklistManager,
          onFlagChanged: () {
            setState(() {});
            _saveFlags();
          },
        );
      default:
        return OverviewTab(
          profile: _profile!,
          topPeople: _topPeople,
          averageRating: _averageRating,
        );
    }
  }
}