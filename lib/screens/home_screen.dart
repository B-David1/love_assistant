import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/facebook_config.dart';
import '../models/ocean_scores.dart';
import '../models/person_score.dart';
import '../models/user_profile.dart';
import '../providers/app_provider.dart';
import '../services/comment_parser_service.dart';
import '../services/facebook_service.dart';
import '../services/ocean_analyzer_service.dart';
import '../services/profile_storage_service.dart';
import '../utils/android_webview_post_loader.dart';
import 'login_screen.dart';
import 'profile_list_screen.dart';
import 'profile_screen.dart';

enum AiProvider { chatGpt, gemini, claude, deepSeek }

extension AiProviderX on AiProvider {
  String get label => switch (this) {
        AiProvider.chatGpt  => 'ChatGPT',
        AiProvider.gemini   => 'Gemini',
        AiProvider.claude   => 'Claude',
        AiProvider.deepSeek => 'DeepSeek',
      };

  String get subtitle => switch (this) {
        AiProvider.chatGpt  => 'GPT-4o mini',
        AiProvider.gemini   => 'Not implemented',
        AiProvider.claude   => 'Not implemented',
        AiProvider.deepSeek => 'Not implemented',
      };

  bool get isAvailable => this == AiProvider.chatGpt;

  Color get color => switch (this) {
        AiProvider.chatGpt  => const Color(0xFF10A37F),
        AiProvider.gemini   => const Color(0xFF4285F4),
        AiProvider.claude   => const Color(0xFFD97706),
        AiProvider.deepSeek => const Color(0xFF6366F1),
      };

  String get avatarLetter => switch (this) {
        AiProvider.chatGpt  => 'G',
        AiProvider.gemini   => 'G',
        AiProvider.claude   => 'C',
        AiProvider.deepSeek => 'D',
      };
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _facebookService  = FacebookService();
  final _parserService    = CommentParserService();
  final _profileStorage   = ProfileStorageService();
  final _oceanAnalyzer    = OceanAnalyzerService();

  AiProvider _selectedAi = AiProvider.chatGpt;

  static const _kFetchKey   = 'last_fetch_time';
  static const _kAnalyzeKey = 'last_analyze_time';
  static const _fetchCooldown   = Duration(hours: 1);
  static const _analyzeCooldown = Duration(hours: 4);

  DateTime? _lastFetchTime;
  DateTime? _lastAnalyzeTime;
  Timer? _countdownTimer;

  Duration? get _fetchRemaining {
    if (_lastFetchTime == null) return null;
    final r = _fetchCooldown - DateTime.now().difference(_lastFetchTime!);
    return r.isNegative ? null : r;
  }

  Duration? get _analyzeRemaining {
    if (_lastAnalyzeTime == null) return null;
    final r = _analyzeCooldown - DateTime.now().difference(_lastAnalyzeTime!);
    return r.isNegative ? null : r;
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadCooldowns();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final ok = await _facebookService.isLoggedIn();
    if (!ok && mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Future<void> _loadCooldowns() async {
    final prefs = await SharedPreferences.getInstance();
    final fetchMs   = prefs.getInt(_kFetchKey);
    final analyzeMs = prefs.getInt(_kAnalyzeKey);
    if (!mounted) return;
    setState(() {
      _lastFetchTime   = fetchMs   != null
          ? DateTime.fromMillisecondsSinceEpoch(fetchMs)   : null;
      _lastAnalyzeTime = analyzeMs != null
          ? DateTime.fromMillisecondsSinceEpoch(analyzeMs) : null;
    });
  }

  Future<void> _stampFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(_kFetchKey, now.millisecondsSinceEpoch);
    if (mounted) setState(() => _lastFetchTime = now);
  }

  Future<void> _stampAnalyze() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(_kAnalyzeKey, now.millisecondsSinceEpoch);
    if (mounted) setState(() => _lastAnalyzeTime = now);
  }

