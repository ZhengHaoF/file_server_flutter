class FileInfo {
  final String name;
  final String? suffix;
  final int sizeRow;
  final String size;
  final String mtime;
  final bool isFile;
  final bool isDirectory;
  final String? url;
  final String? path;

  FileInfo({
    required this.name,
    this.suffix,
    required this.sizeRow,
    required this.size,
    required this.mtime,
    required this.isFile,
    required this.isDirectory,
    this.url,
    this.path,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json, String currentPath, String serverBaseUrl) {
    final name = json['name'] ?? '';
    final isDirectory = json['isDirectory'] ?? false;
    final sizeValue = (json['size'] as num?)?.toInt() ?? 0;

    String suffix = '';
    if (!isDirectory && name.contains('.')) {
      suffix = name.substring(name.lastIndexOf('.'));
    }

    String displaySize = '';
    if (!isDirectory) {
      displaySize = '${(sizeValue / 1024 / 1024).toStringAsFixed(2)}MB';
    }

    String? fileUrl;
    final filePath = currentPath.isNotEmpty ? '$currentPath/$name' : name;
    if (!isDirectory) {
      final cleanPath = currentPath.isNotEmpty ? '/$currentPath' : '';
      fileUrl = '$serverBaseUrl/getFile$cleanPath/${Uri.encodeComponent(name)}';
    }

    return FileInfo(
      name: name,
      suffix: suffix,
      sizeRow: sizeValue,
      size: displaySize,
      mtime: json['mtime'] ?? '',
      isFile: json['isFile'] ?? false,
      isDirectory: isDirectory,
      url: fileUrl,
      path: filePath,
    );
  }
}
