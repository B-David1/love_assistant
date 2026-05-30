import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _accessTokenKey = 'facebook_access_token';
  static const String _userIdKey = 'facebook_user_id';
  static const String _userNameKey = 'facebook_user_name';
  static const String _userEmailKey = 'facebook_user_email';
  static const String _tokenExpiryKey = 'facebook_token_expiry';
  static const String _permissionsKey = 'facebook_permissions';

  // Save Facebook OAuth tokens and user data
  Future<void> saveFacebookAuthData({
    required String accessToken,
    required String userId,
    String? userName,
    String? userEmail,
    required DateTime expiryDate,
    required List<String> permissions,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _userIdKey, value: userId);
    await _secureStorage.write(key: _tokenExpiryKey, value: expiryDate.toIso8601String());
    await _secureStorage.write(key: _permissionsKey, value: permissions.join(','));
    
    if (userName != null) {
      await _secureStorage.write(key: _userNameKey, value: userName);
    }
    if (userEmail != null) {
      await _secureStorage.write(key: _userEmailKey, value: userEmail);
    }
  }

  // Get stored access token
  Future<String?> getAccessToken() async {
    final token = await _secureStorage.read(key: _accessTokenKey);
    if (token != null) {
      // Check if token is expired
      final expiryStr = await _secureStorage.read(key: _tokenExpiryKey);
      if (expiryStr != null) {
        final expiry = DateTime.parse(expiryStr);
        if (expiry.isBefore(DateTime.now())) {
          // Token expired, clear it
          await clearAllTokens();
          return null;
        }
      }
    }
    return token;
  }

  // Get user data
  Future<Map<String, String?>> getUserData() async {
    return {
      'userId': await _secureStorage.read(key: _userIdKey),
      'userName': await _secureStorage.read(key: _userNameKey),
      'userEmail': await _secureStorage.read(key: _userEmailKey),
      'permissions': await _secureStorage.read(key: _permissionsKey),
    };
  }

  // Check if user is logged in with valid token
  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Get token expiry date
  Future<DateTime?> getTokenExpiry() async {
    final expiryStr = await _secureStorage.read(key: _tokenExpiryKey);
    if (expiryStr != null) {
      return DateTime.parse(expiryStr);
    }
    return null;
  }

  // Clear all stored auth data
  Future<void> clearAllTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _userIdKey);
    await _secureStorage.delete(key: _userNameKey);
    await _secureStorage.delete(key: _userEmailKey);
    await _secureStorage.delete(key: _tokenExpiryKey);
    await _secureStorage.delete(key: _permissionsKey);
  }

  // Update token (for token refresh)
  Future<void> updateAccessToken(String newToken, DateTime newExpiry) async {
    await _secureStorage.write(key: _accessTokenKey, value: newToken);
    await _secureStorage.write(key: _tokenExpiryKey, value: newExpiry.toIso8601String());
  }
}