import 'dart:async';

import 'package:flutter/material.dart';

import '../models/person_score.dart';
import '../models/user_profile.dart';
import '../services/facebook_service.dart';
import '../services/ocean_analyzer_service.dart';
import '../services/profile_storage_service.dart';
import 'blacklist_screen.dart';
import 'login_screen.dart';
import 'profile/overview_tab.dart';
import 'profile/personality_tab.dart';
import 'profile/ratings_tab.dart';
import 'quiz_screen.dart';

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
  final _profileStorage = ProfileStorageService();
  final _facebookService = FacebookService();
  final _oceanAnalyzer   = OceanAnalyzerService();

  UserProfile? _profile;
  bool _isLoading   = true;
  bool _isAnalyzing = false;
  late int _tabIndex;

  Timer? _countdownTimer;
  Duration _timeUntilMidnight = Duration.zero;

  List<PersonScore> _sortedScores = [];
  List<MapEntry<String, int>> _topPeople = [];
  double _averageRating = 0;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex;
    _loadProfile();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    if (mounted) setState(() => _timeUntilMidnight = midnight.difference(now));
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    _profile = await _profileStorage.loadUserProfile(widget.userId);
    _rebuildDerived(full: true);
    setState(() => _isLoading = false);
  }

  void _rebuildDerived({required bool full}) {
    if (_profile == null) return;

    if (full || _sortedScores.isEmpty) {
      final prev = {for (final s in _sortedScores) s.name: s};
      _sortedScores = _profile!.personScores.entries.map((e) {
        final reused = prev[e.key];
        if (reused != null) {
          reused
            ..isFavorite    = _profile!.favorites.contains(e.key)
            ..isBlacklisted = _profile!.blacklist.contains(e.key);
          return reused;
        }
        return PersonScore(
          name: e.key,
          score: e.value,
          isFavorite:    _profile!.favorites.contains(e.key),
          isBlacklisted: _profile!.blacklist.contains(e.key),
        );
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));
    } else {
      _sortedScores.sort((a, b) => b.score.compareTo(a.score));
    }

    _topPeople = _sortedScores.take(5).map((s) => MapEntry(s.name, s.score)).toList();

    _averageRating = _profile!.personScores.isEmpty
        ? 0
        : _profile!.personScores.values.reduce((a, b) => a + b) /
            _profile!.personScores.length;
  }

  Future<void> _saveFlags() async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(
      favorites:
          _sortedScores.where((s) => s.isFavorite).map((s) => s.name).toSet(),
      blacklist:
          _sortedScores.where((s) => s.isBlacklisted).map((s) => s.name).toSet(),
    );
    _profile = updated;
    await _profileStorage.saveUserProfile(updated);
  }

  Future<void> _runOceanAnalysis() async {
    if (_profile == null || _isAnalyzing) return;
    setState(() => _isAnalyzing = true);

    try {
      final ocean = await _oceanAnalyzer.analyzeOceanTraits(_profile!.personScores);
      final updated = UserProfile(
        userId: _profile!.userId,
        name: _profile!.name,
        email: _profile!.email,
        profilePictureUrl: _profile!.profilePictureUrl,
        oceanScores: ocean,
        personScores: _profile!.personScores,
        analyzedPostIds: _profile!.analyzedPostIds,
        lastAnalyzed: DateTime.now(),
        totalCommentsAnalyzed: _profile!.totalCommentsAnalyzed,
      );
      final saved = updated.copyWith(clearQuizDeltas: true, hasBeenAnalyzed: true);
      await _profileStorage.saveUserProfile(saved);
      _profile = saved;
      _rebuildDerived(full: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personality analysis complete.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _openQuiz() async {
    if (_profile == null) return;

    var profile = _profile!;
    if (!profile.programStarted) {
      final today = DateTime.now();
      profile = profile.copyWith(
          programStartDate: DateTime(today.year, today.month, today.day));
      await _profileStorage.saveUserProfile(profile);
      setState(() => _profile = profile);
    }

    if (!mounted) return;
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) =>
            QuizScreen(profile: profile, dayNumber: profile.nextQuizDay),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _profile = updated;
        _rebuildDerived(full: true);
      });
    }
  }

  void _openBlacklist() {
    if (_profile == null || _sortedScores.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlacklistScreen(
        userId: widget.userId,
        scores: _sortedScores,
        onChanged: () => setState(() {}),
      ),
    ));
  }

  Future<void> _deleteAccount() async {
    if (_profile == null) return;

    final confirmed = await _showDeleteConfirmation();
    if (!confirmed || !mounted) return;

    final nameOk = await _showNameConfirmation();
    if (!nameOk || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _profileStorage.deleteUserProfile(widget.userId);
      await _facebookService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
              SizedBox(width: 10),
              Text('Delete Account'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This will permanently delete:'),
                const SizedBox(height: 10),
                _BulletItem('Your profile and personality data'),
                _BulletItem(
                    'All ratings (${_profile!.personScores.length} people)'),
                _BulletItem('Quiz progress and OCEAN scores'),
                _BulletItem('All saved posts and comments'),
                const SizedBox(height: 12),
                const Text('This action cannot be undone.',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showNameConfirmation() async {
    final controller = TextEditingController();
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => AlertDialog(
              title: const Text('Confirm Deletion'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type "${_profile!.name}" to confirm:'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setS(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: controller.text.trim() == _profile!.name
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _debugNextDay() async {
    if (_profile == null) return;
    final u = _profile!.copyWith(debugAdvanceDay: true, lastQuizDate: DateTime(2000));
    await _profileStorage.saveUserProfile(u);
    setState(() { _profile = u; _rebuildDerived(full: false); });
  }

  Future<void> _debugCompleteQuiz() async {
    if (_profile == null) return;
    final today = DateTime.now();
    final u = _profile!.copyWith(
      quizDaysCompleted: Set.from(List.generate(UserProfile.programLength, (i) => i + 1)),
      programStartDate: _profile!.programStartDate ?? DateTime(today.year, today.month, today.day),
      lastQuizDate: DateTime(today.year, today.month, today.day),
    );
    await _profileStorage.saveUserProfile(u);
    setState(() { _profile = u; _rebuildDerived(full: false); });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Not Found')),
        body: const Center(child: Text('User profile not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile!.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'blacklist') _openBlacklist();
              if (v == 'delete') _deleteAccount();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'blacklist',
                child: Row(children: [
                  Icon(Icons.block, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Manage Blacklist'),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_forever, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete Account',
                      style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _ProfileHeader(profile: _profile!),
          _TabBar(
            selectedIndex: _tabIndex,
            labels: const ['Overview', 'Personality', 'Match Scores'],
            onTap: (i) => setState(() => _tabIndex = i),
          ),
          Expanded(child: _buildTab()),
        ],
      ),
    );
  }

  Widget _buildTab() {
    switch (_tabIndex) {
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
          onAnalyze: _runOceanAnalysis,
          onOpenQuiz: _openQuiz,
          onGoFetchPosts: () => Navigator.of(context).pop(),
          onDebugNextDay: _debugNextDay,
          onDebugCompleteQuiz: _debugCompleteQuiz,
        );
      case 2:
        return RatingsTab(
          sortedScores: _sortedScores,
          onOpenBlacklist: _openBlacklist,
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

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            radius: 48,
            backgroundColor: Colors.white,
            child: profile.profilePictureUrl != null
                ? ClipOval(
                    child: Image.network(
                      profile.profilePictureUrl!,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.person,
                          size: 48, color: Colors.pink.shade300),
                    ),
                  )
                : Icon(Icons.person, size: 48, color: Colors.pink.shade300),
          ),
          const SizedBox(height: 12),
          Text(profile.name,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            '${profile.totalCommentsAnalyzed} comments analysed'
            ' · ${profile.personScores.length} people rated',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final void Function(int) onTap;

  const _TabBar({
    required this.selectedIndex,
    required this.labels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: labels.indexed.map((e) {
          final (i, label) = e;
          final selected = i == selectedIndex;
          return Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
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
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? Colors.pink.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.red)),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13, color: Colors.red.shade700))),
        ],
      ),
    );
  }
}
