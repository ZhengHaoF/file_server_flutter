import 'dart:convert';

import 'package:flutter/foundation.dart';

class NetworkLogEntry {
  final DateTime timestamp;
  final String method;
  final String url;
  final Map<String, dynamic>? requestHeaders;
  final dynamic requestBody;
  final int? statusCode;
  final String? statusMessage;
  final Map<String, dynamic>? responseHeaders;
  final dynamic responseBody;
  final String? error;
  final int durationMs;
  final bool isRequestError;

  NetworkLogEntry({
    required this.timestamp,
    required this.method,
    required this.url,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.statusMessage,
    this.responseHeaders,
    this.responseBody,
    this.error,
    required this.durationMs,
    this.isRequestError = false,
  });

  String get summary {
    final ts = timestamp.toIso8601String().substring(11, 23);
    final code = statusCode != null ? ' [$statusCode]' : '';
    return '$ts $method $url$code  ${durationMs}ms';
  }

  String get formattedRequestBody {
    if (requestBody == null) return '';
    if (requestBody is String) return requestBody!;
    try {
      return const JsonEncoder.withIndent('  ').convert(requestBody);
    } catch (_) {
      return requestBody.toString();
    }
  }

  String get formattedResponseBody {
    if (responseBody == null) return '';
    if (responseBody is String) return responseBody!;
    try {
      return const JsonEncoder.withIndent('  ').convert(responseBody);
    } catch (_) {
      return responseBody.toString();
    }
  }

  String get formattedRequestHeaders {
    if (requestHeaders == null || requestHeaders!.isEmpty) return '';
    final buf = StringBuffer();
    requestHeaders!.forEach((k, v) {
      buf.writeln('$k: $v');
    });
    return buf.toString();
  }

  String get formattedResponseHeaders {
    if (responseHeaders == null || responseHeaders!.isEmpty) return '';
    final buf = StringBuffer();
    responseHeaders!.forEach((k, v) {
      buf.writeln('$k: $v');
    });
    return buf.toString();
  }
}

class NetworkLogService extends ChangeNotifier {
  static final NetworkLogService _instance = NetworkLogService._internal();
  factory NetworkLogService() => _instance;
  NetworkLogService._internal();

  static const int _maxEntries = 500;

  final List<NetworkLogEntry> _logs = [];
  bool _enabled = true;
  bool _showImageRequests = true;

  bool get enabled => _enabled;
  bool get showImageRequests => _showImageRequests;
  List<NetworkLogEntry> get logs => List.unmodifiable(_logs);

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  set showImageRequests(bool value) {
    if (_showImageRequests == value) return;
    _showImageRequests = value;
    notifyListeners();
  }

  void addLog(NetworkLogEntry entry) {
    if (!_enabled) return;
    if (!_showImageRequests && _isImageRequest(entry.url)) return;

    _logs.insert(0, entry);
    if (_logs.length > _maxEntries) {
      _logs.removeRange(_maxEntries, _logs.length);
    }
    notifyListeners();
  }

  void clear() {
    if (_logs.isEmpty) return;
    _logs.clear();
    notifyListeners();
  }

  bool _isImageRequest(String url) {
    final lower = url.toLowerCase();
    return lower.contains('!') && lower.contains('x') && _looksLikeImage(lower);
  }

  bool _looksLikeImage(String lowerUrl) {
    const exts = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg'];
    for (final ext in exts) {
      if (lowerUrl.contains(ext)) return true;
    }
    return false;
  }
}
