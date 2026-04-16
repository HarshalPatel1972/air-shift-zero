import 'package:shared_preferences/shared_preferences.dart';

class AirShiftSettings {
  static final AirShiftSettings instance = AirShiftSettings._internal();
  AirShiftSettings._internal();
  factory AirShiftSettings() => instance;

  String? customSavePath;
  bool startWhenDetect = false;
  bool hapticFeedback = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    customSavePath = prefs.getString('customSavePath');
    startWhenDetect = prefs.getBool('startWhenDetect') ?? false;
    hapticFeedback = prefs.getBool('hapticFeedback') ?? true;
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
