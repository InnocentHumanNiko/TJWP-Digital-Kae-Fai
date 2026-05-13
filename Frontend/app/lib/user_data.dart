import 'package:shared_preferences/shared_preferences.dart';

class UserData {
  // Keys for storage
  static const String _zoneKey = "CM-1";
  static const String _alertKey = "flood_alert_enabled";
  static const String _dateKey = "selected_date";
  // static const String _chanceKey = "";

  // Save App Settings (Example: Notification toggle)
  static Future<void> saveAlertSetting(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertKey, enabled);
  }

  static Future<bool> getAlertSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alertKey) ?? true;
  }

  static Future<void> saveZone(String zone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_zoneKey, zone);
    } catch (e) {
      print("Error saving zone: $e");
    }
  }

  static Future<String> getZone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_zoneKey) ?? "CM-1";
    } catch (e) {
      return "CM-1"; // Fallback
    }
  }

  static Future<void> saveDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dateKey, date.toIso8601String());
    } catch (e) {
      print("Error saving date: $e");
    }
  }

  static Future<DateTime> getDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? dateStr = prefs.getString(_dateKey);
      return dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
    } catch (e) {
      return DateTime.now(); // Fallback
    }
  }
}