import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsProvider = Provider((ref) => SettingsService());
final roleProvider = StateProvider<String>((ref) => '');

class TrialStatus {
  final int daysRemaining;
  final bool isExpired;
  final bool isSubscribed;
  final int totalDays;

  const TrialStatus({
    required this.daysRemaining,
    required this.isExpired,
    required this.isSubscribed,
    this.totalDays = 3,
  });
}

class TrialStatusNotifier extends StateNotifier<TrialStatus> {
  final SettingsService _settings;

  TrialStatusNotifier(this._settings)
      : super(const TrialStatus(daysRemaining: 3, isExpired: false, isSubscribed: false)) {
    refresh();
  }

  Future<void> refresh() async {
    final isSub = await _settings.isProSubscribed();
    final remaining = await _settings.getRemainingTrialDays();
    final expired = await _settings.isTrialExpired();
    state = TrialStatus(
      daysRemaining: remaining,
      isExpired: expired,
      isSubscribed: isSub,
    );
  }

  Future<void> upgradeToPro() async {
    await _settings.setProSubscribed(true);
    await refresh();
  }

  Future<void> resetTrial() async {
    await _settings.setProSubscribed(false);
    await _settings.setTrialStartDate(DateTime.now());
    await refresh();
  }

  Future<void> expireTrial() async {
    await _settings.setProSubscribed(false);
    await _settings.setTrialStartDate(DateTime.now().subtract(const Duration(days: 4)));
    await refresh();
  }
}

final trialStatusProvider = StateNotifierProvider<TrialStatusNotifier, TrialStatus>((ref) {
  final settings = ref.watch(settingsProvider);
  return TrialStatusNotifier(settings);
});

class SettingsService {
  static const int totalTrialDays = 3;

  Future<String> getBaseUrl() async {
    return 'https://gridcrm.onrender.com/api'; // Can be made dynamic later
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
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Firebase Auth signout error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('role');
    await prefs.remove('assigned_technician_name');
    await prefs.remove('trial_start_date');
    await prefs.remove('is_pro_subscribed');
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

  Future<bool> getPushNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('push_notifications') ?? true; // Default to true
  }

  Future<void> setPushNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', enabled);
  }

  Future<DateTime> getTrialStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('trial_start_date');
    if (str != null) {
      return DateTime.tryParse(str) ?? DateTime.now();
    }
    final now = DateTime.now();
    await prefs.setString('trial_start_date', now.toIso8601String());
    return now;
  }

  Future<void> setTrialStartDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trial_start_date', date.toIso8601String());
  }

  Future<bool> isProSubscribed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_pro_subscribed') ?? false;
  }

  Future<void> setProSubscribed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro_subscribed', value);
  }

  Future<int> getRemainingTrialDays() async {
    final isSub = await isProSubscribed();
    if (isSub) return totalTrialDays;
    final startDate = await getTrialStartDate();
    final difference = DateTime.now().difference(startDate).inDays;
    final remaining = totalTrialDays - difference;
    return remaining < 0 ? 0 : remaining;
  }

  Future<bool> isTrialExpired() async {
    final isSub = await isProSubscribed();
    if (isSub) return false;
    final remaining = await getRemainingTrialDays();
    return remaining <= 0;
  }
}

