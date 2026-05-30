import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import '../models/facebook_post.dart';
import '../config/facebook_config.dart';
import '../utils/webview_post_loader.dart';
import '../utils/android_webview_post_loader.dart';
import 'token_storage_service.dart';
import 'profile_storage_service.dart';

class FacebookService {
  final TokenStorageService _tokenStorage = TokenStorageService();
  final ProfileStorageService _profileStorage = ProfileStorageService();

  String? _cachedAccessToken;
  Map<String, dynamic>? _currentUserData;

  FacebookService() {
    _initializeFacebookSDK();
  }

  void _initializeFacebookSDK() {
    debugPrint('Initializing Facebook Service...');
    debugPrint('App ID: ${FacebookConfig.getAppId()}');
    debugPrint('Using credentials from config (hardcoded or .env)');
  }

  // ─── Auth ────────────────────────────────────────────────────────────────

  Future<bool> isLoggedIn() async {
    if (Platform.isWindows) {
      try {
        _cachedAccessToken = FacebookConfig.getHardcodedUserToken();
        debugPrint('Windows: Using hardcoded token');
        return true;
      } catch (_) {
        debugPrint('Windows: Failed to load hardcoded token');
        return false;
      }
    }

    final storedToken = await _tokenStorage.getAccessToken();
    if (storedToken != null) {
      _cachedAccessToken = storedToken;
      debugPrint('Non-Windows: Using stored token');
      return true;
    }

    debugPrint('Non-Windows: No stored token found, login required');
    return false;
  }

  Future<Map<String, dynamic>?> login() async {
    if (Platform.isWindows) {
      try {
        _cachedAccessToken = FacebookConfig.getHardcodedUserToken();
        final userData = await _fetchUserData();
        _currentUserData = userData;

        if (userData != null) {
          debugPrint('Windows: Login successful with hardcoded credentials!');
          debugPrint('User: ${userData['name']}');
          return userData;
        }

        debugPrint('Windows: Failed to fetch user data with hardcoded token');
        return null;
      } catch (e) {
        debugPrint('Windows: Login error with hardcoded credentials: $e');
        return null;
      }
    }

    try {
      debugPrint('Starting Facebook OAuth login...');
      debugPrint('Using App ID: ${FacebookConfig.getAppId()}');

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'user_posts'],
      );

      debugPrint('Login result status: ${result.status}');

