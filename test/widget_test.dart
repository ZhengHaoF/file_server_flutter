import 'package:flutter_test/flutter_test.dart';

import 'package:z_files/models/file_info.dart';
import 'package:z_files/utils/date_utils.dart';
import 'package:z_files/utils/file_type_utils.dart';

void main() {
  group('FileTypeUtils', () {
    test('isVideo 正确识别视频扩展名', () {
      expect(FileTypeUtils.isVideo('.MP4'), true);
      expect(FileTypeUtils.isVideo('.mp4'), true);
      expect(FileTypeUtils.isVideo('.mkv'), true);
      expect(FileTypeUtils.isVideo('.avi'), true);
      expect(FileTypeUtils.isVideo('.txt'), false);
      expect(FileTypeUtils.isVideo(null), false);
      expect(FileTypeUtils.isVideo(''), false);
    });

    test('isImg 正确识别图片扩展名', () {
      expect(FileTypeUtils.isImg('.JPG'), true);
      expect(FileTypeUtils.isImg('.png'), true);
      expect(FileTypeUtils.isImg('.webp'), true);
      expect(FileTypeUtils.isImg('.mp4'), false);
      expect(FileTypeUtils.isImg(null), false);
    });

    test('isAudio 正确识别音频扩展名', () {
      expect(FileTypeUtils.isAudio('.MP3'), true);
      expect(FileTypeUtils.isAudio('.wav'), true);
      expect(FileTypeUtils.isAudio('.ogg'), true);
      expect(FileTypeUtils.isAudio('.txt'), false);
    });

    test('isZip 正确识别压缩文件扩展名', () {
      expect(FileTypeUtils.isZip('.ZIP'), true);
      expect(FileTypeUtils.isZip('.rar'), true);
      expect(FileTypeUtils.isZip('.7z'), true);
      expect(FileTypeUtils.isZip('.txt'), false);
    });

    test('determineFileType 返回正确的类型标识', () {
      expect(FileTypeUtils.determineFileType('.mp4'), 'VIDEO');
      expect(FileTypeUtils.determineFileType('.jpg'), 'IMG');
      expect(FileTypeUtils.determineFileType('.zip'), 'ZIP');
      expect(FileTypeUtils.determineFileType('.mp3'), 'AUDIO');
      expect(FileTypeUtils.determineFileType('.pdf'), 'PDF');
      expect(FileTypeUtils.determineFileType('.xyz'), 'UNKNOWN');
      expect(FileTypeUtils.determineFileType(null), 'UNKNOWN');
    });
  });

  group('AppDateUtils', () {
    test('formatDateTime 格式化完整时间', () {
      final result = AppDateUtils.formatDateTime('2025-01-15T08:30:45.000');
      expect(result, '2025-01-15 08:30:45');
    });

    test('formatDateTime 自定义格式', () {
      final result = AppDateUtils.formatDateTime(
        '2025-01-15T08:30:45.000',
        format: '{y}/{m}/{d}',
      );
      expect(result, '2025/01/15');
    });

    test('formatDateTime 空值返回空字符串', () {
      expect(AppDateUtils.formatDateTime(null), '');
      expect(AppDateUtils.formatDateTime(''), '');
    });

    test('formatDateTime 无效字符串原样返回', () {
      expect(AppDateUtils.formatDateTime('not-a-date'), 'not-a-date');
    });
  });

  group('FileInfo.fromJson', () {
    test('正确解析文件信息', () {
      final json = {
        'name': 'test.mp4',
        'size': 1048576,
        'mtime': '2025-01-15T08:30:00.000',
        'isFile': true,
        'isDirectory': false,
      };

      final info = FileInfo.fromJson(json, 'videos', 'http://localhost:3000');

      expect(info.name, 'test.mp4');
      expect(info.suffix, '.mp4');
      expect(info.sizeRow, 1048576);
      expect(info.size, '1.00MB');
      expect(info.isFile, true);
      expect(info.isDirectory, false);
      expect(info.path, 'videos/test.mp4');
      expect(info.url, 'http://localhost:3000/getFile/videos/test.mp4');
    });

    test('正确解析文件夹信息', () {
      final json = {
        'name': 'myFolder',
        'size': 0,
        'mtime': '2025-01-15T08:30:00.000',
        'isFile': false,
        'isDirectory': true,
      };

      final info = FileInfo.fromJson(json, '', 'http://localhost:3000');

      expect(info.name, 'myFolder');
      expect(info.suffix, '');
      expect(info.isDirectory, true);
      expect(info.url, isNull);
      expect(info.path, 'myFolder');
    });

    test('子目录下文件夹的 path 包含父路径', () {
      final json = {
        'name': 'subFolder',
        'size': 0,
        'mtime': '2025-01-15T08:30:00.000',
        'isFile': false,
        'isDirectory': true,
      };

      final info = FileInfo.fromJson(json, 'parentDir', 'http://localhost:3000');

      expect(info.path, 'parentDir/subFolder');
      expect(info.url, isNull);
    });

    test('根目录下文件的 path 和 url 正确', () {
      final json = {
        'name': 'readme.txt',
        'size': 512,
        'mtime': '2025-01-15T08:30:00.000',
        'isFile': true,
        'isDirectory': false,
      };

      final info = FileInfo.fromJson(json, '', 'http://localhost:3000');

      expect(info.path, 'readme.txt');
      expect(info.url, 'http://localhost:3000/getFile/readme.txt');
    });
  });
}
