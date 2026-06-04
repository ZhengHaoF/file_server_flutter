import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_task.dart';

const _kTasksKey = 'download_tasks';
const _kMaxTasks = 200;
const _kChannel = MethodChannel('com.example.flutter_application_1/storage');

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio();
  final List<AppDownloadTask> _tasks = [];
  final Map<String, CancelToken> _cancelTokens = {};
  bool _initialized = false;
  String _tempDir = '';

  List<AppDownloadTask> get tasks => List.unmodifiable(_tasks);

  int get activeCount =>
      _tasks.where((t) =>
          t.status == AppDownloadStatus.downloading ||
          t.status == AppDownloadStatus.enqueued).length;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final tempDir = await getTemporaryDirectory();
    _tempDir = tempDir.path;

    await _loadTasks();
  }

  /// Android 版本号（如 14、13），非 Android 平台返回 0
  int get _androidVersion {
    if (!Platform.isAndroid) return 0;
    final ver = Platform.operatingSystemVersion;
    final match = RegExp(r'^(\d+)').firstMatch(ver);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  /// 计算文件的最终保存路径
  Future<String> _resolveSavePath(String fileName) async {
    if (Platform.isAndroid) {
      // Android 10+：下载到临时目录（后续会插入 MediaStore，保留临时文件用于预览）
      // Android 9-：直接写公共 Download 目录
      if (_androidVersion >= 10) {
        return '$_tempDir/$fileName';
      }
      final result =
          await _kChannel.invokeMethod<String>('getExternalDownloads');
      if (result != null) {
        final dir = Directory('$result/Z-Files');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return '${dir.path}/$fileName';
      }
      return '$_tempDir/$fileName';
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      String home;
      if (Platform.isWindows) {
        home = Platform.environment['USERPROFILE'] ?? '';
      } else {
        home = Platform.environment['HOME'] ?? '';
      }
      if (home.isNotEmpty) {
        final dir = Directory('$home/Downloads/Z-Files');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return '${dir.path}/$fileName';
      }
    }

    // iOS / Web：使用临时目录
    return '$_tempDir/$fileName';
  }

  Future<void> startDownload(String url, String fileName, String filePath,
      {int fileSize = 0}) async {
    // 检查是否已在下载列表中
    final exists = _tasks.any((t) => t.url == url && !t.status.isTerminal);
    if (exists) return;

    // 限制任务数量，清理已完成的旧任务
    if (_tasks.length >= _kMaxTasks) {
      _tasks.removeWhere((t) => t.status.isTerminal);
      if (_tasks.length >= _kMaxTasks) {
        _tasks.removeRange(0, _tasks.length - _kMaxTasks + 1);
      }
    }

    final taskId = DateTime.now().microsecondsSinceEpoch.toString();
    final savePath = await _resolveSavePath(fileName);

    final task = AppDownloadTask(
      id: taskId,
      url: url,
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
    );
    task.savePath = savePath;

    _tasks.insert(0, task);
    _saveTasks();
    notifyListeners();

    // 异步执行下载，不阻塞调用方
    _executeDownload(task);
  }

  Future<void> _executeDownload(AppDownloadTask task) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    task.status = AppDownloadStatus.downloading;
    notifyListeners();

    try {
      await _dio.download(
        task.url,
        task.savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            task.progress = received / total;
            notifyListeners();
          }
        },
      );

      if (cancelToken.isCancelled) return;

      // Android 10+ 需要额外插入 MediaStore（临时文件保留用于预览）
      if (Platform.isAndroid && _androidVersion >= 10) {
        final tempFile = File(task.savePath);
        if (await tempFile.exists()) {
          await _insertToMediaStore(tempFile, task.fileName);
          // 临时文件不删除，task.savePath 指向它，用于 App 内预览
        }
      }

      task.status = AppDownloadStatus.completed;
      task.progress = 1.0;
      task.completedAt = DateTime.now();
    } on DioException catch (e) {
      if (cancelToken.isCancelled) return;

      task.status = AppDownloadStatus.failed;
      debugPrint('下载失败 [${e.type}]: ${e.message}');
      debugPrint('  URL: ${task.url}');
      debugPrint('  状态码: ${e.response?.statusCode}');
      debugPrint('  响应: ${e.response?.data}');
    } catch (e) {
      if (cancelToken.isCancelled) return;

      task.status = AppDownloadStatus.failed;
      debugPrint('下载失败: $e');
      debugPrint('  URL: ${task.url}');
      debugPrint('  保存路径: ${task.savePath}');
    } finally {
      _cancelTokens.remove(task.id);
      _saveTasks();
      notifyListeners();
    }
  }

  // ── Android 10+：通过 MediaStore 插入公共目录 ──

  Future<void> _insertToMediaStore(File tempFile, String fileName) async {
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
    final isMedia =
        mimeType.startsWith('image/') || mimeType.startsWith('video/');

    final uri = await _kChannel.invokeMethod<String>('insertMediaStore', {
      'fileName': fileName,
      'mimeType': mimeType,
      'isMedia': isMedia,
      'tempFilePath': tempFile.path,
    });

    if (uri != null) {
      debugPrint('已保存到 MediaStore: $uri');
    }
  }

  // ── 任务管理 ──

  Future<void> cancelDownload(String taskId) async {
    final cancelToken = _cancelTokens[taskId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('用户取消');
    }

    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    _tasks[index].status = AppDownloadStatus.canceled;
    _saveTasks();
    notifyListeners();
  }

  Future<void> retryDownload(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.status != AppDownloadStatus.failed &&
        task.status != AppDownloadStatus.canceled) {
      return;
    }

    task.id = DateTime.now().microsecondsSinceEpoch.toString();
    task.status = AppDownloadStatus.enqueued;
    task.progress = 0.0;
    task.completedAt = null;
    _saveTasks();
    notifyListeners();

    _executeDownload(task);
  }

  /// 移除任务记录，可选删除磁盘文件
  void removeTask(String taskId, {bool deleteFile = false}) {
    _cancelTokens[taskId]?.cancel('移除任务');
    _cancelTokens.remove(taskId);

    if (deleteFile) {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _deleteLocalFile(_tasks[index].savePath);
      }
    }

    _tasks.removeWhere((t) => t.id == taskId);
    _saveTasks();
    notifyListeners();
  }

  Future<void> _deleteLocalFile(String path) async {
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('删除文件失败: $e');
    }
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status.isTerminal);
    _saveTasks();
    notifyListeners();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kTasksKey) ?? '';
    final loaded = AppDownloadTask.listFromJson(json);
    _tasks.clear();
    _tasks.addAll(loaded);

    // 恢复后，之前 downloading 的任务标记为 failed（重启后无法恢复）
    for (final task in _tasks) {
      if (task.status == AppDownloadStatus.downloading ||
          task.status == AppDownloadStatus.enqueued) {
        task.status = AppDownloadStatus.failed;
      }
    }
    notifyListeners();
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTasksKey, AppDownloadTask.listToJson(_tasks));
  }
}

extension _TaskStatusExt on AppDownloadStatus {
  bool get isTerminal =>
      this == AppDownloadStatus.completed ||
      this == AppDownloadStatus.failed ||
      this == AppDownloadStatus.canceled;
}
