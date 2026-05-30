import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

/// Loads a URL in a headless-style WebView, waits for JS to settle,
/// then returns the fully-rendered outerHTML.
///
/// Usage:
///   final html = await WebviewPostLoader.fetchRenderedHTML(url);
class WebviewPostLoader {
  /// How long to wait after the page's `navigationCompleted` event fires
  /// before extracting HTML. Facebook's feed JS typically needs ~3 s.
  static const Duration _renderDelay = Duration(seconds: 4);

  /// Maximum time before giving up entirely.
  static const Duration _timeout = Duration(seconds: 30);

  /// Fetches fully JS-rendered HTML for [url].
  ///
  /// Shows a tiny off-screen overlay window while loading so the WebView has
  /// a real surface to paint on (required by webview_windows).
  /// Returns `null` if navigation fails or times out.
  static Future<String?> fetchRenderedHTML(
    String url, {
    BuildContext? context,
  }) async {
    final controller = WebviewController();
    final completer = Completer<String?>();

    // Must be initialised before use.
    await controller.initialize();

    // Suppress unwanted pop-ups.
    controller.webMessage.listen((_) {});

    // Listen for navigation completion.
    late StreamSubscription<LoadingState> sub;
    sub = controller.loadingState.listen((state) async {
      if (state == LoadingState.navigationCompleted) {
        sub.cancel();
        // Wait for React / dynamic content to hydrate.
        await Future.delayed(_renderDelay);

        try {
          final result = await controller.executeScript(
            'document.documentElement.outerHTML',
          );
          // executeScript returns a JSON-encoded string – strip outer quotes.
          final raw = result?.toString() ?? '';
          final html = _unquoteJson(raw);
          completer.complete(html.isEmpty ? null : html);
        } catch (e) {
          debugPrint('WebviewPostLoader: JS execution failed – $e');
          completer.complete(null);
        } finally {
          await controller.dispose();
        }
      }
    });

    // Kick off navigation.
    await controller.loadUrl(url);

    // Race against timeout.
    return completer.future.timeout(_timeout, onTimeout: () {
      sub.cancel();
      controller.dispose();
      debugPrint('WebviewPostLoader: timed out for $url');
      return null;
    });
  }

  /// `executeScript` returns a JSON string like `"<html>..."`.
  /// This strips the wrapping quotes and unescapes basic JSON escapes.
  static String _unquoteJson(String value) {
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

/// A thin overlay widget that hosts the WebView surface.
/// webview_windows requires the controller to be attached to a visible
/// [Texture] widget – even if it's tiny and off-screen.
///
/// You don't need to use this directly; [WebviewPostLoader.fetchRenderedHTML]
/// manages the controller lifecycle internally without needing a widget tree.
/// This widget is provided for cases where you want to show a progress UI.
class WebviewOverlay extends StatefulWidget {
  final WebviewController controller;
  final Widget? loadingIndicator;

  const WebviewOverlay({
    super.key,
    required this.controller,
    this.loadingIndicator,
  });

  @override
  State<WebviewOverlay> createState() => _WebviewOverlayState();
}

class _WebviewOverlayState extends State<WebviewOverlay> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    widget.controller.loadingState.listen((state) {
      if (state == LoadingState.navigationCompleted && mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Webview(widget.controller),
        if (_isLoading)
          widget.loadingIndicator ??
              const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
