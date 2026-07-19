import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      ..setBackgroundColor(const Color(0xFFF5F1E8));

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
