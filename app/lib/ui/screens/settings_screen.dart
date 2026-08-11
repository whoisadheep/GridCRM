import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import '../../core/settings.dart';
import '../../core/sync_service.dart';
import '../../core/app_update_service.dart';
import 'login_screen.dart';
import 'technician_profile_screen.dart';
import '../widgets/assistant_sheet.dart';
import '../widgets/upgrade_dialog.dart';
import '../widgets/download_progress_banner.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _role = 'admin';
  String? _selectedTech;
  bool _pushEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsProvider);
    final role = await settings.getRole();
    final tech = await settings.getAssignedTechnician();
    final push = await settings.getPushNotificationsEnabled();
    setState(() {
      _role = role;
      _selectedTech = tech;
      _pushEnabled = push;
    });
  }

  Future<void> _saveSettings() async {
    final settings = ref.read(settingsProvider);
    await settings.setRole(_role);
    await settings.setAssignedTechnician(_selectedTech);
    
    // Initialize push notifications if they just switched to technician
    ref.read(syncServiceProvider).enablePushNotifications();
    
    // Auto reloaded by stream in other screens
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      Navigator.pop(context);
    }
  }

  Future<void> _logout() async {
    final settings = ref.read(settingsProvider);
    await settings.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Color textColor = Colors.black87,
    Color iconColor = Colors.blueAccent,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final baseColor = Theme.of(context).scaffoldBackgroundColor;
    return GestureDetector(
      onTap: onTap,
      child: ClayContainer(
        color: baseColor,
        borderRadius: 16,
        depth: 10,
        child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.black38),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: 24,
      ),  ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final techsAsync = ref.watch(techniciansProvider);
    final trialStatus = ref.watch(trialStatusProvider);
    final techs = techsAsync.value ?? [];
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 12),
          const DownloadProgressBanner(),
          if (_role == 'technician' && _selectedTech != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildSettingsTile(
                icon: Icons.person,
                title: 'My Profile',
                onTap: () {
                  final tech = techs.firstWhere((t) => t['name'] == _selectedTech, orElse: () => {});
                  if (tech.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TechnicianProfileScreen(technician: tech)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile not found')));
                  }
                },
              ),
            ),
          
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            textColor: Colors.redAccent,
            iconColor: Colors.redAccent,
            onTap: _logout,
          ),

          const SizedBox(height: 32),
          const Text('Subscription & Trial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 16),
          ClayContainer(
            color: baseColor,
            borderRadius: 20,
            depth: 15,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              trialStatus.isSubscribed ? Icons.stars : Icons.timer,
                              color: trialStatus.isSubscribed ? Colors.amber : (trialStatus.isExpired ? Colors.redAccent : Colors.blueAccent),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                trialStatus.isSubscribed ? 'Grid CRM Pro' : 'Free Trial (3 Days)',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: trialStatus.isSubscribed
                              ? Colors.green.withOpacity(0.15)
                              : (trialStatus.isExpired ? Colors.red.withOpacity(0.15) : Colors.blue.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          trialStatus.isSubscribed
                              ? 'ACTIVE'
                              : (trialStatus.isExpired ? 'EXPIRED' : '${trialStatus.daysRemaining}d LEFT'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: trialStatus.isSubscribed
                                ? Colors.green[700]
                                : (trialStatus.isExpired ? Colors.red[700] : Colors.blue[700]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!trialStatus.isSubscribed) ...[
                    Text(
                      trialStatus.isExpired
                          ? 'Your 3-day free trial has expired. Upgrade to keep using all CRM features.'
                          : '${trialStatus.daysRemaining} days left in your free trial period.',
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          showDialog(context: context, builder: (_) => const UpgradeDialog());
                        },
                        icon: const Icon(Icons.bolt, color: Colors.amber),
                        label: const Text('Upgrade to Pro', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    const Text('You have full access to all Pro features.', style: TextStyle(color: Colors.black54, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          const Text('Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 16),
          
          _buildSettingsTile(
            icon: Icons.notifications,
            title: 'Push Notifications',
            trailing: Switch(
              value: _pushEnabled,
              onChanged: (val) async {
                setState(() => _pushEnabled = val);
                await ref.read(settingsProvider).setPushNotificationsEnabled(val);
                if (val) {
                  await ref.read(syncServiceProvider).enablePushNotifications();
                } else {
                  await ref.read(syncServiceProvider).disablePushNotifications();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? 'Push Notifications Enabled' : 'Push Notifications Disabled')));
                }
              },
              activeColor: Colors.blueAccent,
            ),
            onTap: () {},
          ),


          const SizedBox(height: 32),
          const Text('Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 16),
          
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const AssistantSheet()
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About Grid CRM',
            trailing: const Text('v1.0.0', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Grid CRM'),
                  content: const Text('Version 1.0.0\nDesigned for seamless CRM management and dispatch.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.system_update,
            title: 'Check for Updates',
            onTap: () {
              ref.read(appUpdateServiceProvider).checkAndShowUpdateModal(context, showToastIfLatest: true);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