  Future<void> _resetCooldowns() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFetchKey);
    await prefs.remove(_kAnalyzeKey);
    setState(() {
      _lastFetchTime   = null;
      _lastAnalyzeTime = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cooldowns reset.'),
            duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _fetchPosts() async {
    final provider = Provider.of<AppProvider>(context, listen: false);

    provider
      ..setLoading(true)
      ..setStatus('Retrieving your Facebook posts…');

    _facebookService.webViewContext = context;

    if (Platform.isAndroid) {
      final token = await _facebookService.getAccessToken();
      if (token != null && mounted) {
        await AndroidWebviewPostLoader.warmUpWebViewSession(
            context, FacebookConfig.getAppId(), token);
      }
    }

    try {
      final result = await _facebookService.fetchAndSaveAccessiblePosts(
        onProgress: (cur, tot) =>
            provider.setStatus('Downloading posts: $cur of $tot'),
      );
      provider.setStatus('${result['savedCount']} posts downloaded successfully.');
      await _stampFetch();
    } catch (e) {
      provider.setStatus('Failed to retrieve posts. Please try again.',
          isError: true);
    } finally {
      provider.setLoading(false);
    }
  }

  Future<void> _analyzeComments() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final userId = await _facebookService.getCurrentUserId();

    if (userId == null) {
      provider.setStatus('User session not found. Please log in again.',
          isError: true);
      return;
    }

    provider
      ..setLoading(true)
      ..setStatus('Starting personality analysis with ${_selectedAi.label}…');

    try {
      final existingProfile = await _profileStorage.loadUserProfile(userId);

      final scores = await _parserService.processAllCommentsForUser(
        userId: userId,
        userName: existingProfile?.name,
        onStatusUpdate: (msg, {bool isError = false}) =>
            provider.setStatus(msg, isError: isError),
      );

      provider.setPersonScores(scores);
      await _saveProfile(userId, scores, existingProfile);

      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: userId, initialTabIndex: 0),
        ));
      }

      provider.setStatus(
          'Analysis complete. Your personality profile has been updated.');
      await _stampAnalyze();
    } catch (e) {
      provider.setStatus('Analysis failed. Please try again.', isError: true);
    } finally {
      provider.setLoading(false);
    }
  }

  Future<void> _saveProfile(
    String userId,
    List<PersonScore> scores,
    UserProfile? existing,
  ) async {
    final userData = await _facebookService.getCurrentUser();

    final name = (existing?.name.isNotEmpty == true && existing!.name != 'User')
        ? existing.name
        : (userData?['name'] as String? ?? existing?.name ?? 'User');

    final personMap = {for (final s in scores) s.name: s.score};

    OceanScores ocean;
    if (existing != null && existing.personScores.isNotEmpty) {
      ocean = await _oceanAnalyzer
          .analyzeOceanTraits({...existing.personScores, ...personMap});
    } else {
      ocean = existing?.oceanScores ??
          OceanScores(
            openness: 50, conscientiousness: 50, extraversion: 50,
            agreeableness: 50, neuroticism: 50,
          );
    }

    final posts = await _profileStorage.getUserPosts(userId);
    final postIds = posts
        .map((f) => f.path.split('/').last.replaceAll('.html', ''))
        .toSet();

    final profile = UserProfile(
      userId: userId,
      name: name,
      email: userData?['email'] as String? ?? existing?.email,
      profilePictureUrl:
          userData?['picture']?['data']?['url'] as String? ??
              existing?.profilePictureUrl,
      oceanScores: ocean,
      personScores: personMap,
      favorites: existing?.favorites,
      blacklist: existing?.blacklist,
      analyzedPostIds: {
        ...?existing?.analyzedPostIds,
        ...postIds,
      }.toList(),
      lastAnalyzed: DateTime.now(),
      totalCommentsAnalyzed:
          scores.length + (existing?.totalCommentsAnalyzed ?? 0),
      hasBeenAnalyzed: true,
    );

    await _profileStorage.saveUserProfile(profile);
  }

  Future<void> _logout() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await _facebookService.logout();
    provider.clearAll();
    if (mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _goToProfiles() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileListScreen()));

  Future<void> _goToMyProfile() async {
    final userId = await _facebookService.getCurrentUserId();
    if (userId != null && mounted) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
    }
  }

  void _showAiSelector() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.smart_toy_outlined),
          SizedBox(width: 10),
          Text('Select AI Model'),
        ]),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AiProvider.values.map((ai) {
              final selected = ai == _selectedAi;
              return ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                leading: CircleAvatar(
                  backgroundColor: ai.color,
                  child: Text(ai.avatarLetter,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(ai.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ai.isAvailable ? null : Colors.grey)),
                subtitle: Text(
                  ai.isAvailable ? ai.subtitle : 'Not implemented',
                  style: TextStyle(
                      fontSize: 12,
                      color: ai.isAvailable
                          ? Colors.grey.shade600
                          : Colors.grey.shade400),
                ),
                trailing: selected
                    ? Icon(Icons.check_circle, color: ai.color)
                    : ai.isAvailable
                        ? null
                        : _ComingSoonBadge(),
                selected: selected,
                selectedTileColor: ai.color.withValues(alpha: 0.08),
                onTap: () {
                  Navigator.pop(ctx);
                  if (!ai.isAvailable) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${ai.label} is not implemented yet'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ));
                    return;
                  }
                  setState(() => _selectedAi = ai);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (_, provider, __) => Scaffold(
        appBar: AppBar(
          title: const Text('Love Assistant'),
          actions: [
            if (Platform.isWindows || Platform.isAndroid)
              IconButton(
                icon: const Icon(Icons.timer_off_outlined),
                tooltip: 'Reset Cooldowns',
                onPressed: _resetCooldowns,
              ),
            IconButton(
              icon: const Icon(Icons.people),
              tooltip: 'All Profiles',
              onPressed: _goToProfiles,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: _logout,
            ),
          ],
        ),
        body: Column(
          children: [
            _StatusBanner(
                message: provider.statusMessage,
                isError: provider.isError,
                isLoading: provider.isLoading),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.favorite,
                          size: 72, color: Colors.pink.shade300),
                      const SizedBox(height: 20),
                      const Text('Love Assistant',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        'Analyse comments and discover personality insights',
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      _buildActionCard(provider),
                      const SizedBox(height: 20),
                      _InfoBanner(
                        icon: Icons.lightbulb,
                        color: Colors.orange,
                        text:
                            'Your comments will be analysed to build a Big Five '
                            'personality profile and track how you rate others.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(AppProvider provider) {
    final busy = provider.isLoading;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _ActionButton(
              icon: Icons.download,
              label: _fetchRemaining != null
                  ? 'Fetch Posts (${_fmt(_fetchRemaining!)})'
                  : 'Fetch Posts',
              description: _fetchRemaining != null
                  ? 'Available in ${_fmt(_fetchRemaining!)}'
                  : 'Download your Facebook posts',
              color: Colors.blue,
              onPressed:
                  busy || _fetchRemaining != null ? null : _fetchPosts,
            ),
            const SizedBox(height: 16),
            _AnalyzeRow(
              label: _analyzeRemaining != null
                  ? 'Analyse (${_fmt(_analyzeRemaining!)})'
                  : 'Analyse Comments',
              selectedAi: _selectedAi,
              onPressed:
                  busy || _analyzeRemaining != null ? null : _analyzeComments,
              onAiTap: busy ? null : _showAiSelector,
            ),
            const SizedBox(height: 16),
            _ActionButton(
              icon: Icons.psychology,
              label: 'View My Profile',
              description: 'See your personality insights',
              color: Colors.purple,
              onPressed: busy ? null : _goToMyProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final bool isLoading;

  const _StatusBanner({
    required this.message,
    required this.isError,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final bg    = isError ? Colors.red.shade100   : Colors.blue.shade100;
    final fg    = isError ? Colors.red            : Colors.blue;
    final textC = isError ? Colors.red.shade900   : Colors.blue.shade900;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bg,
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline,
              color: fg, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: textC, fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          if (isLoading) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(description,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
      ],
    );
  }
}

class _AnalyzeRow extends StatelessWidget {
  final String label;
  final AiProvider selectedAi;
  final VoidCallback? onPressed;
  final VoidCallback? onAiTap;

  const _AnalyzeRow({
    required this.label,
    required this.selectedAi,
    required this.onPressed,
    required this.onAiTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.analytics),
                  label: Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'AI: ${selectedAi.label}',
              child: InkWell(
                onTap: onAiTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: selectedAi.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selectedAi.color.withValues(alpha: 0.4),
                        width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      selectedAi.avatarLetter,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: selectedAi.color),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            'Using ${selectedAi.label} · ${selectedAi.subtitle}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: color.withValues(alpha: 0.9))),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Soon',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
    );
  }
}
