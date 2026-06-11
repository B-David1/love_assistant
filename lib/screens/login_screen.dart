import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ocean_scores.dart';
import '../models/user_profile.dart';
import '../providers/app_provider.dart';
import '../services/facebook_service.dart';
import '../services/profile_storage_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _facebookService = FacebookService();
  final _profileStorage = ProfileStorageService();

  bool _isLoading = false;
  bool _termsAccepted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final loggedIn = await _facebookService.isLoggedIn();
    if (!loggedIn || !mounted) return;
    await _performLogin();
  }

  Future<void> _performLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userData = await _facebookService.login();
      if (userData == null) {
        await _facebookService.logout();
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;
      Provider.of<AppProvider>(context, listen: false).setUserData(userData);
      await _ensureProfileExists(userData);
      _goHome();
    } on Exception catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isLoading = false;
        _errorMessage = message.contains('cancelled') ? null : message;
      });
    }
  }

  Future<void> _ensureProfileExists(Map<String, dynamic> userData) async {
    final userId = userData['id'] as String?;
    if (userId == null) return;

    final name = userData['name'] as String?;
    final email = userData['email'] as String?;
    final picture = userData['picture']?['data']?['url'] as String?;

    var profile = await _profileStorage.loadUserProfile(userId);

    if (profile == null) {
      profile = UserProfile(
        userId: userId,
        name: name ?? 'User',
        email: email,
        profilePictureUrl: picture,
        oceanScores: OceanScores(
          openness: 50,
          conscientiousness: 50,
          extraversion: 50,
          agreeableness: 50,
          neuroticism: 50,
        ),
        personScores: {},
        analyzedPostIds: [],
        lastAnalyzed: DateTime.now(),
        totalCommentsAnalyzed: 0,
      );
      await _profileStorage.saveUserProfile(profile);
    } else if (name != null &&
        (profile.name == 'User' ||
            profile.name.isEmpty ||
            profile.profilePictureUrl == null)) {
      final patched = UserProfile(
        userId: profile.userId,
        name: name,
        email: email ?? profile.email,
        profilePictureUrl: picture ?? profile.profilePictureUrl,
        oceanScores: profile.oceanScores,
        personScores: profile.personScores,
        favorites: profile.favorites,
        blacklist: profile.blacklist,
        analyzedPostIds: profile.analyzedPostIds,
        lastAnalyzed: profile.lastAnalyzed,
        totalCommentsAnalyzed: profile.totalCommentsAnalyzed,
        quizDeltas: profile.quizDeltas,
        programStartDate: profile.programStartDate,
        lastQuizDate: profile.lastQuizDate,
        quizDaysCompleted: profile.quizDaysCompleted,
        hasBeenAnalyzed: profile.hasBeenAnalyzed,
      );
      await _profileStorage.saveUserProfile(patched);
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _onLoginPressed() async {
    if (!_termsAccepted) {
      setState(
          () => _errorMessage = 'Please accept the Terms & Conditions to continue.');
      return;
    }
    await _performLogin();
  }

  Future<void> _openTerms() async {
    const url = 'https://example.com/terms';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _showTermsDialog();
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'By using Love Assistant, you agree that your Facebook posts and '
            'comments will be processed using AI to generate a personality '
            'profile. Your data is stored privately and never shared with '
            'third parties without your consent.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.pink.shade300, Colors.purple.shade400],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 24),
                      _buildHeadline(),
                      const SizedBox(height: 32),
                      if (_errorMessage != null) ...[
                        _ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      _buildTermsRow(),
                      const SizedBox(height: 20),
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else
                        _buildButtons(),
                      const SizedBox(height: 20),
                      Text(
                        'Your privacy is important to us',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.pink.shade300, Colors.purple.shade400],
        ),
      ),
      child: const Icon(Icons.favorite, size: 56, color: Colors.white),
    );
  }

  Widget _buildHeadline() {
    return Column(
      children: [
        const Text(
          'Love Assistant',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect with Facebook to analyse your posts\nand discover personality insights',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildTermsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _termsAccepted,
          activeColor: Colors.pink,
          onChanged: (v) => setState(() => _termsAccepted = v ?? false),
        ),
        Expanded(
          child: GestureDetector(
            onTap: _openTerms,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87),
                children: [
                  const TextSpan(text: 'I accept the '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: TextStyle(
                      color: Colors.pink.shade400,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        _SocialButton(
          icon: Icons.facebook,
          label: 'Continue with Facebook',
          color: const Color(0xFF1877F2),
          onPressed: _onLoginPressed,
        ),
        const SizedBox(height: 12),
        _SocialButton(
          icon: Icons.camera_alt,
          label: 'Continue with Instagram',
          color: Colors.grey.shade400,
          comingSoon: true,
        ),
        const SizedBox(height: 12),
        _SocialButton(
          icon: Icons.language,
          label: 'Continue with Twitter / X',
          color: Colors.grey.shade400,
          comingSoon: true,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool comingSoon;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Stack(
        children: [
          ElevatedButton.icon(
            onPressed: comingSoon ? null : onPressed,
            icon: Icon(icon),
            label: Text(label, style: const TextStyle(fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white70,
              disabledBackgroundColor: color,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
            ),
          ),
          if (comingSoon)
            Positioned(
              top: 4,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
