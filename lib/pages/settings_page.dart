import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final StorageService _storage = StorageService();
  final ApiService _apiService = ApiService();

  late int _imgSize;
  late int _columns;
  late String _playMode;
  late String _fileSort;
  late String _folderSort;
  late Color _themeColor;
  late bool _onlyShowImages;
  late bool _viewOriginalImage;
  late bool _videoThumbnail;
  late String _serverBaseUrl;
  final _restartPwdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _imgSize = _storage.imgSize;
    _columns = _storage.columns;
    _playMode = _storage.playMode;
    _fileSort = _storage.fileSort;
    _folderSort = _storage.folderSort;
    _onlyShowImages = _storage.onlyShowImages;
    _viewOriginalImage = _storage.viewOriginalImage;
    _videoThumbnail = _storage.videoThumbnail;
    _serverBaseUrl = _apiService.serverBaseUrl;

    try {
      final colorStr = _storage.themeColor.replaceAll('#', '');
      _themeColor = Color(int.parse('FF$colorStr', radix: 16));
    } catch (e) {
      _themeColor = const Color(0xFFf6823b);
    }
  }

  @override
  void dispose() {
    _restartPwdController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    _storage.imgSize = _imgSize;
    _storage.columns = _columns;
    _storage.playMode = _playMode;
    _storage.fileSort = _fileSort;
    _storage.folderSort = _folderSort;
    _storage.onlyShowImages = _onlyShowImages;
    _storage.viewOriginalImage = _viewOriginalImage;
    _storage.videoThumbnail = _videoThumbnail;
    _storage.serverBaseUrl = _serverBaseUrl;
    _apiService.setServerUrl(_serverBaseUrl);

    final colorHex = _themeColor.toARGB32().toRadixString(16).substring(2).toUpperCase();
    _storage.themeColor = '#$colorHex';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('设置已保存')),
    );

    Navigator.pop(context);
  }

  String _normalizeServerUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return 'http://localhost:3000';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  void _showServerUrlDialog() {
    final controller = TextEditingController(text: _serverBaseUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改服务器地址'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '服务器地址',
            hintText: 'http://localhost:3000',
          ),
          autofocus: true,
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final url = _normalizeServerUrl(controller.text);
              _apiService.setServerUrl(url);
              setState(() => _serverBaseUrl = url);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _restoreDefaults() async {
    await _storage.clear();
    if (mounted) {
      setState(() {
        _imgSize = _storage.imgSize;
        _columns = _storage.columns;
        _playMode = _storage.playMode;
        _fileSort = _storage.fileSort;
        _folderSort = _storage.folderSort;
        _onlyShowImages = _storage.onlyShowImages;
        _viewOriginalImage = _storage.viewOriginalImage;
        _videoThumbnail = _storage.videoThumbnail;
        _serverBaseUrl = _storage.serverBaseUrl;

        try {
          final colorStr = _storage.themeColor.replaceAll('#', '');
          _themeColor = Color(int.parse('FF$colorStr', radix: 16));
        } catch (e) {
          _themeColor = const Color(0xFFf6823b);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复默认设置')),
      );
    }
  }

  void _restartServer() async {
    final pwd = _restartPwdController.text;
    if (pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入密码')),
      );
      return;
    }

    try {
      final result = await _apiService.restartServer(pwd);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['msg'] ?? '操作完成')),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _themeColor,
            onColorChanged: (color) {
              setState(() => _themeColor = color);
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('保存', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildSection(
            title: '服务设置',
            children: [
              ListTile(
                title: const Text('服务器地址'),
                subtitle: Text(
                  _serverBaseUrl,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.edit),
                onTap: _showServerUrlDialog,
              ),
            ],
          ),
          _buildSection(
            title: '显示设置',
            children: [
              _buildStepperTile(
                title: '预览图像素',
                value: _imgSize,
                min: 50,
                max: 5000,
                onChanged: (v) => setState(() => _imgSize = v),
              ),
              _buildStepperTile(
                title: '图片模式列数',
                value: _columns,
                min: 2,
                max: 6,
                onChanged: (v) => setState(() => _columns = v),
              ),
              _buildColorTile(),
              _buildDropdownTile(
                title: '视频打开方式',
                value: _playMode,
                items: const {
                  'ask': '每次询问',
                  'vlc': 'VLC播放',
                  'html': '本地播放器',
                },
                onChanged: (v) => setState(() => _playMode = v!),
              ),
              _buildDropdownTile(
                title: '文件排序方式',
                value: _fileSort,
                items: const {
                  'timeStoB': '时间正序',
                  'timeBtoS': '时间倒序',
                  'sizeStoB': '大小正序',
                  'sizeBtoS': '大小倒序',
                  'nameStoB': '名称正序',
                  'nameBtoS': '名称倒序',
                },
                onChanged: (v) => setState(() => _fileSort = v!),
              ),
              _buildDropdownTile(
                title: '文件夹位置',
                value: _folderSort,
                items: const {
                  'start': '最前',
                  'end': '最后',
                },
                onChanged: (v) => setState(() => _folderSort = v!),
              ),
              _buildSwitchTile(
                title: '图片模式只显示图片',
                value: _onlyShowImages,
                onChanged: (v) => setState(() => _onlyShowImages = v),
              ),
              _buildSwitchTile(
                title: '是否查看原图',
                value: _viewOriginalImage,
                onChanged: (v) => setState(() => _viewOriginalImage = v),
              ),
              _buildSwitchTile(
                title: '开启视频缩略图',
                value: _videoThumbnail,
                onChanged: (v) => setState(() => _videoThumbnail = v),
              ),
            ],
          ),
          _buildSection(
            title: '系统操作',
            children: [
              ListTile(
                title: const Text('恢复默认'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _restoreDefaults,
              ),
              _buildRestartTile(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _buildStepperTile({
    required String title,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          GestureDetector(
            onTap: () {
              final controller = TextEditingController(text: '$value');
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('设置$title'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '$min - $max',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        final input = int.tryParse(controller.text);
                        if (input != null) {
                          final clamped = input.clamp(min, max);
                          onChanged(clamped);
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$value', style: const TextStyle(fontSize: 16)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildColorTile() {
    return ListTile(
      title: const Text('主题色'),
      trailing: GestureDetector(
        onTap: _showColorPicker,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _themeColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        items: items.entries.map((e) {
          return DropdownMenuItem(value: e.key, child: Text(e.value));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildRestartTile() {
    return ListTile(
      title: const Text('重启服务器'),
      trailing: SizedBox(
        width: 160,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextField(
                controller: _restartPwdController,
                decoration: const InputDecoration(
                  hintText: '密码',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                obscureText: true,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _restartServer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('重启'),
            ),
          ],
        ),
      ),
    );
  }
}
