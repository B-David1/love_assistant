import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;

import '../config/facebook_config.dart';
import '../models/facebook_post.dart';
import '../utils/android_webview_post_loader.dart';
import '../utils/webview_post_loader.dart';
import 'profile_storage_service.dart';
import 'token_storage_service.dart';

class FacebookService {
  FacebookService();

  final TokenStorageService _tokenStorage = TokenStorageService();
  final ProfileStorageService _profileStorage = ProfileStorageService();

  String? _cachedAccessToken;
  Map<String, dynamic>? _currentUserData;

  BuildContext? webViewContext;

  Future<bool> isLoggedIn() async {
    if (Platform.isWindows) {
      _cachedAccessToken = FacebookConfig.getHardcodedUserToken();
      return true;
    }

    final stored = await _tokenStorage.getAccessToken();
    if (stored != null) {
      _cachedAccessToken = stored;
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> login() async {
    if (Platform.isWindows) {
      return _windowsLogin();
    }
    return _oauthLogin();
  }

  Future<Map<String, dynamic>?> _windowsLogin() async {
    _cachedAccessToken = FacebookConfig.getHardcodedUserToken();
    final userData = await _fetchUserData();
    _currentUserData = userData;
    if (userData != null) debugPrint('Facebook: logged in as ${userData['name']}');
    return userData;
  }

  Future<Map<String, dynamic>?> _oauthLogin() async {
    final result = await FacebookAuth.instance.login(
      permissions: ['email', 'user_posts'],
    );

    if (result.status == LoginStatus.cancelled) throw Exception('Login cancelled');
    if (result.status != LoginStatus.success) {
      throw Exception(result.message ?? 'Login failed');
    }

    final accessToken = result.accessToken!;
    _cachedAccessToken = accessToken.tokenString;

    String? userId;
    DateTime? expires;
    if (accessToken is ClassicToken) {
      userId = accessToken.userId;
      expires = accessToken.expires;
    }

    final userData = await _fetchUserData();
    await _tokenStorage.saveFacebookAuthData(
      accessToken: accessToken.tokenString,
      userId: userId ?? userData?['id'] ?? '',
      userName: userData?['name'],
      userEmail: userData?['email'],
      expiryDate: expires ?? DateTime.now().add(const Duration(days: 60)),
      permissions: const [],
    );

    _currentUserData = userData;
    debugPrint('Facebook: logged in as ${userData?['name']}');
    return userData;
  }

  Future<void> logout() async {
    if (!Platform.isWindows) {
      await FacebookAuth.instance.logOut();
      await _tokenStorage.clearAllTokens();
    }
    _cachedAccessToken = null;
    _currentUserData = null;
  }

  Future<bool> validateAndRestoreSession() async {
    if (Platform.isWindows) {
      _cachedAccessToken = FacebookConfig.getHardcodedUserToken();
      return true;
    }

    final sdk = await FacebookAuth.instance.accessToken;
    if (sdk != null) {
      if (sdk is ClassicToken) {
        final expires = sdk.expires;
        if (expires != null && expires.isBefore(DateTime.now())) {
          await logout();
          return false;
        }
      }
      _cachedAccessToken = sdk.tokenString;
      return true;
    }

    final stored = await _tokenStorage.getAccessToken();
    if (stored != null && await _isTokenValid(stored)) {
      _cachedAccessToken = stored;
      return true;
    }

    await _tokenStorage.clearAllTokens();
    return false;
  }

  Future<bool> _isTokenValid(String token) async {
    try {
      final res = await http.get(
          Uri.parse('https://graph.facebook.com/me?access_token=$token'));
      if (res.statusCode != 200) return false;
      final body = json.decode(res.body) as Map<String, dynamic>;
      return !body.containsKey('error');
    } catch (_) {
      return false;
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
      final sdk = await FacebookAuth.instance.accessToken;
      if (sdk != null) {
        final expired = sdk is ClassicToken &&
            (sdk.expires?.isBefore(DateTime.now()) ?? false);
        if (!expired) _cachedAccessToken = sdk.tokenString;
      }
    }
    return _cachedAccessToken;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_currentUserData != null) return _currentUserData;
    if (Platform.isWindows) {
      _currentUserData = await _fetchUserData();
      return _currentUserData;
    }
    final stored = await _tokenStorage.getUserData();
    if (stored['userId'] != null) {
      _currentUserData = stored;
      return stored;
    }
    return _fetchUserData();
  }

  Future<String?> getCurrentUserId() async {
    final user = await getCurrentUser();
    if (user == null) return null;
    return (user['id'] ?? user['userId']) as String?;
  }

  Future<Map<String, dynamic>?> fetchUserDataById(String userId) async {
    final token = await getAccessToken();
    if (token == null) return null;
    return _graphGet('$userId?fields=id,name,email,picture&access_token=$token');
  }

  Future<Map<String, dynamic>?> _fetchUserData() async {
    final token = await getAccessToken();
    if (token == null) return null;
    return _graphGet('me?fields=id,name,email,picture&access_token=$token');
  }

  Future<List<FacebookPost>> fetchPosts({int limit = 100}) async {
    if (!await validateAndRestoreSession()) throw Exception('Not logged in');

    final token = await getAccessToken();
    final data = await _graphGet(
      'v18.0/me/posts'
      '?fields=id,message,created_time,story,permalink_url'
      '&limit=$limit'
      '&access_token=$token',
    );

    if (data == null) throw Exception('Failed to fetch posts');
    if (data.containsKey('error')) {
      final err = data['error'] as Map<String, dynamic>;
      if (err['code'] == 190) {
        await logout();
        throw Exception('Session expired. Please log in again.');
      }
      throw Exception('Facebook API error: ${err['message']}');
    }

    final posts = (data['data'] as List)
        .map((p) => FacebookPost.fromJson(p as Map<String, dynamic>))
        .toList();
    debugPrint('Facebook: fetched ${posts.length} posts');
    return posts;
  }

  Future<Map<String, dynamic>> fetchAndSaveAccessiblePosts({
    void Function(int current, int total)? onProgress,
  }) async {
    final posts = await fetchPosts();
    final userId = await getCurrentUserId();
    if (userId == null) throw Exception('User ID not found');

    final withMessages = posts
        .where((p) => p.message != null && p.message!.isNotEmpty)
        .toList();

    int completed = 0;
    int saved = 0;

    for (var i = 0; i < withMessages.length; i++) {
      final post = withMessages[i];
      final html = await fetchPostHTML(post.id);
      if (html != null) {
        await _profileStorage.savePostHTML(userId, post.id, html);
        saved++;
        debugPrint('Facebook: saved HTML ${i + 1}/${withMessages.length}');
      }
      completed++;
      onProgress?.call(completed, withMessages.length);
    }

    debugPrint('Facebook: saved $saved/${posts.length} post HTML files');
    return {
      'totalPosts': posts.length,
      'postsWithMessages': withMessages.length,
      'savedCount': saved,
    };
  }

  Future<String?> fetchPostHTML(String postId) async {
    final id = postId.contains('_') ? postId.split('_')[1] : postId;
    final url = 'https://www.facebook.com/$id';

    if (Platform.isWindows) return _fetchHtmlWindows(url);
    if (Platform.isAndroid) return _fetchHtmlAndroid(url);
    return _fetchHtmlPlain(url);
  }

  Future<String?> _fetchHtmlWindows(String url) async {
    try {
      final html = await WebviewPostLoader.fetchRenderedHTML(url);
      if (html == null || _isAccessDenied(html)) return null;
      return html;
    } catch (e) {
      debugPrint('Facebook: Windows WebView error — $e');
      return null;
    }
  }

  Future<String?> _fetchHtmlAndroid(String url) async {
    final ctx = webViewContext;
    if (ctx == null || !ctx.mounted) {
      debugPrint('Facebook: no BuildContext for Android WebView');
      return _fetchHtmlPlain(url);
    }
    try {
      final html = await AndroidWebviewPostLoader.fetchRenderedHTML(
          url, context: ctx);
      if (html == null || _isAccessDenied(html)) return null;
      return html;
    } catch (e) {
      debugPrint('Facebook: Android WebView error — $e');
      return null;
    }
  }

  Future<String?> _fetchHtmlPlain(String url) async {
    try {
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      });
      if (res.statusCode != 200) return null;
      final html = res.body;
      return _isAccessDenied(html) ? null : html;
    } catch (e) {
      debugPrint('Facebook: plain HTTP error — $e');
      return null;
    }
  }

  bool _isAccessDenied(String html) {
    final hasContent = html.contains('og:type') ||
        html.contains('story_attachment') ||
        html.contains('userContent') ||
        html.contains('data-testid') ||
        html.length > 50000;
    return !hasContent;
  }

  Future<Map<String, dynamic>?> _graphGet(String path) async {
    try {
      final base = path.startsWith('v') ? '' : '';
      final url = Uri.parse('https://graph.facebook.com/$base$path');
      final res = await http.get(url);
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body.containsKey('error')) {
        debugPrint('Facebook Graph error: ${body['error']['message']}');
        return null;
      }
      return body;
    } catch (e) {
      debugPrint('Facebook Graph request failed: $e');
      return null;
    }
  }
}
