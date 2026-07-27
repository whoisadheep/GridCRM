import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import '../../core/settings.dart';
import '../../core/sync_service.dart';
import 'login_screen.dart';
import 'technician_profile_screen.dart';
import '../widgets/assistant_sheet.dart';

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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final techsAsync = ref.watch(techniciansProvider);
    final techs = techsAsync.value ?? [];
    final techNames = techs.map((t) => t['name'] as String).toList();
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 16),
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
