import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

const Color ink = Color(0xFF0A0D12);
const Color panel = Color(0xFF141923);
const Color panel2 = Color(0xFF1C2430);
const Color accent = Color(0xFF20D6A2);
const String registrationUrl = 'https://simreg.smart.com.ph/';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: ink,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: ink,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const SmartRegApp());
}

class SmartRegApp extends StatelessWidget {
  const SmartRegApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Smart SIM Registration',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ink,
          colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
          useMaterial3: true,
          snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
        ),
        home: const RegistrationBrowser(),
      );
}

class RegistrationBrowser extends StatefulWidget {
  const RegistrationBrowser({super.key});

  @override
  State<RegistrationBrowser> createState() => _RegistrationBrowserState();
}

class _RegistrationBrowserState extends State<RegistrationBrowser> {
  InAppWebViewController? _web;
  int _progress = 0;
  String _title = 'Smart SIM Registration';
  String _url = registrationUrl;
  String? _error;
  bool _loading = true;
  bool _cameraPermissionGranted = false;

  bool get _isSmartUrl {
    final host = Uri.tryParse(_url)?.host.toLowerCase() ?? '';
    return host == 'smart.com.ph' || host.endsWith('.smart.com.ph');
  }

  Future<void> _loadRegistration() async {
    setState(() {
      _error = null;
      _loading = true;
      _progress = 0;
    });
    await _web?.loadUrl(urlRequest: URLRequest(url: WebUri(registrationUrl)));
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraPermissionGranted = status.isGranted);
    if (!status.isGranted) {
      _showMessage(status.isPermanentlyDenied
          ? 'Camera permission is blocked. Open App Settings and allow Camera, then reload the page.'
          : 'Camera permission was not granted. Allow it when prompted, then try the selfie step again.');
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    } else {
      _showMessage('Camera permission is ready. Return to the registration page and try the selfie step again.');
    }
  }

  Future<PermissionResponse?> _handleWebPermission(
      InAppWebViewController controller, PermissionRequest request) async {
    final origin = Uri.tryParse(request.origin.toString());
    final host = origin?.host.toLowerCase() ?? '';
    final isOfficialSmart = host == 'smart.com.ph' || host.endsWith('.smart.com.ph');
    if (!isOfficialSmart || origin?.scheme != 'https') {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      );
    }

    final asksCamera = request.resources.contains(PermissionResourceType.CAMERA);
    final asksMic = request.resources.contains(PermissionResourceType.MICROPHONE);
    if (asksCamera) {
      final camera = await Permission.camera.request();
      if (!camera.isGranted) {
        if (mounted) {
          setState(() => _cameraPermissionGranted = false);
          _showMessage('Android camera access is not allowed yet. Enable Camera permission and retry.');
        }
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.DENY,
        );
      }
      if (mounted) setState(() => _cameraPermissionGranted = true);
    }
    if (asksMic) {
      final microphone = await Permission.microphone.request();
      if (!microphone.isGranted) {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.DENY,
        );
      }
    }
    return PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.GRANT,
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 4)));
  }

  Future<bool> _onBackPressed() async {
    final web = _web;
    if (web != null && await web.canGoBack()) {
      await web.goBack();
      return false;
    }
    return true;
  }

  Future<void> _openInExternalBrowser() async {
    final uri = Uri.tryParse(_url);
    if (uri == null || uri.scheme != 'https') return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      _showMessage('Could not open the link in another browser.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && await _onBackPressed()) {
          if (context.mounted) Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              if (_progress < 100 && _loading)
                LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 2,
                  backgroundColor: panel,
                  color: accent,
                ),
              Expanded(
                child: Stack(
                  children: [
                    InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(registrationUrl)),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        databaseEnabled: true,
                        supportZoom: true,
                        builtInZoomControls: false,
                        displayZoomControls: false,
                        useShouldOverrideUrlLoading: true,
                        javaScriptCanOpenWindowsAutomatically: true,
                        supportMultipleWindows: false,
                        mediaPlaybackRequiresUserGesture: true,
                        allowsInlineMediaPlayback: true,
                        thirdPartyCookiesEnabled: true,
                        sharedCookiesEnabled: true,
                        safeBrowsingEnabled: true,
                        useHybridComposition: true,
                      ),
                      onWebViewCreated: (controller) => _web = controller,
                      onPermissionRequest: _handleWebPermission,
                      onTitleChanged: (controller, title) {
                        if (mounted && title != null && title.trim().isNotEmpty) {
                          setState(() => _title = title);
                        }
                      },
                      onProgressChanged: (controller, progress) {
                        if (mounted) setState(() {
                          _progress = progress;
                          _loading = progress < 100;
                        });
                      },
                      onLoadStart: (controller, uri) {
                        if (mounted) setState(() {
                          _url = uri?.toString() ?? registrationUrl;
                          _error = null;
                          _loading = true;
                        });
                      },
                      onLoadStop: (controller, uri) async {
                        if (!mounted) return;
                        setState(() {
                          _url = uri?.toString() ?? _url;
                          _loading = false;
                          _progress = 100;
                        });
                      },
                      onReceivedError: (controller, request, error) {
                        if (request.isForMainFrame == true && mounted) {
                          setState(() {
                            _error = 'The registration site could not load. Check your internet connection, then reload.';
                            _loading = false;
                          });
                        }
                      },
                      onReceivedHttpError: (controller, request, response) {
                        if (request.isForMainFrame == true && response.statusCode >= 500 && mounted) {
                          setState(() {
                            _error = 'Smart’s registration server is temporarily unavailable (${response.statusCode}). Try again later.';
                          });
                        }
                      },
                      onCreateWindow: (controller, action) async {
                        final uri = action.request.url;
                        if (uri != null && uri.scheme == 'https') {
                          await controller.loadUrl(urlRequest: URLRequest(url: uri));
                        }
                        return true;
                      },
                    ),
                    if (_error != null) _errorPanel(),
                    if (_loading && _progress < 8)
                      const Center(child: CircularProgressIndicator(color: accent)),
                  ],
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: const BoxDecoration(
          color: ink,
          border: Border(bottom: BorderSide(color: Color(0xFF222A35))),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: accent.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.verified_user_rounded, color: accent, size: 24),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('SMART SIM REG', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: .8)),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.lock_rounded, size: 12, color: _isSmartUrl ? accent : Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Expanded(child: Text(_isSmartUrl ? 'Official Smart domain' : 'Secure web page', style: const TextStyle(fontSize: 11, color: Colors.white60), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            ),
            IconButton(tooltip: 'Reload registration', onPressed: _loadRegistration, icon: const Icon(Icons.refresh_rounded)),
            PopupMenuButton<String>(
              color: panel2,
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                switch (value) {
                  case 'camera':
                    _requestCameraPermission();
                    break;
                  case 'external':
                    _openInExternalBrowser();
                    break;
                  case 'help':
                    _showHelp();
                    break;
                  case 'home':
                    _loadRegistration();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'camera', child: ListTile(leading: Icon(Icons.camera_alt_outlined), title: Text('Check camera permission'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'external', child: ListTile(leading: Icon(Icons.open_in_browser), title: Text('Open in another browser'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'help', child: ListTile(leading: Icon(Icons.help_outline), title: Text('Permission help'), contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'home', child: ListTile(leading: Icon(Icons.home_outlined), title: Text('Open registration home'), contentPadding: EdgeInsets.zero)),
              ],
            ),
          ],
        ),
      );

  Widget _bottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(color: ink, border: Border(top: BorderSide(color: Color(0xFF222A35)))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            _navButton(Icons.arrow_back_rounded, 'Back', () async {
              if (_web != null && await _web!.canGoBack()) await _web!.goBack();
            }),
            _navButton(Icons.arrow_forward_rounded, 'Forward', () async {
              if (_web != null && await _web!.canGoForward()) await _web!.goForward();
            }),
            _navButton(Icons.refresh_rounded, 'Reload', _loadRegistration),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(13)),
                child: Row(children: [
                  const Icon(Icons.language_rounded, size: 17, color: accent),
                  const SizedBox(width: 7),
                  Expanded(child: Text(Uri.tryParse(_url)?.host ?? 'simreg.smart.com.ph', style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(_cameraPermissionGranted ? Icons.check_circle : Icons.camera_alt_outlined, size: 15, color: _cameraPermissionGranted ? accent : Colors.white54),
            const SizedBox(width: 6),
            Expanded(child: Text(_cameraPermissionGranted ? 'Camera access ready' : 'Camera is requested only when Smart needs it', style: const TextStyle(fontSize: 10, color: Colors.white54))),
            TextButton.icon(
              onPressed: _requestCameraPermission,
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: const Text('Permissions', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(foregroundColor: accent, visualDensity: VisualDensity.compact),
            ),
          ]),
        ]),
      );

  Widget _navButton(IconData icon, String label, FutureOr<void> Function() onPressed) => IconButton(
        tooltip: label,
        onPressed: () => onPressed(),
        icon: Icon(icon, size: 21, color: Colors.white70),
        style: IconButton.styleFrom(backgroundColor: panel, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );

  Widget _errorPanel() => Positioned.fill(
        child: Container(
          color: ink.withValues(alpha: .97),
          padding: const EdgeInsets.all(28),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, color: accent, size: 48),
            const SizedBox(height: 18),
            const Text('Could not open the site', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _loadRegistration, icon: const Icon(Icons.refresh), label: const Text('Try again')),
            const SizedBox(height: 8),
            TextButton(onPressed: _showHelp, child: const Text('Camera and upload help')),
          ])),
        ),
      );

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Fix camera or ID upload issues', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('1. Tap Permissions below and allow Camera when Android asks.\n\n2. Return to the Smart registration page and retry the selfie step.\n\n3. For ID upload, choose Camera or Photos/Files when the page opens the picker.\n\n4. If you previously blocked Camera, open Android App info → Permissions → Camera → Allow, then reload.\n\nThis app cannot bypass Android permission prompts or Smart’s own server-side checks. It handles the WebView permission request correctly so you should not need to switch browsers just because the embedded page was not granted access.' , style: TextStyle(height: 1.45, color: Colors.white70)),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () { Navigator.pop(context); _requestCameraPermission(); }, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Check camera permission'))),
        ]),
      ),
    );
  }
}
