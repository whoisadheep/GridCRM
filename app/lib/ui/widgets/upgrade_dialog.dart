import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/settings.dart';

class UpgradeDialog extends ConsumerStatefulWidget {
  const UpgradeDialog({super.key});

  @override
  ConsumerState<UpgradeDialog> createState() => _UpgradeDialogState();
}

class _UpgradeDialogState extends ConsumerState<UpgradeDialog>
    with SingleTickerProviderStateMixin {
  bool _isChecking = false;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

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
                    Text('Grid CRM Pro activated!',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                backgroundColor: const Color(0xFF1E293B),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Subscription not activated yet. Please contact developer.'),
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

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.15),
                  const Color(0xFF8B5CF6).withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: Colors.greenAccent.withOpacity(0.7), size: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Crown icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: Colors.amber,
                  size: 36,
                ),
              ),

              const SizedBox(height: 20),

              // PRO badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                ),
                child: const Text(
                  'GRID CRM PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Title
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Color(0xFFA5B4FC)],
                ).createShader(bounds),
                child: const Text(
                  'Unlock Unlimited Power',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Contact the developer to activate your Pro subscription.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Feature list
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      Icons.auto_awesome,
                      'AI Call Extraction',
                      'Unlimited voice-to-text & smart dispatch',
                    ),
                    Divider(
                        color: Colors.white.withOpacity(0.06), height: 1),
                    _buildFeatureRow(
                      Icons.notifications_active,
                      'Push Notifications',
                      'Instant alerts to technicians in the field',
                    ),
                    Divider(
                        color: Colors.white.withOpacity(0.06), height: 1),
                    _buildFeatureRow(
                      Icons.analytics_rounded,
                      'Analytics Dashboard',
                      'Real-time insights & customer reports',
                    ),
                    Divider(
                        color: Colors.white.withOpacity(0.06), height: 1),
                    _buildFeatureRow(
                      Icons.cloud_sync,
                      'Unlimited Calls',
                      'No caps on service calls & technicians',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // CTA button
              _isChecking
                  ? Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF6366F1).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _checkActivationStatus,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sync_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Check Activation Status',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

              const SizedBox(height: 12),

              // Close button
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
