import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_update_service.dart';
import '../../core/download_service.dart';

class AppUpdateDialog extends ConsumerStatefulWidget {
  final AppUpdateInfo updateInfo;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
  });

  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startDownload() {
    ref.read(downloadProvider.notifier).startDownload(
      widget.updateInfo.updateUrl,
      version: widget.updateInfo.latestVersion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);
    final isDownloading = downloadState.status == DownloadStatus.downloading;
    final isCompleted = downloadState.status == DownloadStatus.completed;
    final isFailed = downloadState.status == DownloadStatus.failed;

    return PopScope(
      canPop: !widget.updateInfo.forceUpdate && !isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                color: const Color(0xFF0F3460).withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueAccent.withOpacity(0.3),
                          Colors.cyanAccent.withOpacity(0.15),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.cyanAccent.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      size: 40,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Colors.cyanAccent],
                  ).createShader(bounds),
                  child: const Text(
                    'New Update Available!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 6),

                // Version badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.cyanAccent.withOpacity(0.12),
                    border: Border.all(
                      color: Colors.cyanAccent.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    'v${widget.updateInfo.currentVersion}  →  v${widget.updateInfo.latestVersion}',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Release notes card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 16, color: Colors.amber[300]),
                          const SizedBox(width: 6),
                          Text(
                            "What's New",
                            style: TextStyle(
                              color: Colors.amber[300],
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.updateInfo.releaseNotes,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Progress section (visible when downloading/completed/failed)
                if (isDownloading || isCompleted || isFailed)
                  _buildProgressSection(downloadState),

                if (isDownloading || isCompleted || isFailed)
                  const SizedBox(height: 20),

                // Buttons
                _buildButtons(downloadState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(DownloadState state) {
    final isDownloading = state.status == DownloadStatus.downloading;
    final isCompleted = state.status == DownloadStatus.completed;
    final isFailed = state.status == DownloadStatus.failed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? Colors.greenAccent.withOpacity(0.3)
              : isFailed
                  ? Colors.redAccent.withOpacity(0.3)
                  : Colors.cyanAccent.withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          // Status row
          Row(
            children: [
              if (isDownloading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value: state.progress,
                    color: Colors.cyanAccent,
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),
              if (isCompleted)
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
              if (isFailed)
                const Icon(Icons.error_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.statusText,
                  style: TextStyle(
                    color: isCompleted
                        ? Colors.greenAccent
                        : isFailed
                            ? Colors.redAccent
                            : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isDownloading)
                Text(
                  state.progressPercent,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 12),
            // Animated progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    height: 6,
                    width: (MediaQuery.of(context).size.width - 150) * state.progress,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: [Colors.cyanAccent, Color(0xFF6366F1)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.5),
                          blurRadius: 8,
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
    );
  }

  Widget _buildButtons(DownloadState state) {
    final isDownloading = state.status == DownloadStatus.downloading;
    final isCompleted = state.status == DownloadStatus.completed;
    final isFailed = state.status == DownloadStatus.failed;
    final isIdle = state.status == DownloadStatus.idle;

    return Row(
      children: [
        // Later / Cancel button
        if (!widget.updateInfo.forceUpdate || isDownloading)
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                if (isDownloading) {
                  ref.read(downloadProvider.notifier).cancelDownload();
                }
                if (!widget.updateInfo.forceUpdate) {
                  Navigator.pop(context);
                }
              },
              child: Text(
                isDownloading ? 'Cancel' : 'Later',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (!widget.updateInfo.forceUpdate || isDownloading)
          const SizedBox(width: 12),

        // Primary action button
        Expanded(
          flex: widget.updateInfo.forceUpdate && !isDownloading ? 2 : 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: isCompleted
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : isFailed
                        ? [Colors.redAccent, Colors.red]
                        : [const Color(0xFF6366F1), Colors.cyanAccent],
              ),
              boxShadow: [
                if (!isDownloading)
                  BoxShadow(
                    color: (isCompleted
                            ? Colors.greenAccent
                            : isFailed
                                ? Colors.redAccent
                                : Colors.cyanAccent)
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: isDownloading
                  ? null
                  : () {
                      if (isIdle || isFailed) {
                        _startDownload();
                      } else if (isCompleted) {
                        ref.read(downloadProvider.notifier).installApk();
                        Navigator.pop(context);
                      }
                    },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isDownloading) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Downloading...', style: TextStyle(fontWeight: FontWeight.w700)),
                    ] else if (isCompleted) ...[
                      const Icon(Icons.install_mobile_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('Install Now', style: TextStyle(fontWeight: FontWeight.w700)),
                    ] else if (isFailed) ...[
                      const Icon(Icons.refresh_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                    ] else ...[
                      const Icon(Icons.download_rounded, size: 18),
                      const SizedBox(width: 8),
                      const Text('Download & Install', style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
