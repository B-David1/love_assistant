import 'package:flutter_dotenv/flutter_dotenv.dart';

class FacebookConfig {
  // Hardcoded fallback values - used for Windows or when .env not available

  static String getAppId() {
    // Try .env first (if available)
    try {
      final appId = dotenv.env['FACEBOOK_APP_ID'];
      if (appId != null && appId.isNotEmpty) {
        return appId;
      }
    } catch (_) {
      // .env not loaded, continue to fallback
    }
    
    // Fall back to hardcoded for all platforms
    return "";
  }
  
  static String getClientToken() {
    // Try .env first (if available)
    try {
      final token = dotenv.env['FACEBOOK_CLIENT_TOKEN'];
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (_) {
      // .env not loaded, continue to fallback
    }

    return "";
  }

  static String getHardcodedUserToken() {
    return getClientToken();
  }
  
  // Helper to generate the OAuth redirect scheme
  static String get fbLoginProtocolScheme => 'fb${getAppId()}';
}