      if (result.status == LoginStatus.success) {
        // v7.x: AccessToken is abstract; cast to ClassicToken for full data.
        final accessToken = result.accessToken!;
        final tokenString = accessToken.tokenString;
        _cachedAccessToken = tokenString;

        debugPrint('Access token obtained: ${tokenString.substring(0, 20)}...');

        // ClassicToken carries userId, expires, etc.
        String? userId;
        DateTime? expires;
        if (accessToken is ClassicToken) {
          userId = accessToken.userId;
          expires = accessToken.expires;
          debugPrint('User ID: $userId');
          debugPrint('Expires: $expires');
        }

        final userData = await _fetchUserData();

        await _tokenStorage.saveFacebookAuthData(
          accessToken: tokenString,
          userId: userId ?? userData?['id'] ?? '',
          userName: userData?['name'],
          userEmail: userData?['email'],
          // Fall back to 60-day expiry if expires is null (LimitedToken case)
          expiryDate: expires ?? DateTime.now().add(const Duration(days: 60)),
          permissions: const [], // grantedPermissions removed in v7.x
        );

        _currentUserData = userData;
        debugPrint('Login successful! User: ${userData?['name']}');
        return userData;
      } else if (result.status == LoginStatus.cancelled) {
        debugPrint('Login cancelled by user');
        throw Exception('Login cancelled');
      } else {
        debugPrint('Login failed: ${result.message}');
        throw Exception(result.message ?? 'Login failed');
      }
    } catch (e) {
      debugPrint('Facebook login error: $e');
      rethrow;
    }
  }

  /// Fetches user data for a known userId using the stored access token.
  /// Used after Android WebView login where we have the userId from cookies
  /// but need the name/picture from the Graph API.
  Future<Map<String, dynamic>?> fetchUserDataById(String userId) async {
    try {
      final token = await getAccessToken();
      if (token == null) return null;

      final url = Uri.parse(
        'https://graph.facebook.com/$userId'
        '?fields=id,name,email,picture'
        '&access_token=$token',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!data.containsKey('error')) return data;
      }
    } catch (e) {
      debugPrint('fetchUserDataById error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchUserData() async {
    try {
      final token = await getAccessToken();
      if (token == null) return null;

      final url = Uri.parse(
        'https://graph.facebook.com/me'
        '?fields=id,name,email,picture'
        '&access_token=$token',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('error')) {
          debugPrint('Error fetching user data: ${data['error']['message']}');
          return null;
        }
        debugPrint('User data fetched successfully');
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;

    if (Platform.isWindows) {
      _cachedAccessToken = FacebookConfig.getHardcodedUserToken();
      return _cachedAccessToken;
    }

    _cachedAccessToken = await _tokenStorage.getAccessToken();

    if (_cachedAccessToken == null) {
      // v7.x: use tokenString instead of .token
      final accessToken = await FacebookAuth.instance.accessToken;
      if (accessToken != null) {
        // For ClassicToken check expiry; LimitedToken has no expiry field.
        final expired = accessToken is ClassicToken
            ? (accessToken.expires.isBefore(DateTime.now()))
            : false;
        if (!expired) {
          _cachedAccessToken = accessToken.tokenString;
        }
      }
    }

    return _cachedAccessToken;
  }

  Future<void> logout() async {
    if (Platform.isWindows) {
      _cachedAccessToken = null;
      _currentUserData = null;
      debugPrint('Windows: Logged out (cleared cache)');
      return;
    }

    try {
      await FacebookAuth.instance.logOut();
      await _tokenStorage.clearAllTokens();
      _cachedAccessToken = null;
      _currentUserData = null;
      debugPrint('Logged out successfully');
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  Future<bool> validateAndRestoreSession() async {
    if (Platform.isWindows) {
      _cachedAccessToken = FacebookConfig.getHardcodedUserToken();
      debugPrint('Windows: Session always valid (hardcoded token)');
      return true;
    }

    try {
      final accessToken = await FacebookAuth.instance.accessToken;

      if (accessToken != null) {
        // v7.x: isExpired removed; check manually for ClassicToken only.
        if (accessToken is ClassicToken) {
          final expires = accessToken.expires;
          if (expires.isBefore(DateTime.now())) {
            debugPrint('Token is expired, logging out');
            await logout();
            return false;
          }
        }
        _cachedAccessToken = accessToken.tokenString;
        return true;
      }

      final storedToken = await _tokenStorage.getAccessToken();
      if (storedToken != null) {
        final isValid = await _validateToken(storedToken);
        if (isValid) {
          _cachedAccessToken = storedToken;
          return true;
        } else {
          await _tokenStorage.clearAllTokens();
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error validating session: $e');
      return false;
    }
  }

  Future<bool> _validateToken(String token) async {
    try {
      final url = Uri.parse('https://graph.facebook.com/me?access_token=$token');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return !data.containsKey('error');
      }
      return false;
    } catch (e) {
      debugPrint('Token validation error: $e');
      return false;
    }
  }

  // ─── Posts ───────────────────────────────────────────────────────────────

  Future<List<FacebookPost>> fetchPosts({int limit = 100}) async {
    final isValid = await validateAndRestoreSession();
    if (!isValid) throw Exception('Not logged in or session expired');

    try {
      final token = await getAccessToken();

      final url = Uri.parse(
        'https://graph.facebook.com/v18.0/me/posts'
        '?fields=id,message,created_time,story,permalink_url'
        '&limit=$limit'
        '&access_token=$token',
      );

      debugPrint('Fetching posts...');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('error')) {
          final error = data['error'];
          debugPrint('Facebook API Error: ${error['message']}');
          if (error['code'] == 190) {
            await logout();
            throw Exception('Session expired. Please login again.');
          }
          throw Exception('Facebook API Error: ${error['message']}');
        }

        final posts = (data['data'] as List)
            .map((post) => FacebookPost.fromJson(post))
            .toList();

        debugPrint('Fetched ${posts.length} posts');
        return posts;
      } else {
        debugPrint('HTTP Error: ${response.statusCode}');
        throw Exception('Failed to fetch posts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      rethrow;
    }
  }

  // BuildContext reference so Android WebView can attach to the Overlay.
  // Set this once (e.g. in HomeScreen.initState) before fetching posts.
  BuildContext? webViewContext;

  /// Fetches a post's HTML with JavaScript executed via a WebView.
  /// Windows uses webview_windows; Android uses webview_flutter (desktop UA).
  /// Falls back to a plain HTTP GET on other platforms (iOS, macOS, Linux).
  Future<String?> fetchPostHTML(String postId) async {
    final actualPostId = postId.contains('_') ? postId.split('_')[1] : postId;
    final postUrl = 'https://www.facebook.com/$actualPostId';

    if (Platform.isWindows) {
      return _fetchPostHTMLWithWebView(postUrl);
    } else if (Platform.isAndroid) {
      return _fetchPostHTMLWithAndroidWebView(postUrl);
    } else {
      return _fetchPostHTMLPlain(postUrl);
    }
  }

  Future<String?> _fetchPostHTMLWithWebView(String url) async {
    debugPrint('WebView fetch: $url');
    try {
      final html = await WebviewPostLoader.fetchRenderedHTML(url);

      if (html == null) {
        debugPrint('WebView returned null for $url');
        return null;
      }

      if (_isAccessDeniedPage(html)) {
        debugPrint('Access denied / login wall detected for $url');
        return null;
      }

      debugPrint('WebView fetch succeeded (${html.length} chars)');
      return html;
    } catch (e) {
      debugPrint('WebView fetch error for $url: $e');
      return null;
    }
  }

  Future<String?> _fetchPostHTMLPlain(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        final html = response.body;
        if (_isAccessDeniedPage(html)) return null;
        return html;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching post HTML (plain): $e');
      return null;
    }
  }

  /// Loads a Facebook URL with the access token embedded so the WebView
  /// cookie store gets a real session before scraping begins.
  Future<String?> _fetchPostHTMLWithAndroidWebView(String url) async {
    debugPrint('Android WebView fetch: $url');
    final ctx = webViewContext;
    if (ctx == null || !ctx.mounted) {
      debugPrint('Android WebView: no BuildContext, falling back to plain HTTP');
      return _fetchPostHTMLPlain(url);
    }

    try {
      final html = await AndroidWebviewPostLoader.fetchRenderedHTML(
        url,
        context: ctx,
      );

      if (html == null) {
        debugPrint('Android WebView returned null for $url');
        return null;
      }

      if (_isAccessDeniedPage(html)) {
        debugPrint('Access denied for $url');
        return null;
      }

      debugPrint('Android WebView fetch succeeded (${html.length} chars)');
      return html;
    } catch (e) {
      debugPrint('Android WebView fetch error for $url: $e');
      return null;
    }
  }

  bool _isAccessDeniedPage(String html) {
    final hasContent = html.contains('og:type') ||
        html.contains('story_attachment') ||
        html.contains('userContent') ||
        html.contains('data-testid') ||
        html.length > 50000;
    if (hasContent) return false;
    return true;
  }

  // ─── Fetch & Save ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchAndSaveAccessiblePosts({
    Function(int current, int total)? onProgress,
  }) async {
    final posts = await fetchPosts();

    final userId = await getCurrentUserId();
    if (userId == null) throw Exception('User ID not found');

    final postsWithMessages = posts
        .where((p) => p.message != null && p.message!.isNotEmpty)
        .toList();

    final totalWithMessages = postsWithMessages.length;

    int completed = 0;
    int savedCount = 0;

    // On Android the WebView loader must run one at a time — spawning dozens
    // of WebViews simultaneously causes all but a few to silently fail.
    for (var i = 0; i < postsWithMessages.length; i++) {
      final post = postsWithMessages[i];

      final html = await fetchPostHTML(post.id);
      if (html != null) {
        await _profileStorage.savePostHTML(userId, post.id, html);
        savedCount++;
        debugPrint('Saved HTML for post ${i + 1}/$totalWithMessages: ${post.id}');
      } else {
        debugPrint('No HTML for post ${i + 1}/$totalWithMessages: ${post.id}');
      }

      completed++;
      onProgress?.call(completed, totalWithMessages);
    }

    debugPrint(
      'Saved $savedCount HTML files out of ${posts.length} total posts for user $userId',
    );

    return {
      'totalPosts': posts.length,
      'postsWithMessages': totalWithMessages,
      'savedCount': savedCount,
    };
  }

  // ─── User ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_currentUserData != null) return _currentUserData;

    if (Platform.isWindows) {
      final userData = await _fetchUserData();
      _currentUserData = userData;
      return userData;
    }

    final storedData = await _tokenStorage.getUserData();
    if (storedData['userId'] != null) {
      _currentUserData = storedData;
      return storedData;
    }

    return await _fetchUserData();
  }

  /// Returns the user ID regardless of whether the map uses
  /// the Graph API key ('id') or the token-storage key ('userId').
  Future<String?> getCurrentUserId() async {
    final userData = await getCurrentUser();
    if (userData == null) return null;
    return (userData['id'] ?? userData['userId']) as String?;
  }
}