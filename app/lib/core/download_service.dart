import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// Represents the current state of an APK download.
enum DownloadStatus { idle, downloading, completed, failed, installing }

class DownloadState {
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String? filePath;
  final String? error;
  final String? version;

  const DownloadState({
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.filePath,
    this.error,
    this.version,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? filePath,
    String? error,
    String? version,
  }) {
    return DownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      version: version ?? this.version,
    );
  }

  bool get isActive => status == DownloadStatus.downloading || status == DownloadStatus.installing;
  
  String get progressPercent => '${(progress * 100).toStringAsFixed(0)}%';
  
  String get statusText {
    switch (status) {
      case DownloadStatus.idle:
        return 'Ready to update';
      case DownloadStatus.downloading:
        return 'Downloading $progressPercent';
      case DownloadStatus.completed:
        return 'Download complete — tap to install';
      case DownloadStatus.failed:
        return error ?? 'Download failed';
      case DownloadStatus.installing:
        return 'Installing...';
    }
  }
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  DownloadNotifier() : super(const DownloadState());

  Future<void> startDownload(String url, {String? version}) async {
    if (state.status == DownloadStatus.downloading) return; // Already downloading

    _cancelToken = CancelToken();

    state = DownloadState(
      status: DownloadStatus.downloading,
      progress: 0.0,
      version: version,
    );

    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        state = state.copyWith(status: DownloadStatus.failed, error: 'Cannot access storage');
        return;
      }

      final filePath = '${dir.path}/GridCRM-update.apk';

      // Delete old APK if it exists
      final oldFile = File(filePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      await _dio.download(
        url,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            state = state.copyWith(
              progress: received / total,
            );
          }
        },
      );

      state = state.copyWith(
        status: DownloadStatus.completed,
        filePath: filePath,
        progress: 1.0,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        state = const DownloadState(); // Reset to idle
      } else {
        state = state.copyWith(
          status: DownloadStatus.failed,
          error: 'Network error. Please try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: DownloadStatus.failed,
        error: 'Download failed. Please try again.',
      );
    }
  }

  Future<void> installApk() async {
    if (state.filePath == null) return;
    state = state.copyWith(status: DownloadStatus.installing);
    try {
      final result = await OpenFilex.open(state.filePath!);
      if (result.type != ResultType.done) {
        state = state.copyWith(
          status: DownloadStatus.failed,
          error: 'Could not open installer: ${result.message}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: DownloadStatus.failed,
        error: 'Installation failed.',
      );
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
    state = const DownloadState();
  }

  void reset() {
    _cancelToken?.cancel();
    state = const DownloadState();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>(
  (ref) => DownloadNotifier(),
);
