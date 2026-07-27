import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import '../../core/settings.dart';
import '../../core/sync_service.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _role = 'admin';
  String? _selectedTech;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsProvider);
    final role = await settings.getRole();
    final tech = await settings.getAssignedTechnician();
    setState(() {
      _role = role;
      _selectedTech = tech;
    });
  }

  Future<void> _saveSettings() async {
    final settings = ref.read(settingsProvider);
    await settings.setRole(_role);
    await settings.setAssignedTechnician(_selectedTech);
    
    // Initialize push notifications if they just switched to technician
    ref.read(syncServiceProvider).initPushNotifications();
    
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClayContainer(
              color: baseColor,
              borderRadius: 16,
              depth: 20,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('App Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _role,
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'technician', child: Text('Technician')),
                      ],
                      onChanged: (v) => setState(() => _role = v!),
                      decoration: const InputDecoration(labelText: 'Role', border: InputBorder.none),
                    ),
                    if (_role == 'technician') ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedTech,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Select a technician...')),
                          ...techNames.map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        ],
                        onChanged: (v) => setState(() => _selectedTech = v),
                        decoration: const InputDecoration(labelText: 'Assigned Technician', border: InputBorder.none),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _saveSettings,
              child: ClayContainer(
                color: const Color(0xFF4285F4),
                height: 60,
                borderRadius: 30,
                depth: 20,
                curveType: CurveType.convex,
                child: const Center(
                  child: Text(
                    'Save Settings',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _logout,
              child: ClayContainer(
                color: Colors.redAccent,
                height: 60,
                borderRadius: 30,
                depth: 20,
                curveType: CurveType.convex,
                child: const Center(
                  child: Text(
                    'Logout',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
