import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';
import '../services/facebook_service.dart';
import '../services/comment_parser_service.dart';
import '../services/profile_storage_service.dart';
import '../services/ocean_analyzer_service.dart';
import '../models/user_profile.dart';
import '../models/person_score.dart';
import '../models/ocean_scores.dart';
import '../config/facebook_config.dart';
import '../utils/android_webview_post_loader.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'profile_list_screen.dart';

// ── AI provider enum ──────────────────────────────────────────────────────────

enum AiProvider { chatGpt, gemini, claude, deepSeek }

extension AiProviderInfo on AiProvider {
  String get label {
    switch (this) {
      case AiProvider.chatGpt:  return 'ChatGPT';
      case AiProvider.gemini:   return 'Gemini';
      case AiProvider.claude:   return 'Claude';
      case AiProvider.deepSeek: return 'DeepSeek';
    }
  }

  String get subtitle {
    switch (this) {
      case AiProvider.chatGpt:  return 'GPT-4o mini';
      case AiProvider.gemini:   return 'Not implemented';
      case AiProvider.claude:   return 'Not implemented';
      case AiProvider.deepSeek: return 'Not implemented';
    }
  }

  bool get isAvailable => this == AiProvider.chatGpt;

  // Simple letter-based avatar colors
  Color get color {
    switch (this) {
      case AiProvider.chatGpt:  return const Color(0xFF10A37F); // OpenAI green
      case AiProvider.gemini:   return const Color(0xFF4285F4); // Google blue
      case AiProvider.claude:   return const Color(0xFFD97706); // Anthropic amber
      case AiProvider.deepSeek: return const Color(0xFF6366F1); // indigo
    }
  }

