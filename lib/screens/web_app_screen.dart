import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Full-screen WebView that hosts the React bible-ui, served directly from
/// the deployed backend (which also serves the built frontend — see
/// bible-backend/app.js and the root Dockerfile) so the app works standalone
/// on-device with no dev-machine tunnel required.
class WebAppScreen extends StatefulWidget {
  const WebAppScreen({super.key});

  @override
  State<WebAppScreen> createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F1E8))
      // Forwards the page's console.log/error to `adb logcat` (tag
      // "flutter") — webview_flutter doesn't do this by default, so any JS
      // exception (including a silently-caught one, if the site logs it)
      // was otherwise invisible outside Chrome's own devtools.
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        debugPrint('[WebView console] ${message.level.name}: ${message.message}');
      });

    // webview_flutter_web has no NavigationDelegate implementation yet —
    // setOnPageFinished/setOnPageStarted throw UnimplementedError there, so
    // there's no load-finished signal to hook on web. Skip the spinner logic
    // and just drop it once the iframe request is issued.
    if (!kIsWeb) {
      _controller.setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ));
    }

    // Android's WebView blocks any audio/video .play() call that isn't the
    // direct, synchronous result of a tap — the player here sets the audio
    // element's src (async, after fetching the stream URL) and *then* calls
    // .play(), which falls outside that window, so playback silently never
    // starts and the UI is left stuck on the play button. This is off by
    // default and only reachable via the Android-specific controller.
    if (!kIsWeb && _controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller.loadRequest(Uri.parse('https://bible-music-app-1.onrender.com'));

    if (kIsWeb) {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1E8),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF163A2D),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
