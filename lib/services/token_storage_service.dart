import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  TokenStorageService();

  static const _storage = FlutterSecureStorage();

  static const _kAccessToken  = 'facebook_access_token';
  static const _kUserId       = 'facebook_user_id';
  static const _kUserName     = 'facebook_user_name';
  static const _kUserEmail    = 'facebook_user_email';
  static const _kTokenExpiry  = 'facebook_token_expiry';
  static const _kPermissions  = 'facebook_permissions';

  Future<void> saveFacebookAuthData({
    required String accessToken,
    required String userId,
    String? userName,
    String? userEmail,
    required DateTime expiryDate,
    required List<String> permissions,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kUserId,      value: userId),
      _storage.write(key: _kTokenExpiry, value: expiryDate.toIso8601String()),
      _storage.write(key: _kPermissions, value: permissions.join(',')),
      if (userName  != null) _storage.write(key: _kUserName,  value: userName),
      if (userEmail != null) _storage.write(key: _kUserEmail, value: userEmail),
    ]);
  }

  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _kAccessToken);
    if (token == null) return null;

    final expiryStr = await _storage.read(key: _kTokenExpiry);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        await clearAllTokens();
        return null;
      }
    }
    return token;
  }

  Future<Map<String, String?>> getUserData() async => {
        'userId':    await _storage.read(key: _kUserId),
        'userName':  await _storage.read(key: _kUserName),
        'userEmail': await _storage.read(key: _kUserEmail),
        'permissions': await _storage.read(key: _kPermissions),
      };

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> updateAccessToken(String token, DateTime expiry) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: token),
      _storage.write(key: _kTokenExpiry, value: expiry.toIso8601String()),
    ]);
  }

  Future<void> clearAllTokens() => Future.wait([
        _storage.delete(key: _kAccessToken),
        _storage.delete(key: _kUserId),
        _storage.delete(key: _kUserName),
        _storage.delete(key: _kUserEmail),
        _storage.delete(key: _kTokenExpiry),
        _storage.delete(key: _kPermissions),
      ]);
}
