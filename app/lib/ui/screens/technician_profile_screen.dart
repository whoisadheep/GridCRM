import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import '../../core/sync_service.dart';

class TechnicianProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> technician;

  const TechnicianProfileScreen({super.key, required this.technician});

  @override
  ConsumerState<TechnicianProfileScreen> createState() => _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends ConsumerState<TechnicianProfileScreen> {
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _specialtyCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.technician['phone'] ?? '');
    _emailCtrl = TextEditingController(text: widget.technician['email'] ?? '');
    _specialtyCtrl = TextEditingController(text: widget.technician['specialty'] ?? '');
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(syncServiceProvider).updateTechnician(
        widget.technician['id'], 
        widget.technician['name'], 
        widget.technician['pin'], 
        phone: _phoneCtrl.text.trim(), 
        email: _emailCtrl.text.trim(), 
        specialty: _specialtyCtrl.text.trim()
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClayContainer(
                color: baseColor,
                height: 100,
                width: 100,
                borderRadius: 50,
                depth: 20,
                child: const Icon(Icons.person, size: 50, color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                widget.technician['name'],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            ClayContainer(
              color: baseColor,
              borderRadius: 12,
              depth: -10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Phone Number',
                    icon: Icon(Icons.phone),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClayContainer(
              color: baseColor,
              borderRadius: 12,
              depth: -10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Email Address',
                    icon: Icon(Icons.email),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClayContainer(
              color: baseColor,
              borderRadius: 12,
              depth: -10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _specialtyCtrl,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Specialty (e.g. CCTV, Networking)',
                    icon: Icon(Icons.star),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onTap: _saveProfile,
                  child: ClayContainer(
                    color: Colors.blueAccent,
                    height: 60,
                    borderRadius: 30,
                    depth: 20,
                    curveType: CurveType.convex,
                    child: const Center(
                      child: Text(
                        'Save Profile',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
