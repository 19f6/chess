/// Backend server location.
///
/// Defaults to localhost, which is reachable as-is from the iOS Simulator
/// and macOS desktop builds. Override at build/run time for a physical
/// device or the Android emulator (which needs 10.0.2.2 instead of
/// localhost), e.g.:
///   flutter run --dart-define=SERVER_URL=http://10.0.2.2:3000
class AppConfig {
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://localhost:3000',
  );
}
