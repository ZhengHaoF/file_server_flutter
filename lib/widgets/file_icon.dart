import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/file_type_utils.dart';

class FileIcon extends StatelessWidget {
  final String? suffix;
  final bool isDirectory;
  final double size;
  final Color? color;
  final bool showImagePreview;
  final String? imageSrc;

  const FileIcon({
    super.key,
    this.suffix,
    required this.isDirectory,
    this.size = 24,
    this.color,
    this.showImagePreview = false,
    this.imageSrc,
  });

  @override
  Widget build(BuildContext context) {
    if (isDirectory) {
      return Icon(
        Icons.folder,
        size: size,
        color: color ?? Colors.amber,
      );
    }

    if (showImagePreview && imageSrc != null && imageSrc!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: imageSrc!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => Icon(
            _getIconData(),
            size: size * 0.6,
            color: color ?? _getIconColor(),
          ),
          errorWidget: (context, url, error) => Icon(
            _getIconData(),
            size: size * 0.6,
            color: color ?? _getIconColor(),
          ),
        ),
      );
    }

    return Icon(
      _getIconData(),
      size: size,
      color: color ?? _getIconColor(),
    );
  }

  IconData _getIconData() {
    final fileType = FileTypeUtils.determineFileType(suffix);

    switch (fileType) {
      case 'VIDEO':
        return Icons.video_file;
      case 'IMG':
        return Icons.image;
      case 'ZIP':
        return Icons.archive;
      case 'AUDIO':
        return Icons.audio_file;
      case 'DOC':
        return Icons.description;
      case 'EXCEL':
        return Icons.table_chart;
      case 'PS':
        return Icons.photo_camera;
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'DATA':
        return Icons.storage;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getIconColor() {
    final fileType = FileTypeUtils.determineFileType(suffix);

    switch (fileType) {
      case 'VIDEO':
        return Colors.purple;
      case 'IMG':
        return Colors.blue;
      case 'ZIP':
        return Colors.orange;
      case 'AUDIO':
        return Colors.green;
      case 'DOC':
        return Colors.indigo;
      case 'EXCEL':
        return Colors.teal;
      case 'PS':
        return Colors.cyan;
      case 'PDF':
        return Colors.red;
      case 'DATA':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
