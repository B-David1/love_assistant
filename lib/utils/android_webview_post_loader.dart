import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Loads a Facebook post URL in a hidden desktop-mode WebView on Android.
/// No login required — uses desktop user agent so Facebook renders comments.
class AndroidWebviewPostLoader {
  static const Duration _renderDelay = Duration(seconds: 8);
  static const Duration _timeout = Duration(seconds: 60);

  /// Full desktop Chrome UA — tells Facebook to serve the full desktop site.
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Safari/537.36';

  /// Loads a Facebook URL with the access token so the shared WebView
  /// cookie store gets a real session before scraping begins.
  static Future<void> warmUpWebViewSession(
      BuildContext context, String appId, String token) async {
    final completer = Completer<void>();

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..clearCache()
      ..clearLocalStorage();

    controller.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (url) async {
        if (completer.isCompleted) return;
        try {
          final cookieResult = await controller
              .runJavaScriptReturningResult('document.cookie');
          final cookies = cookieResult.toString();
          debugPrint('WarmUp: has c_user: ${cookies.contains('c_user=')}');
        } catch (_) {}
        completer.complete();
      },
      onWebResourceError: (_) {
        if (!completer.isCompleted) completer.complete();
      },
    ));

    final overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: -100, top: -100, width: 1, height: 1,
        child: WebViewWidget(controller: controller),
      ),
    );
    Overlay.of(context).insert(overlayEntry);

    try {
      await controller.loadRequest(Uri.parse(
        'https://www.facebook.com/dialog/oauth?'
        'client_id=$appId'
        '&redirect_uri=https://www.facebook.com/connect/login_success.html'
        '&response_type=token'
        '&access_token=$token',
      ));
      await completer.future
          .timeout(const Duration(seconds: 10), onTimeout: () {});
    } finally {
      overlayEntry.remove();
    }
  }

  static Future<String?> fetchRenderedHTML(
    String url, {
    required BuildContext context,
  }) async {
    final completer = Completer<String?>();

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..clearCache()
      ..clearLocalStorage();

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (u) => debugPrint('WebView started: $u'),
        onPageFinished: (String finishedUrl) async {
          if (completer.isCompleted) return;
          debugPrint('WebView page finished: $finishedUrl');

          // Wait for React/comments JS to hydrate.
          await Future.delayed(_renderDelay);
          if (completer.isCompleted) return;

          // Scroll to trigger lazy-loaded comments.
          await controller.runJavaScript(
            'window.scrollTo(0, document.body.scrollHeight);',
          );
          await Future.delayed(const Duration(seconds: 2));
          if (completer.isCompleted) return;

          try {
            final result = await controller.runJavaScriptReturningResult(
              'document.documentElement.outerHTML',
            );
            final html = _unquoteJs(result.toString());

            final ariaCount =
                RegExp(r'aria-label="Comment by').allMatches(html).length;
            debugPrint('WebView HTML length: ${html.length}, comments found: $ariaCount');

            completer.complete(html.isEmpty ? null : html);
          } catch (e) {
            debugPrint('WebView JS failed: $e');
            completer.complete(null);
          }
        },
        onWebResourceError: (error) =>
            debugPrint('WebView resource error: ${error.description}'),
      ),
    );

    // 1280x900 off-screen so Facebook renders in full desktop mode.
    final overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: -1400,
        top: -1000,
        width: 1280,
        height: 900,
        child: WebViewWidget(controller: controller),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    try {
      await controller.loadRequest(Uri.parse(url));
      return await completer.future.timeout(
        _timeout,
        onTimeout: () {
          debugPrint('WebView timed out for $url');
          return null;
        },
      );
    } finally {
      overlayEntry.remove();
    }
  }

  static String _unquoteJs(String value) {
    var v = value.trim();
    if (v.startsWith('"') && v.endsWith('"')) {
      v = v.substring(1, v.length - 1);
    }
    return v
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\\', '\\');
  }
}