# Facebook OAuth Setup Guide

This guide explains how to properly configure Facebook authentication redirect for the Love Assistant app.

## Overview
The `flutter_facebook_auth` package automatically handles OAuth redirects. No additional code is needed, but you must configure your app in the Facebook Developer Console.

## Android Setup

### 1. Get Your App's Key Hash
Run this command to get your app's key hash:

```bash
# For Windows (PowerShell)
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
keytool -exportcert -alias androiddebugkey -keystore "$env:USERPROFILE\.android\keystore" | `
  ForEach-Object { $_ } | `
  certutil -encode -f - cert.txt
# Then decode and convert to base64

# Or use this simpler approach for debug key:
keytool -exportcert -alias androiddebugkey -keystore %USERPROFILE%\.android\keystore -storepass android -keypass android | certutil -encode -f - cert.txt
# cert.txt will contain the base64 hash
```

### 2. Android Manifest Already Configured ✓
Your `AndroidManifest.xml` already has:
```xml
<meta-data
    android:name="com.facebook.sdk.ApplicationId"
    android:value="@string/facebook_app_id" />

<meta-data
    android:name="com.facebook.sdk.ClientToken"
    android:value="@string/facebook_client_token" />
```

### 3. Update Facebook App Console
1. Go to [Facebook Developers Console](https://developers.facebook.com)
2. Select your app
3. Go to **Settings > Basic**
4. Copy your **App ID** and **App Secret**
5. Go to **Products > Facebook Login > Settings**
6. In **Valid OAuth Redirect URIs**, add:
   - `fb{YOUR_APP_ID}://authorize` (for native Android)
   - `fb{YOUR_APP_ID}://facebook` (fallback)

## iOS Setup

### 1. Update Info.plist
Your app needs URL schemes. Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fb25071066379229707</string>
        </array>
    </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>fbauth2</string>
    <string>fbapi</string>
    <string>fbshareextension</string>
</array>
```

**Replace `25071066379229707` with your actual Facebook App ID.**

### 2. Update Facebook App Console
In **Products > Facebook Login > Settings**:
- Add to **Valid OAuth Redirect URIs**: `fb{YOUR_APP_ID}://authorize`

## Windows Setup (Desktop)

For Windows platform (if building desktop version):

### 1. WebView2 Configuration
Windows uses web-based OAuth flow. No special redirect needed, but ensure you have:
- WebView2 Runtime installed on target machine
- Or use Flutter web wrapper

### 2. Facebook App Console
For Windows desktop apps, you may need to register a website URL if using web-based auth flow.

## Environment Variables

Your `.env` file should contain:
```
FACEBOOK_APP_ID=25071066379229707
FACEBOOK_CLIENT_TOKEN=your_client_token_here
OPENAI_API_KEY=your_openai_key_here
```

## Testing the Setup

### Android
```bash
flutter run
# Tap Facebook Login
# You should be redirected back to the app after authentication
```

### iOS
```bash
cd ios
pod install
cd ..
flutter run -d iphone
# Tap Facebook Login
# You should be redirected back to the app after authentication
```

## Troubleshooting

### "App not set up" Error
- Ensure App ID is correct in `.env` and Facebook App Console
- Verify package name matches in Facebook Console

### Login redirects to browser but doesn't return
- Check that redirect URIs are properly configured in Facebook Console
- Ensure URL schemes are correct in Info.plist (iOS)
- Check AndroidManifest metadata (Android)

### Key Hash Mismatch (Android)
- Get correct key hash with keytool command above
- Add to Facebook Console under **Settings > Basic > Key Hashes**

### Still having issues?
The `flutter_facebook_auth` package handles redirects automatically via native plugins. If it's not working:
1. Run `flutter pub get` to ensure latest packages
2. Run `flutter clean && flutter pub get` to reset
3. Check device logs: `flutter logs`
4. Verify Facebook App settings match your package name/bundle ID

## Current Configuration Status

✅ **Already Configured:**
- Android: Metadata tags in AndroidManifest.xml
- Environment: .env file with credentials
- Facebook Service: Handles login flow

⚠️ **Still Needed:**
- iOS: Update Info.plist with URL schemes (if building for iOS)
- Facebook Console: Add redirect URIs matching your URL schemes
- Debug Key Hash: Get and add to Facebook Console (Android)
