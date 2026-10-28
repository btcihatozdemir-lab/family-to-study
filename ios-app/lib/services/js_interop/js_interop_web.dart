// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void implCallMethod(String method, [List<dynamic>? args]) {
  try {
    js.context.callMethod(method, args ?? []);
  } catch (e) {
    print('[JSBridge.Web] CallMethod error for $method: $e');
  }
}

dynamic implGetMethod(String method, [List<dynamic>? args]) {
  try {
    return js.context.callMethod(method, args ?? []);
  } catch (e) {
    print('[JSBridge.Web] GetMethod error for $method: $e');
    return null;
  }
}
