import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/session_manager.dart';
import '../services/supabase_service.dart';

class FamilyWebViewScreen extends StatefulWidget {
  const FamilyWebViewScreen({super.key});

  @override
  State<FamilyWebViewScreen> createState() => _FamilyWebViewScreenState();
}

class _FamilyWebViewScreenState extends State<FamilyWebViewScreen> {
  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;
  double _progress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _requestHardwarePermissions();

    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: const Color(0xFF6366F1),
      ),
      onRefresh: () async {
        _webViewController?.reload();
      },
    );
  }

  /// Açılışta Kamera & Mikrofon İzinlerini Native Olarak İste
  Future<void> _requestHardwarePermissions() async {
    try {
      await [
        Permission.camera,
        Permission.microphone,
      ].request();
    } catch (e) {
      print('[Permissions] İzin isteme hatası: $e');
    }
  }

  String _getTargetUrl() {
    String base = SessionManager.pwaUrl.trim();
    if (!base.endsWith('/')) {
      base = '$base/';
    }

    if (SessionManager.magicToken.isNotEmpty) {
      return '$base?u=${SessionManager.magicToken}&auto_auth=true';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          children: [
            if (!_hasError)
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(_getTargetUrl()),
                ),
                pullToRefreshController: _pullToRefreshController,
                initialSettings: InAppWebViewSettings(
                  // iOS 15.8+ & Güncel iOS Performans ve Medya Ayarları
                  allowsInlineMediaPlayback: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsBackForwardNavigationGestures: true,
                  cacheEnabled: true,
                  transparentBackground: true,
                  useShouldOverrideUrlLoading: true,
                  applicationNameForUserAgent: 'FamilyOS-iOS-Native/1.0',
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  _setupJavaScriptHandlers(controller);
                },
                onPermissionRequest: (controller, request) async {
                  // PWA Kamera / Mikrofon taleplerine doğrudan izin ver
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100;
                  });
                  if (progress == 100) {
                    _pullToRefreshController?.endRefreshing();
                  }
                },
                onLoadStop: (controller, url) async {
                  _pullToRefreshController?.endRefreshing();
                  setState(() {
                    _hasError = false;
                  });
                  _syncSessionFromPwaStorage(controller);
                },
                onReceivedError: (controller, request, error) {
                  _pullToRefreshController?.endRefreshing();
                  if (request.isForMainFrame ?? true) {
                    setState(() {
                      _hasError = true;
                    });
                  }
                },
              ),

            // Üst İlerleme Çubuğu
            if (_progress < 1.0 && !_hasError)
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                minHeight: 2.5,
              ),

            // Bağlantı Hatası / Çevrimdışı Ekranı
            if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        size: 64,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Bağlantı Kurulamadı',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'FamilyOS sunucusuna erişilemiyor. Lütfen internet bağlantınızı kontrol edin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                          });
                          _webViewController?.reload();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Yeniden Dene'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// PWA ile Native Dart arasında iki yönlü durum köprüsü kurar
  void _setupJavaScriptHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onFamilyStateSync',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = Map<String, dynamic>.from(args[0] as Map);
          _applySyncedState(data);
        }
      },
    );
  }

  /// PWA'nın localStorage içindeki aktif kullanıcı ve ders durumunu okur
  Future<void> _syncSessionFromPwaStorage(InAppWebViewController controller) async {
    try {
      final jsCode = '''
        (function() {
          try {
            const raw = localStorage.getItem('family_to_study_session_v1');
            if (raw) return raw;
          } catch(e) {}
          return null;
        })();
      ''';

      final result = await controller.evaluateJavascript(source: jsCode);
      if (result != null && result.toString().isNotEmpty && result.toString() != 'null') {
        print('[Bridge] PWA Oturumu tespit edildi: $result');
        // Realtime aboneliğini canlandır
        SupabaseService.subscribeToRealtimeEvents();
      }
    } catch (e) {
      print('[Bridge] Storage okuma hatası: $e');
    }
  }

  void _applySyncedState(Map<String, dynamic> data) {
    final role = data['role']?.toString() ?? SessionManager.role;
    final state = data['currentState']?.toString() ?? SessionManager.currentState;
    final userId = data['userId']?.toString() ?? SessionManager.userId;
    final familyId = data['familyId']?.toString() ?? SessionManager.familyId;
    final name = data['name']?.toString() ?? SessionManager.name;

    SessionManager.updateSession(
      newUserId: userId,
      newFamilyId: familyId,
      newRole: role,
      newName: name,
    );
    SessionManager.updateCurrentState(state);

    // Ders saatinde ekran kararmasını engelle
    if (SessionManager.isStudying) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    SupabaseService.subscribeToRealtimeEvents();
  }
}
