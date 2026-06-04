import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/file_info.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';
import '../utils/date_utils.dart';
import '../utils/file_type_utils.dart';
import '../widgets/file_icon.dart';
import '../widgets/network_log_dialog.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final String? path;

  const HomePage({super.key, this.path});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  final StorageService _storage = StorageService();

  List<FileInfo> _fileList = [];
  bool _isLoading = false;
  String _currentPath = '';
  String _viewMode = 'list';
  bool _hasDialogOpen = false;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.path ?? '';
    _viewMode = _storage.model;
    _loadFileList();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _currentPath = widget.path ?? '';
      _loadFileList();
    }
  }

  Future<void> _loadFileList() async {
    setState(() => _isLoading = true);

    try {
      final list = await _apiService.getFileList(_currentPath);
      setState(() {
        _fileList = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _fileList = [];
        _isLoading = false;
      });
      if (e is Exception && e.toString().contains('404')) {
        _goToRoot();
      } else if (mounted) {
        final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  List<FileInfo> _getSortedFileList() {
    List<FileInfo> sorted = List.from(_fileList);

    switch (_storage.fileSort) {
      case 'timeStoB':
        sorted.sort((a, b) => a.mtime.compareTo(b.mtime));
        break;
      case 'timeBtoS':
        sorted.sort((a, b) => b.mtime.compareTo(a.mtime));
        break;
      case 'sizeStoB':
        sorted.sort((a, b) => b.sizeRow.compareTo(a.sizeRow));
        break;
      case 'sizeBtoS':
        sorted.sort((a, b) => a.sizeRow.compareTo(b.sizeRow));
        break;
      case 'nameStoB':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'nameBtoS':
        sorted.sort((a, b) => b.name.compareTo(a.name));
        break;
    }

    if (_storage.folderSort == 'start') {
      final folders = sorted.where((f) => f.isDirectory).toList();
      final files = sorted.where((f) => f.isFile).toList();
      return [...folders, ...files];
    } else {
      final folders = sorted.where((f) => f.isDirectory).toList();
      final files = sorted.where((f) => f.isFile).toList();
      return [...files, ...folders];
    }
  }

  List<FileInfo> _getImageFilteredFileList() {
    if (!_storage.onlyShowImages) return _getSortedFileList();
    return _getSortedFileList().where((file) {
      return file.isDirectory || FileTypeUtils.isImg(file.suffix);
    }).toList();
  }

  String get _pathDisplayText {
    if (_currentPath.isEmpty) return '根目录';
    final segments = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
    return segments.last;
  }

  bool get _isRoot => _currentPath.isEmpty;

  void _enterDirectory(String dirName) {
    final newPath = _currentPath.isNotEmpty ? '$_currentPath/$dirName' : dirName;
    context.push('/browse', extra: newPath);
  }

  void _goToRoot() {
    context.go('/');
  }

  Color get _themeColor {
    try {
      final colorStr = _storage.themeColor.replaceAll('#', '');
      return Color(int.parse('FF$colorStr', radix: 16));
    } catch (e) {
      return const Color(0xFFf6823b);
    }
  }

  void _onFileTap(int index) {
    final files = _viewMode == 'img' ? _getImageFilteredFileList() : _getSortedFileList();
    if (index >= files.length) return;

    final fileInfo = files[index];

    if (fileInfo.isDirectory) {
      _enterDirectory(fileInfo.name);
      return;
    }

    final suffix = fileInfo.suffix ?? '';

    if (FileTypeUtils.isVideo(suffix)) {
      _showVideoActions(fileInfo, index);
    } else if (FileTypeUtils.isImg(suffix)) {
      _showMediaActions(fileInfo, index);
    } else if (FileTypeUtils.isAudio(suffix)) {
      context.push('/audio-play?url=${Uri.encodeComponent(fileInfo.url ?? '')}');
    } else if (FileTypeUtils.isText(suffix)) {
      context.push('/text-view', extra: {
        'url': fileInfo.url ?? '',
        'fileName': fileInfo.name,
      });
    } else {
      _showFileActions(fileInfo, index);
    }
  }

  void _onFileLongPress(int index) {
    final files = _viewMode == 'img' ? _getImageFilteredFileList() : _getSortedFileList();
    if (index >= files.length) return;

    final fileInfo = files[index];

    if (fileInfo.isDirectory) {
      _showFolderActions(fileInfo, index);
    } else {
      final suffix = fileInfo.suffix ?? '';
      if (FileTypeUtils.isVideo(suffix) || FileTypeUtils.isImg(suffix)) {
        _showMediaActions(fileInfo, index);
      } else {
        _showFileActions(fileInfo, index);
      }
    }
  }

  void _showVideoActions(FileInfo fileInfo, int index) {
    final playMode = _storage.playMode;

    if (playMode == 'vlc') {
      _launchVlc(fileInfo.url ?? '');
    } else if (playMode == 'html') {
      _openVideoPlayer(fileInfo);
    } else {
      setState(() => _hasDialogOpen = true);
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_circle),
                title: const Text('本地播放器'),
                onTap: () {
                  Navigator.pop(context);
                  _openVideoPlayer(fileInfo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('VLC 播放'),
                onTap: () {
                  Navigator.pop(context);
                  _launchVlc(fileInfo.url ?? '');
                },
              ),
              ListTile(
                leading: const Text('取消'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ).then((_) {
        if (mounted) setState(() => _hasDialogOpen = false);
      });
    }
  }

  void _openVideoPlayer(FileInfo fileInfo) {
    final videoList = _fileList.where((f) => FileTypeUtils.isVideo(f.suffix)).toList();
    final currentIndex = videoList.indexWhere((v) => v.name == fileInfo.name);

    context.push('/video-play', extra: {
      'url': fileInfo.url ?? '',
      'videoList': videoList,
      'currentIndex': currentIndex >= 0 ? currentIndex : 0,
    });
  }

  void _launchVlc(String url) async {
    final vlcUrl = 'vlc://$url';
    final uri = Uri.parse(vlcUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showMediaActions(FileInfo fileInfo, int index) {
    setState(() => _hasDialogOpen = true);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('预览'),
              onTap: () {
                Navigator.pop(context);
                _previewFile(fileInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制链接'),
              onTap: () {
                Navigator.pop(context);
                _copyUrl(fileInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('下载'),
              onTap: () {
                Navigator.pop(context);
                _downloadFile(fileInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(context);
                _confirmRename(fileInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(fileInfo);
              },
            ),
            ListTile(
              leading: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _hasDialogOpen = false);
    });
  }

  void _showFileActions(FileInfo fileInfo, int index) {
    setState(() => _hasDialogOpen = true);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制链接'),
              onTap: () {
                Navigator.pop(context);
                _copyUrl(fileInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('下载'),
              onTap: () {
                Navigator.pop(context);
                _downloadFile(fileInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(context);
                _confirmRename(fileInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(fileInfo);
              },
            ),
            ListTile(
              leading: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _hasDialogOpen = false);
    });
  }

  void _showFolderActions(FileInfo fileInfo, int index) {
    setState(() => _hasDialogOpen = true);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制链接'),
              onTap: () {
                Navigator.pop(context);
                _copyUrl(fileInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(context);
                _confirmRename(fileInfo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(fileInfo);
              },
            ),
            ListTile(
              leading: const Text('取消'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _hasDialogOpen = false);
    });
  }

  void _previewFile(FileInfo fileInfo) {
    final suffix = fileInfo.suffix ?? '';
    if (FileTypeUtils.isVideo(suffix)) {
      _openVideoPlayer(fileInfo);
    } else if (FileTypeUtils.isImg(suffix)) {
      _showImagePreview(fileInfo);
    }
  }

  void _showImagePreview(FileInfo fileInfo) {
    final imageFiles = _getSortedFileList()
        .where((f) => FileTypeUtils.isImg(f.suffix))
        .toList();
    final currentIndex = imageFiles.indexWhere((f) => f.name == fileInfo.name);

    final imageUrls = imageFiles.map((f) {
      if (_storage.viewOriginalImage) {
        return f.url ?? '';
      }
      final w = (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).round();
      return '${f.url}!${w}x$w';
    }).toList();

    final heroTags = imageFiles.map((f) => 'grid_image_${f.name}').toList();

    setState(() => _hasDialogOpen = true);
    showDialog(
      context: context,
      builder: (context) => _ImagePreviewDialog(
        imageUrls: imageUrls,
        heroTags: heroTags,
        initialIndex: currentIndex >= 0 ? currentIndex : 0,
      ),
    ).then((_) {
      if (mounted) setState(() => _hasDialogOpen = false);
    });
  }

  void _copyUrl(FileInfo fileInfo) {
    final url = fileInfo.url ?? '';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('链接已复制到剪贴板')),
    );
  }

  void _downloadFile(FileInfo fileInfo) async {
    final url = fileInfo.url ?? '';
    if (kIsWeb) {
      // Web 端降级到浏览器下载
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      // 非 Web 端使用内置下载管理
      DownloadService().startDownload(
        url,
        fileInfo.name,
        fileInfo.path ?? '',
        fileSize: fileInfo.sizeRow,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已加入下载队列')),
        );
      }
    }
  }

  void _confirmDelete(FileInfo fileInfo) {
    final isFolder = fileInfo.isDirectory && !fileInfo.isFile;
    final title = isFolder ? '删除文件夹' : '删除文件';
    final message = isFolder
        ? '确定要删除文件夹"${fileInfo.name}"吗？文件夹内的所有内容都将被删除。'
        : '确定要删除文件"${fileInfo.name}"吗？';

    setState(() => _hasDialogOpen = true);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFile(fileInfo);
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() => _hasDialogOpen = false);
    });
  }

  Future<void> _deleteFile(FileInfo fileInfo) async {
    final filePath = fileInfo.path ?? '';
    try {
      final success = await _apiService.deleteFile(filePath);
      if (success) {
        _loadFileList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $msg')),
        );
      }
    }
  }

  void _confirmRename(FileInfo fileInfo) {
    final controller = TextEditingController(text: fileInfo.name);

    setState(() => _hasDialogOpen = true);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: fileInfo.isDirectory ? '文件夹名称' : '文件名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _renameFile(fileInfo, controller.text);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() => _hasDialogOpen = false);
    });
  }

  Future<void> _renameFile(FileInfo fileInfo, String newName) async {
    if (newName.isEmpty || newName == fileInfo.name) return;

    final oldPath = fileInfo.path ?? '';
    final lastSlash = oldPath.lastIndexOf('/');
    final parentPath = lastSlash >= 0 ? oldPath.substring(0, lastSlash + 1) : '';
    final newPath = '$parentPath$newName';

    try {
      await _apiService.renameFile(oldPath, newPath);
      _loadFileList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('重命名成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重命名失败: $msg')),
        );
      }
    }
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == 'list' ? 'img' : 'list';
      _storage.model = _viewMode;
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    ).then((_) {
      setState(() {});
      _loadFileList();
    });
  }

  void _handleWillPop(BuildContext context) {
    if (_hasDialogOpen) {
      setState(() => _hasDialogOpen = false);
      Navigator.of(context).pop();
      return;
    }

    if (_lastBackPress == null ||
        DateTime.now().difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = DateTime.now();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('再按一次返回关闭软件'), duration: Duration(seconds: 2)),
      );
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _viewMode == 'img' ? _getImageFilteredFileList() : _getSortedFileList();

    return PopScope(
      canPop: !_isRoot,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleWillPop(context);
      },
      child: Scaffold(
      appBar: AppBar(
        leading: _isRoot
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
        title: Text(
          _pathDisplayText,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: '下载管理',
              onPressed: () => context.push('/downloads'),
            ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: '网络日志',
            onPressed: () => NetworkLogDialog.show(context),
          ),
          IconButton(
            icon: Icon(_viewMode == 'list' ? Icons.grid_view : Icons.list),
            onPressed: _toggleViewMode,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (files.isEmpty && !_isLoading)
            const Center(child: Text('当前数据为空'))
          else
            _viewMode == 'list'
                ? _buildListView(files)
                : _buildGridView(files),
          if (_isLoading)
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('加载中···', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildListView(List<FileInfo> files) {
    return RefreshIndicator(
      onRefresh: _loadFileList,
      child: ListView.builder(
        itemCount: files.length + 1,
        itemBuilder: (context, index) {
          if (index == files.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('到底了···', style: TextStyle(color: Colors.grey)),
              ),
            );
          }

          final file = files[index];
          return _buildListItem(file, index);
        },
      ),
    );
  }

  Widget _buildListItem(FileInfo file, int index) {
    return InkWell(
      onTap: () => _onFileTap(index),
      onLongPress: () => _onFileLongPress(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            FileIcon(
              suffix: file.suffix,
              isDirectory: file.isDirectory,
              size: 24,
              color: _themeColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppDateUtils.formatDateTime(file.mtime),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      if (file.isFile)
                        Text(
                          file.size,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<FileInfo> files) {
    final columns = _storage.columns;

    return RefreshIndicator(
      onRefresh: _loadFileList,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 0.8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          return _buildGridItem(file, index);
        },
      ),
    );
  }

  Widget _buildGridItem(FileInfo file, int index) {
    final suffix = file.suffix ?? '';
    final isImage = FileTypeUtils.isImg(suffix);
    final isVideo = FileTypeUtils.isVideo(suffix);
    final showPreview = isImage || (isVideo && _storage.videoThumbnail);

    String? previewUrl;
    if (showPreview) {
      if (isVideo && _storage.videoThumbnail) {
        previewUrl = _apiService.getVideoPreviewUrl(file.path ?? '');
      } else if (isImage) {
        final w = _storage.imgSize;
        previewUrl = '${file.url}!${w}x$w';
      }
    }

    return InkWell(
      onTap: () => _onFileTap(index),
      onLongPress: () => _onFileLongPress(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: showPreview && previewUrl != null
                  ? Hero(
                      tag: 'grid_image_${file.name}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          previewUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) => FileIcon(
                            suffix: file.suffix,
                            isDirectory: file.isDirectory,
                            size: 48,
                            color: _themeColor,
                          ),
                        ),
                      ),
                    )
                  : FileIcon(
                      suffix: file.suffix,
                      isDirectory: file.isDirectory,
                      size: 48,
                      color: _themeColor,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              file.name,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewDialog extends StatefulWidget {
  final List<String> imageUrls;
  final List<String> heroTags;
  final int initialIndex;

  const _ImagePreviewDialog({
    required this.imageUrls,
    required this.heroTags,
    required this.initialIndex,
  });

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                 imageProvider: NetworkImage(widget.imageUrls[index]),
                 heroAttributes: PhotoViewHeroAttributes(tag: widget.heroTags[index]),
                 minScale: PhotoViewComputedScale.contained,
                 maxScale: PhotoViewComputedScale.covered * 5,
                 errorBuilder: (context, error, stackTrace) =>
                     const Icon(Icons.broken_image, color: Colors.white, size: 64),
               );
            },
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
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
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.imageUrls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
