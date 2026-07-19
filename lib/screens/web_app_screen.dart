import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
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
    // Grants/denies the WebView's own permission prompt for getUserMedia()
    // (the Web Speech API's mic access goes through the same prompt) — only
    // takes effect via this constructor parameter, not a post-construction
    // setter. Separate from, and must come after, the OS-level RECORD_AUDIO
    // runtime permission requested inside: granting the WebView request
    // alone does nothing if the app process doesn't already hold that
    // permission. Not available on webview_flutter_web, hence kIsWeb ? null.
    _controller = WebViewController(
      onPermissionRequest: kIsWeb ? null : _onWebViewPermissionRequest,
    )
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
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);

      // Android's WebView shows no native file-chooser UI for <input
      // type="file"> unless the app implements this callback and does the
      // picking itself - with nothing wired up, tapping the profile-photo
      // input (or any file input) silently does nothing at all.
      androidController.setOnShowFileSelector(_pickImageForFileSelector);
    }

    _controller.loadRequest(Uri.parse('https://bible-music-app-1.onrender.com'));

    if (kIsWeb) {
      _loading = false;
    }
  }

  // Backing implementation for the WebViewController's onPermissionRequest -
  // grants/denies the WebView's own permission prompt for getUserMedia()
  // (the Web Speech API's mic access goes through the same prompt). Must
  // come after the OS-level RECORD_AUDIO runtime permission requested here:
  // granting the WebView request alone does nothing if the app process
  // doesn't already hold that permission.
  Future<void> _onWebViewPermissionRequest(
    WebViewPermissionRequest request,
  ) async {
    if (!request.types.contains(WebViewPermissionResourceType.microphone)) {
      request.deny();
      return;
    }

    final status = await ph.Permission.microphone.request();
    if (status.isGranted) {
      request.grant();
    } else {
      request.deny();
    }
  }

  // WhatsApp-style source picker, since the WebView's file input has no
  // native "Take Photo vs Choose from Gallery" chooser of its own —
  // implementing setOnShowFileSelector at all means we're responsible for
  // presenting that choice ourselves.
  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF163A2D).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Color(0xFF163A2D)),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF163A2D)),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Backing implementation for setOnShowFileSelector: shows the source
  // picker above, opens the chosen native picker, then hands the file back
  // to the WebView as a file:// URI (the format the underlying Android
  // WebChromeClient expects for its file-chooser result).
  Future<List<String>> _pickImageForFileSelector(FileSelectorParams params) async {
    final ImageSource? source = await _chooseImageSource();
    if (source == null) return <String>[];

    final XFile? image = await ImagePicker().pickImage(source: source);
    if (image == null) return <String>[];

    return <String>[Uri.file(image.path).toString()];
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
