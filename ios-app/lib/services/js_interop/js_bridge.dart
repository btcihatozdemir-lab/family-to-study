import 'js_interop_stub.dart'
    if (dart.library.js) 'js_interop_web.dart';

class JSBridge {
  static void callMethod(String method, [List<dynamic>? args]) {
    implCallMethod(method, args);
  }

  static dynamic getMethod(String method, [List<dynamic>? args]) {
    return implGetMethod(method, args);
  }
}
