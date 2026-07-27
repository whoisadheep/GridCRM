import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsProvider = Provider((ref) => SettingsService());

class SettingsService {
  Future<String> getBaseUrl() async {
    return 'https://gridcrm-production-9915.up.railway.app/api'; // Can be made dynamic later
  }

  Future<void> setBaseUrl(String url) async {}

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', value);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('role');
    await prefs.remove('assigned_technician_name');
  }

  Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role') ?? '';
  }

  Future<void> setRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role);
  }

  Future<String?> getAssignedTechnician() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('assigned_technician_name');
  }

  Future<void> setAssignedTechnician(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null || name.isEmpty) {
      await prefs.remove('assigned_technician_name');
    } else {
      await prefs.setString('assigned_technician_name', name);
    }
  }
}