  String get avatarLetter {
    switch (this) {
      case AiProvider.chatGpt:  return 'G';
      case AiProvider.gemini:   return 'G';
      case AiProvider.claude:   return 'C';
      case AiProvider.deepSeek: return 'D';
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FacebookService _facebookService = FacebookService();
  final CommentParserService _parserService = CommentParserService();
  final ProfileStorageService _profileStorage = ProfileStorageService();
  final OceanAnalyzerService _oceanAnalyzer = OceanAnalyzerService();

  AiProvider _selectedAi = AiProvider.chatGpt;

  static const String _fetchCooldownKey   = 'last_fetch_time';
  static const String _analyzeCooldownKey = 'last_analyze_time';
  static const Duration _fetchCooldown    = Duration(hours: 1);
  static const Duration _analyzeCooldown  = Duration(hours: 4);

  DateTime? _lastFetchTime;
  DateTime? _lastAnalyzeTime;

  Duration? get _fetchRemaining {
    if (_lastFetchTime == null) return null;
    final remaining = _fetchCooldown - DateTime.now().difference(_lastFetchTime!);
    return remaining.isNegative ? null : remaining;
  }

  Duration? get _analyzeRemaining {
    if (_lastAnalyzeTime == null) return null;
    final remaining = _analyzeCooldown - DateTime.now().difference(_lastAnalyzeTime!);
    return remaining.isNegative ? null : remaining;
  }

  String _formatDuration(Duration d) {
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
    // Refresh countdown display every second
    Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadCooldowns() async {
    final prefs = await SharedPreferences.getInstance();
    final fetchMs   = prefs.getInt(_fetchCooldownKey);
    final analyzeMs = prefs.getInt(_analyzeCooldownKey);
    if (mounted) {
      setState(() {
        _lastFetchTime   = fetchMs   != null ? DateTime.fromMillisecondsSinceEpoch(fetchMs)   : null;
        _lastAnalyzeTime = analyzeMs != null ? DateTime.fromMillisecondsSinceEpoch(analyzeMs) : null;
      });
    }
  }

  Future<void> _saveFetchTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(_fetchCooldownKey, now.millisecondsSinceEpoch);
    if (mounted) setState(() => _lastFetchTime = now);
  }

  Future<void> _saveAnalyzeTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(_analyzeCooldownKey, now.millisecondsSinceEpoch);
    if (mounted) setState(() => _lastAnalyzeTime = now);
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _facebookService.isLoggedIn();
    if (!isLoggedIn && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ── AI selector dialog ────────────────────────────────────────────────────

  void _showAiSelector() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined),
            SizedBox(width: 10),
            Text('Select AI Model'),
          ],
        ),
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
                  child: Text(
                    ai.avatarLetter,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  ai.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ai.isAvailable ? null : Colors.grey,
                  ),
                ),
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
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Soon',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ),
                selected: selected,
                selectedTileColor: ai.color.withOpacity(0.08),
                onTap: () {
                  if (!ai.isAvailable) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('${ai.label} is not implemented yet'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  setState(() => _selectedAi = ai);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _fetchPosts() async {
    final provider = Provider.of<AppProvider>(context, listen: false);

    provider.setLoading(true);
    provider.setStatus('Retrieving your Facebook posts…');

    _facebookService.webViewContext = context;

    if (Platform.isAndroid) {
      final token = await _facebookService.getAccessToken();
      if (token != null) {
        await AndroidWebviewPostLoader.warmUpWebViewSession(
          context,
          FacebookConfig.getAppId(),
          token,
        );
      }
    }

    try {
      final result = await _facebookService.fetchAndSaveAccessiblePosts(
        onProgress: (current, total) {
          provider.setStatus('Downloading posts: $current of $total');
        },
      );
      provider.setStatus(
          '${result['savedCount']} posts downloaded successfully.');
      await _saveFetchTime();
    } catch (e) {
      provider.setStatus('Failed to retrieve posts. Please try again.', isError: true);
    } finally {
      provider.setLoading(false);
    }
  }

  Future<void> _analyzeComments() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final userId = await _facebookService.getCurrentUserId();

    if (userId == null) {
      provider.setStatus('User session not found. Please log in again.', isError: true);
      return;
    }

    provider.setLoading(true);
    provider.setStatus('Starting personality analysis with ${_selectedAi.label}…');

    try {
      final scores = await _parserService.processAllCommentsForUser(
        userId: userId,
        userName: (await _profileStorage.loadUserProfile(userId))?.name,
        onStatusUpdate: (message, {bool isError = false}) {
          provider.setStatus(message, isError: isError);
        },
      );

      provider.setPersonScores(scores);
      await _saveToUserProfile(userId, scores);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              userId: userId,
              initialTabIndex: 0, // open on Overview tab
            ),
          ),
        );
      }

      provider.setStatus('Analysis complete. Your personality profile has been updated.');
      await _saveAnalyzeTime();
    } catch (e) {
      provider.setStatus('Analysis failed. Please try again.', isError: true);
    } finally {
      provider.setLoading(false);
    }
  }

  Future<void> _saveToUserProfile(
      String userId, List<PersonScore> scores) async {
    final userData = await _facebookService.getCurrentUser();
    final existingProfile = await _profileStorage.loadUserProfile(userId);

    // Name priority: already-saved real name → Graph API → fallback
    final name = (existingProfile?.name != null &&
                existingProfile!.name.isNotEmpty &&
                existingProfile.name != 'User')
        ? existingProfile.name
        : (userData?['name'] as String? ?? existingProfile?.name ?? 'User');

    final email =
        userData?['email'] as String? ?? existingProfile?.email;
    final pictureUrl =
        (userData?['picture']?['data']?['url'] as String?) ??
            existingProfile?.profilePictureUrl;

    final Map<String, int> personScoresMap = {
      for (final score in scores) score.name: score.score
    };

    OceanScores oceanScores;
    if (existingProfile != null && existingProfile.personScores.isNotEmpty) {
      final mergedScores = {
        ...existingProfile.personScores,
        ...personScoresMap
      };
      oceanScores = await _oceanAnalyzer.analyzeOceanTraits(mergedScores);
    } else {
      oceanScores = existingProfile?.oceanScores ??
          OceanScores(
            openness: 50.0,
            conscientiousness: 50.0,
            extraversion: 50.0,
            agreeableness: 50.0,
            neuroticism: 50.0,
          );
    }

    final analyzedPostIds = existingProfile?.analyzedPostIds ?? [];
    final posts = await _profileStorage.getUserPosts(userId);
    final newPostIds = posts
        .map((f) => f.path.split('/').last.replaceAll('.html', ''))
        .toList();

    final userProfile = UserProfile(
      userId: userId,
      name: name,
      email: email,
      profilePictureUrl: pictureUrl,
      oceanScores: oceanScores,
      personScores: personScoresMap,
      favorites: existingProfile?.favorites,
      blacklist: existingProfile?.blacklist,
      analyzedPostIds: {...analyzedPostIds, ...newPostIds}.toList(),
      lastAnalyzed: DateTime.now(),
      totalCommentsAnalyzed:
          scores.length + (existingProfile?.totalCommentsAnalyzed ?? 0),
    );

    await _profileStorage.saveUserProfile(userProfile);
  }

  Future<void> _logout() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await _facebookService.logout();
    provider.clearAll();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _navigateToProfileList() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileListScreen()),
    );
  }

  void _navigateToMyProfile() async {
    final userId = await _facebookService.getCurrentUserId();
    if (userId != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Love Assistant'),
            actions: [
              if (Platform.isWindows)
                IconButton(
                  icon: const Icon(Icons.timer_off_outlined),
                  tooltip: 'Reset Cooldowns',
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove(_fetchCooldownKey);
                    await prefs.remove(_analyzeCooldownKey);
                    setState(() {
                      _lastFetchTime = null;
                      _lastAnalyzeTime = null;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cooldowns reset.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.people),
                onPressed: _navigateToProfileList,
                tooltip: 'All Profiles',
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
            ],
          ),
          body: Column(
            children: [
              // Status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: provider.isError
                    ? Colors.red.shade100
                    : Colors.blue.shade100,
                child: Row(
                  children: [
                    Icon(
                      provider.isError ? Icons.error : Icons.info,
                      color: provider.isError ? Colors.red : Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        provider.statusMessage,
                        style: TextStyle(
                          color: provider.isError
                              ? Colors.red.shade900
                              : Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (provider.isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite,
                            size: 80, color: Colors.pink.shade300),
                        const SizedBox(height: 24),
                        const Text(
                          'Love Assistant',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Analyze comments and discover personality insights',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                _buildActionButton(
                                  icon: Icons.download,
                                  label: _fetchRemaining != null
                                      ? 'Fetch Posts (${_formatDuration(_fetchRemaining!)})'
                                      : 'Fetch Posts',
                                  onPressed: provider.isLoading || _fetchRemaining != null
                                      ? null
                                      : _fetchPosts,
                                  color: Colors.blue,
                                  description: _fetchRemaining != null
                                      ? 'Available in ${_formatDuration(_fetchRemaining!)}'
                                      : 'Download your Facebook posts',
                                ),
                                const SizedBox(height: 16),

                                // ── Analyze row with AI selector ──────────
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 50,
                                            child: ElevatedButton.icon(
                                              onPressed: provider.isLoading || _analyzeRemaining != null
                                                  ? null
                                                  : _analyzeComments,
                                              icon: const Icon(Icons.analytics),
                                              label: Text(
                                                _analyzeRemaining != null
                                                    ? 'Analyze (${_formatDuration(_analyzeRemaining!)})'
                                                    : 'Analyze Comments',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                              style:
                                                  ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.green,
                                                foregroundColor:
                                                    Colors.white,
                                                shape:
                                                    RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          25),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // AI selector button
                                        Tooltip(
                                          message:
                                              'AI: ${_selectedAi.label}',
                                          child: InkWell(
                                            onTap: provider.isLoading
                                                ? null
                                                : _showAiSelector,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: _selectedAi.color
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        12),
                                                border: Border.all(
                                                  color: _selectedAi.color
                                                      .withOpacity(0.4),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  _selectedAi.avatarLetter,
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color:
                                                        _selectedAi.color,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16),
                                      child: Text(
                                        'Using ${_selectedAi.label} · ${_selectedAi.subtitle}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                _buildActionButton(
                                  icon: Icons.psychology,
                                  label: 'View My Profile',
                                  onPressed: provider.isLoading
                                      ? null
                                      : _navigateToMyProfile,
                                  color: Colors.purple,
                                  description:
                                      'See your personality insights',
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lightbulb,
                                  color: Colors.orange.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your comments will be analyzed to create a Big Five personality profile and track how you rate others.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(
              label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}