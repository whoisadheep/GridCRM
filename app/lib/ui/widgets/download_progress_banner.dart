import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/download_service.dart';

/// A persistent, animated download progress banner.
/// Drop this into any screen's body (e.g., as the first child of a Column/ListView)
/// and it will automatically show/hide based on download state.
class DownloadProgressBanner extends ConsumerWidget {
  const DownloadProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadProvider);

    // Only show when there's an active download or a recent completion
    if (state.status == DownloadStatus.idle) {
      return const SizedBox.shrink();
    }

    final isDownloading = state.status == DownloadStatus.downloading;
    final isCompleted = state.status == DownloadStatus.completed;
    final isFailed = state.status == DownloadStatus.failed;
    final isInstalling = state.status == DownloadStatus.installing;

    // Pick colors based on state
    final Color gradientStart;
    final Color gradientEnd;
    final Color accentColor;
    final IconData icon;

    if (isCompleted) {
      gradientStart = const Color(0xFF064E3B);
      gradientEnd = const Color(0xFF065F46);
      accentColor = Colors.greenAccent;
      icon = Icons.check_circle_rounded;
    } else if (isFailed) {
      gradientStart = const Color(0xFF7F1D1D);
      gradientEnd = const Color(0xFF991B1B);
      accentColor = Colors.redAccent;
      icon = Icons.error_rounded;
    } else {
      gradientStart = const Color(0xFF1E1B4B);
      gradientEnd = const Color(0xFF312E81);
      accentColor = Colors.cyanAccent;
      icon = Icons.downloading_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isCompleted) {
              ref.read(downloadProvider.notifier).installApk();
            } else if (isFailed) {
              // Could trigger retry, but we don't have the URL stored.
              // User can re-check for updates.
              ref.read(downloadProvider.notifier).reset();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Icon / spinner
                    if (isDownloading || isInstalling)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: isDownloading ? state.progress : null,
                          color: accentColor,
                          backgroundColor: Colors.white.withOpacity(0.15),
                        ),
                      )
                    else
                      Icon(icon, color: accentColor, size: 22),

                    const SizedBox(width: 12),

                    // Status text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDownloading
                                ? 'Updating GridCRM${state.version != null ? " v${state.version}" : ""}...'
                                : isCompleted
                                    ? 'Update ready to install'
                                    : isFailed
                                        ? 'Update failed'
                                        : 'Installing update...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.statusText,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action hint / percentage
                    if (isDownloading)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          state.progressPercent,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'INSTALL',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    if (isFailed)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                        onPressed: () => ref.read(downloadProvider.notifier).reset(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),

                // Progress bar
                if (isDownloading) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(
                          height: 4,
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          height: 4,
                          width: (MediaQuery.of(context).size.width - 60) * state.progress,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              colors: [accentColor, const Color(0xFF6366F1)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
