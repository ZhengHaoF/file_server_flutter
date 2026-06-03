class FileTypeUtils {
  static const List<String> _videoTypes = ['.MP4', '.AVI', '.MOV', '.FLV', '.MKV', '.TS'];
  static const List<String> _imgTypes = ['.JPG', '.JPEG', '.PNG', '.WEBP', '.GIF'];
  static const List<String> _psTypes = ['.PSD'];
  static const List<String> _zipTypes = ['.RAR', '.ZIP', '.7Z'];
  static const List<String> _audioTypes = ['.WAV', '.MP3', '.OGG'];
  static const List<String> _docTypes = ['.DOC', '.DOCX'];
  static const List<String> _excelTypes = ['.XLS', '.XLSX'];

  static bool isVideo(String? fileSuffix) {
    if (fileSuffix == null || fileSuffix.isEmpty) return false;
    return _videoTypes.contains(fileSuffix.toUpperCase());
  }

  static bool isImg(String? fileSuffix) {
    if (fileSuffix == null || fileSuffix.isEmpty) return false;
    return _imgTypes.contains(fileSuffix.toUpperCase());
  }

  static bool isPs(String? fileSuffix) {
    if (fileSuffix == null || fileSuffix.isEmpty) return false;
    return _psTypes.contains(fileSuffix.toUpperCase());
  }

  static bool isZip(String? fileSuffix) {
    if (fileSuffix == null || fileSuffix.isEmpty) return false;
    return _zipTypes.contains(fileSuffix.toUpperCase());
  }

  static bool isAudio(String? fileSuffix) {
    if (fileSuffix == null || fileSuffix.isEmpty) return false;
    return _audioTypes.contains(fileSuffix.toUpperCase());
  }

  static bool isDoc(String? fileSuffix) {
    if (fileSuffix == null || fileSuffix.isEmpty) return false;
    return _docTypes.contains(fileSuffix.toUpperCase());
  }

  static bool isExcel(String? fileSuffix) {
    if (fileSuffix == null || fileSuffix.isEmpty) return false;
    return _excelTypes.contains(fileSuffix.toUpperCase());
  }

  static const List<String> _textTypes = ['.TXT', '.LOG', '.MD', '.JSON', '.XML', '.CSV', '.YAML', '.YML', '.SQL', '.JS', '.TS', '.DART', '.PY', '.JAVA', '.C', '.CPP', '.H', '.CSS', '.HTML', '.SH', '.BAT', '.INI', '.CONF', '.CFG', '.ENV', '.GITIGNORE'];

  static bool isText(String? fileSuffix) {
    if (fileSuffix == null || fileSuffix.isEmpty) return false;
    return _textTypes.contains(fileSuffix.toUpperCase());
  }

  static String determineFileType(String? suffix) {
    if (isVideo(suffix)) return 'VIDEO';
    if (isImg(suffix)) return 'IMG';
    if (isPs(suffix)) return 'PS';
    if (isZip(suffix)) return 'ZIP';
    if (isAudio(suffix)) return 'AUDIO';
    if (isDoc(suffix)) return 'DOC';
    if (isExcel(suffix)) return 'EXCEL';

    if (suffix != null && suffix.isNotEmpty) {
      final upperSuffix = suffix.toUpperCase();
      if (upperSuffix == '.PDF') return 'PDF';
      if (upperSuffix == '.SQL') return 'DATA';
    }

    return 'UNKNOWN';
  }
}
