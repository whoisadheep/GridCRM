import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clay_containers/clay_containers.dart';
import '../../core/settings.dart';
import 'upgrade_dialog.dart';

class TrialBanner extends ConsumerWidget {
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialStatus = ref.watch(trialStatusProvider);

    if (trialStatus.isSubscribed) {
      return const SizedBox.shrink();
    }

    final isExpired = trialStatus.isExpired;
    final remainingDays = trialStatus.daysRemaining;
    final baseColor = Theme.of(context).scaffoldBackgroundColor;

    final gradientColors = isExpired
        ? [const Color(0xFFEF4444), const Color(0xFF991B1B)]
        : (remainingDays <= 1
            ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
            : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]);

    final bannerText = isExpired
        ? '⚠️ Free Trial Expired'
        : (remainingDays == 1
            ? '⚡ 1 Day Left in Free Trial'
            : '⚡ Free Trial: $remainingDays Days Remaining');

    final subText = isExpired
        ? 'Upgrade to Grid CRM Pro to log new calls & dispatch technicians.'
        : 'Enjoy full access to all AI CRM features during your 3-day trial.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ClayContainer(
        color: baseColor,
        borderRadius: 20,
        depth: 15,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bannerText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: gradientColors[0],
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const UpgradeDialog(),
                  );
                },
                child: const Text(
                  'Upgrade',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
