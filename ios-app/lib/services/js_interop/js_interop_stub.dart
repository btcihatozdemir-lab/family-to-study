/// No-op implementation for native platforms (iOS, Android, macOS, Windows, Linux)
void implCallMethod(String method, [List<dynamic>? args]) {
  // Intentionally empty on native platforms
}

dynamic implGetMethod(String method, [List<dynamic>? args]) {
  // Intentionally returns null on native platforms
  return null;
}
