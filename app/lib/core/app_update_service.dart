import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'settings.dart';
import '../ui/widgets/app_update_dialog.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String minRequiredVersion;
  final String updateUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final bool hasUpdate;

  AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.updateUrl,
    required this.releaseNotes,
    required this.forceUpdate,
    required this.hasUpdate,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json, String currentVer) {
    final latest = json['latest_version'] as String? ?? '1.0.0';
    final minReq = json['min_required_version'] as String? ?? '1.0.0';
    final force = json['force_update'] as bool? ?? false;
    final url = json['update_url'] as String? ?? 'https://github.com/whoisadheep/GridCRM/releases';
    final notes = json['release_notes'] as String? ?? 'A new version of GridCRM is available.';

    final hasUpdate = _isVersionHigher(currentVer, latest);

    return AppUpdateInfo(
      currentVersion: currentVer,
      latestVersion: latest,
      minRequiredVersion: minReq,
      updateUrl: url,
      releaseNotes: notes,
      forceUpdate: force,
      hasUpdate: hasUpdate,
    );
  }

  static bool _isVersionHigher(String current, String latest) {
    try {
      final cParts = current.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
      final lParts = latest.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();

      for (int i = 0; i < lParts.length; i++) {
        final c = i < cParts.length ? cParts[i] : 0;
        final l = lParts[i];
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }
}

class AppUpdateService {
  static const String currentInstalledVersion = "1.0.0";

  Future<AppUpdateInfo?> checkUpdate() async {
    try {
      final baseUrl = await SettingsService().getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/app/version'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AppUpdateInfo.fromJson(data, currentInstalledVersion);
      }
    } catch (e) {
      debugPrint("Error checking app update: $e");
    }
    return null;
  }

  Future<void> checkAndShowUpdateModal(BuildContext context, {bool showToastIfLatest = false}) async {
    final info = await checkUpdate();
    if (!context.mounted) return;

    if (info != null && info.hasUpdate) {
      showDialog(
        context: context,
        barrierDismissible: !info.forceUpdate,
        builder: (ctx) => AppUpdateDialog(updateInfo: info),
      );
    } else if (showToastIfLatest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚀 You are on the latest version of GridCRM! (v1.0.0)"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  static Future<void> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) => AppUpdateService());
