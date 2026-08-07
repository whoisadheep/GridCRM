import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/settings.dart';

class UpgradeDialog extends ConsumerStatefulWidget {
  const UpgradeDialog({super.key});

  @override
  ConsumerState<UpgradeDialog> createState() => _UpgradeDialogState();
}

class _UpgradeDialogState extends ConsumerState<UpgradeDialog> {
  bool _isChecking = false;

  Future<void> _checkActivationStatus() async {
    setState(() => _isChecking = true);
    try {
      final settings = ref.read(settingsProvider);
      final baseUrl = await settings.getBaseUrl();
      final role = await settings.getRole();
      final username = await settings.getAssignedTechnician() ?? 'admin';

      final response = await http.get(
        Uri.parse('$baseUrl/subscription/status?username=$username&role=$role'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isSubscribed = data['is_subscribed'] ?? false;

        if (isSubscribed) {
          await ref.read(trialStatusProvider.notifier).upgradeToPro();
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.stars, color: Colors.amber),
                    SizedBox(width: 12),
                    Text('Grid CRM Pro activated from Firebase!', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                backgroundColor: const Color(0xFF1E293B),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription not activated yet in Firebase. Please contact developer.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status check failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 28,
        depth: 25,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'GRID CRM PRO',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Unlock Unlimited Access',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Contact developer to activate your full Grid CRM Pro subscription.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Feature List
              _buildFeatureRow(Icons.auto_awesome, 'Unlimited AI Call Extraction & Voice Logs'),
              _buildFeatureRow(Icons.notifications_active, 'Instant Push Notifications to Technicians'),
              _buildFeatureRow(Icons.analytics, 'Real-time Analytics & Customer Insights'),
              _buildFeatureRow(Icons.cloud_sync, 'Unlimited Service Calls & Tech Dispatch'),

              const SizedBox(height: 20),

              // Info Card
              ClayContainer(
                color: baseColor,
                borderRadius: 18,
                depth: -10,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.contact_support_outlined, color: Color(0xFF4F46E5), size: 20),
                          SizedBox(width: 8),
                          Text('Contact Developer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4F46E5))),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blueAccent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Please contact the developer directly. Once activated, tap below to verify status.',
                              style: TextStyle(color: Colors.grey[700], fontSize: 12, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              _isChecking
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        onPressed: _checkActivationStatus,
                        icon: const Icon(Icons.sync, color: Colors.white),
                        label: const Text('Check Activation Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
              
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
