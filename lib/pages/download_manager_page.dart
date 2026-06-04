import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/download_task.dart';
import '../services/download_service.dart';
import '../utils/file_type_utils.dart';

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  final DownloadService _downloadService = DownloadService();

  @override
  void initState() {
    super.initState();
    _downloadService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _downloadService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _downloadService.tasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
        centerTitle: true,
        actions: [
          if (tasks.any((t) => t.status.isTerminal))
            TextButton(
              onPressed: () {
                _downloadService.clearCompleted();
              },
              child: const Text('清空已完成'),
            ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_done, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无下载任务', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return _DownloadTaskItem(
                  task: tasks[index],
                  onRetry: () => _downloadService.retryDownload(tasks[index].id),
                  onCancel: () => _downloadService.cancelDownload(tasks[index].id),
                  onRemove: () => _downloadService.removeTask(tasks[index].id),
                  onDeleteFile: () => _downloadService.removeTask(tasks[index].id, deleteFile: true),
                  onOpen: () => _openFile(tasks[index]),
                );
              },
            ),
    );
  }

  void _openFile(AppDownloadTask task) async {
    if (task.savePath.isEmpty) return;
    final file = File(task.savePath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件不存在')),
        );
      }
      return;
    }

    final suffix = p.extension(task.fileName);
    final localPath = task.savePath;

    if (FileTypeUtils.isVideo(suffix)) {
      context.push('/video-play', extra: {
        'url': localPath,
        'videoList': <dynamic>[],
        'currentIndex': 0,
      });
    } else if (FileTypeUtils.isImg(suffix)) {
      _showImagePreview(localPath);
    } else if (FileTypeUtils.isAudio(suffix)) {
      context.push('/audio-play?url=${Uri.encodeComponent(localPath)}');
    } else if (FileTypeUtils.isText(suffix)) {
      context.push('/text-view', extra: {
        'url': localPath,
        'fileName': task.fileName,
      });
    } else {
      // 其他文件类型，用系统默认应用打开
      final uri = Uri.file(task.savePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _showImagePreview(String filePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            PhotoView(
              imageProvider: FileImage(File(filePath)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 5,
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTaskItem extends StatelessWidget {
  final AppDownloadTask task;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final VoidCallback onRemove;
  final VoidCallback onDeleteFile;
  final VoidCallback onOpen;

  const _DownloadTaskItem({
    required this.task,
    required this.onRetry,
    required this.onCancel,
    required this.onRemove,
    required this.onDeleteFile,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final canOpen = task.status == AppDownloadStatus.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: canOpen ? onOpen : null,
        child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.fileName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buildInfoText(),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  _buildActions(context),
                ],
              ),
              if (task.status == AppDownloadStatus.downloading ||
                  task.status == AppDownloadStatus.enqueued) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: task.progress > 0 ? task.progress : null,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(height: 4),
                Text(
                  '${(task.progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (task.status) {
      case AppDownloadStatus.enqueued:
        return const Icon(Icons.hourglass_empty, size: 24, color: Colors.orange);
      case AppDownloadStatus.downloading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case AppDownloadStatus.completed:
        return const Icon(Icons.check_circle, size: 24, color: Colors.green);
      case AppDownloadStatus.failed:
        return const Icon(Icons.error, size: 24, color: Colors.red);
      case AppDownloadStatus.canceled:
        return const Icon(Icons.cancel, size: 24, color: Colors.grey);
      case AppDownloadStatus.paused:
        return const Icon(Icons.pause_circle, size: 24, color: Colors.orange);
    }
  }

  String _buildInfoText() {
    final sizeStr = task.fileSize > 0 ? _formatSize(task.fileSize) : '';
    switch (task.status) {
      case AppDownloadStatus.downloading:
      case AppDownloadStatus.enqueued:
        return sizeStr.isNotEmpty ? sizeStr : '下载中...';
      case AppDownloadStatus.completed:
        return '${sizeStr.isNotEmpty ? '$sizeStr · ' : ''}下载完成';
      case AppDownloadStatus.failed:
        return '下载失败';
      case AppDownloadStatus.canceled:
        return '已取消';
      case AppDownloadStatus.paused:
        return '已暂停';
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  Widget _buildActions(BuildContext context) {
    switch (task.status) {
      case AppDownloadStatus.downloading:
      case AppDownloadStatus.enqueued:
        return IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: '取消',
          onPressed: onCancel,
        );
      case AppDownloadStatus.completed:
        return IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: '删除',
          onPressed: () => _showDeleteDialog(context),
        );
      case AppDownloadStatus.failed:
      case AppDownloadStatus.canceled:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: '重试',
              onPressed: onRetry,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: '移除',
              onPressed: onRemove,
            ),
          ],
        );
      case AppDownloadStatus.paused:
        return IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: '移除',
          onPressed: onRemove,
        );
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定删除"${task.fileName}"？文件将从磁盘移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteFile();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

extension _Terminal on AppDownloadStatus {
  bool get isTerminal =>
      this == AppDownloadStatus.completed ||
      this == AppDownloadStatus.failed ||
      this == AppDownloadStatus.canceled;
}
