import '../models/user_profile.dart';
import '../models/ocean_scores.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final FacebookService _facebookService = FacebookService();
  final ProfileStorageService _profileStorage = ProfileStorageService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();
  }

  Future<void> _checkExistingLogin() async {
    try {
      final isLoggedIn = await _facebookService.isLoggedIn();
      if (isLoggedIn && mounted) {
        _autoLogin();
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
    }
  }

  Future<void> _autoLogin() async {
    setState(() => _isLoading = true);

    try {
      final userData = await _facebookService.login();

      // Token was invalid / expired (e.g. error 190) — clear it and show
      // the login screen so the user can log in fresh.
      if (userData == null) {
        await _facebookService.logout();
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        final provider = Provider.of<AppProvider>(context, listen: false);
        provider.setUserData(userData);

        // Create or load user profile
        final userId = userData['id'];
        if (userId != null) {
          final freshName = userData['name'] as String?;
          final freshEmail = userData['email'] as String?;
          final freshPicture = userData['picture']?['data']?['url'] as String?;

          var profile = await _profileStorage.loadUserProfile(userId);
          if (profile == null) {
            // Create new profile
            profile = UserProfile(
              userId: userId,
              name: freshName ?? 'User',
              email: freshEmail,
              profilePictureUrl: freshPicture,
              oceanScores: OceanScores(
                openness: 50.0,
                conscientiousness: 50.0,
                extraversion: 50.0,
                agreeableness: 50.0,
                neuroticism: 50.0,
              ),
              personScores: {},
              analyzedPostIds: [],
              lastAnalyzed: DateTime.now(),
              totalCommentsAnalyzed: 0,
            );
          } else if (freshName != null &&
              (profile.name == 'User' ||
                  profile.name.isEmpty ||
                  profile.profilePictureUrl == null)) {
            // Existing profile has stale/missing identity data — patch it
            profile = UserProfile(
              userId: profile.userId,
              name: freshName,
              email: freshEmail ?? profile.email,
              profilePictureUrl: freshPicture ?? profile.profilePictureUrl,
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
            );
          }
          await _profileStorage.saveUserProfile(profile);
        }

        _navigateToHome();
      }
    } catch (e) {
      debugPrint('Auto-login error: $e');
      // Clear any bad token so the user sees the login screen next time
      await _facebookService.logout();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openTermsAndConditions() async {
    const termsUrl = 'https://example.com/terms';
    try {
      if (await canLaunchUrl(Uri.parse(termsUrl))) {
        await launchUrl(Uri.parse(termsUrl), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showTermsDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        _showTermsDialog();
      }
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Terms & Conditions'),
          content: const SingleChildScrollView(
            child: Text(
              'By using Love Assistant, you agree to our terms and conditions. '
              'This app analyzes your Facebook posts and comments using ChatGPT AI. '
              'Your data is processed securely and stored privately. '
              'We do not share your personal information with third parties without consent.'
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _login() async {
    if (!_termsAccepted) {
      setState(() {
        _errorMessage = 'Please accept the terms and conditions to continue';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userData = await _facebookService.login();

      if (userData != null && mounted) {
        final provider = Provider.of<AppProvider>(context, listen: false);
        provider.setUserData(userData);
        
        // Create or load user profile
        final userId = userData['id'];
        if (userId != null) {
          final freshName = userData['name'] as String?;
          final freshEmail = userData['email'] as String?;
          final freshPicture = userData['picture']?['data']?['url'] as String?;

          var profile = await _profileStorage.loadUserProfile(userId);
          if (profile == null) {
            profile = UserProfile(
              userId: userId,
              name: freshName ?? 'User',
              email: freshEmail,
              profilePictureUrl: freshPicture,
              oceanScores: OceanScores(
                openness: 50.0,
                conscientiousness: 50.0,
                extraversion: 50.0,
                agreeableness: 50.0,
                neuroticism: 50.0,
              ),
              personScores: {},
              analyzedPostIds: [],
              lastAnalyzed: DateTime.now(),
              totalCommentsAnalyzed: 0,
            );
          } else if (freshName != null && (profile.name == 'User' || profile.name.isEmpty || profile.profilePictureUrl == null)) {
            profile = UserProfile(
              userId: profile.userId,
              name: freshName,
              email: freshEmail ?? profile.email,
              profilePictureUrl: freshPicture ?? profile.profilePictureUrl,
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
            );
          }
          await _profileStorage.saveUserProfile(profile);
        }

        _navigateToHome();
      } else {
        setState(() {
          _errorMessage = 'Login failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('cancelled')) {
          _errorMessage = 'Login cancelled';
        } else {
          _errorMessage = 'Error: ${e.toString()}';
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.pink.shade300,
              Colors.purple.shade400,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(24),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.pink.shade300,
                            Colors.purple.shade400,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Love Assistant',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    if (true)
                      const Text(
                        'Connect with Facebook to analyze your posts\nand discover your personality insights',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    Row(
                      children: [
                        Checkbox(
                          value: _termsAccepted,
                          onChanged: (value) {
                            setState(() {
                              _termsAccepted = value ?? false;
                            });
                          },
                          activeColor: Colors.pink,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openTermsAndConditions,
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'I accept the ',
                                    style: TextStyle(color: Colors.black87),
                                  ),
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
                    ),
                    
                    const SizedBox(height: 16),
                    
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Column(
                        children: [
                          // Facebook Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _login,
                              icon: const Icon(Icons.facebook),
                              label: const Text(
                                'Continue with Facebook',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1877F2),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Instagram Button (Disabled)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: Stack(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text(
                                    'Continue with Instagram',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.grey.shade600,
                                    disabledForegroundColor: Colors.grey.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade400,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Coming Soon',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Twitter Button (Disabled)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: Stack(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.language),
                                  label: const Text(
                                    'Continue with Twitter/X',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    foregroundColor: Colors.grey.shade600,
                                    disabledForegroundColor: Colors.grey.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade400,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Coming Soon',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                    const SizedBox(height: 16),
                    
                    Text(
                      'Your privacy is important to us',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}