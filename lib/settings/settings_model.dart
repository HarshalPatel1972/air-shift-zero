import 'package:shared_preferences/shared_preferences.dart';

class AirShiftSettings {
  static final AirShiftSettings instance = AirShiftSettings._internal();
  AirShiftSettings._internal();
  factory AirShiftSettings() => instance;

  String? customSavePath;
  bool startWhenDetect = false;
  bool hapticFeedback = true;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      customSavePath = prefs.getString('customSavePath');
      startWhenDetect = prefs.getBool('startWhenDetect') ?? false;
      hapticFeedback = prefs.getBool('hapticFeedback') ?? true;
    } catch (e) {
      debugPrint('Warning: SharedPreferences failed to load in time: $e');
      // Continue with defaults
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (customSavePath != null) {
      await prefs.setString('customSavePath', customSavePath!);
    } else {
      await prefs.remove('customSavePath');
    }
    await prefs.setBool('startWhenDetect', startWhenDetect);
    await prefs.setBool('hapticFeedback', hapticFeedback);
  }
}
