import 'package:dio/dio.dart';
import '../models/file_info.dart';
import 'network_log_service.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  late String _serverBaseUrl;

  ApiService._internal() {
    _serverBaseUrl = StorageService().serverBaseUrl;
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    _dio.interceptors.add(_NetworkLogInterceptor(NetworkLogService()));
  }

  void setServerUrl(String url) {
    _serverBaseUrl = url;
    StorageService().serverBaseUrl = url;
  }

  String get serverBaseUrl => _serverBaseUrl;

  String getFileUrl(String filePath, String fileName) {
    final cleanPath = filePath.isNotEmpty ? '/$filePath' : '';
    return '$_serverBaseUrl/getFile$cleanPath/${Uri.encodeComponent(fileName)}';
  }

  String getVideoPreviewUrl(String filePath) {
    return '$_serverBaseUrl/getVideoPreview/$filePath';
  }

  Future<List<FileInfo>> getFileList(String currentPath) async {
    try {
      final response = await _dio.get(
        '$_serverBaseUrl/list/${Uri.encodeComponent(currentPath)}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final list = data['list'] as List<dynamic>?;

        if (list == null) return [];

        return list.map((item) {
          return FileInfo.fromJson(
            item as Map<String, dynamic>,
            currentPath,
            _serverBaseUrl,
          );
        }).toList();
      }

      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        rethrow;
      }
      throw Exception('获取文件列表失败: ${e.message}');
    }
  }

  Future<bool> deleteFile(String filePath) async {
    try {
      final response = await _dio.post(
        '$_serverBaseUrl/delFile',
        data: {'filePath': filePath},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> restartServer(String pwd) async {
    try {
      final response = await _dio.post(
        '$_serverBaseUrl/restartServer',
        data: {'pwd': pwd},
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      return {'msg': '重启失败: $e'};
    }
  }
}

class _NetworkLogInterceptor extends Interceptor {
  final NetworkLogService _logService;

  _NetworkLogInterceptor(this._logService);

  static const _startKey = '_networkLogStart';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _record(response.requestOptions, statusCode: response.statusCode, statusMessage: response.statusMessage, responseHeaders: response.headers.map, responseBody: response.data);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(
      err.requestOptions,
      statusCode: err.response?.statusCode,
      statusMessage: err.response?.statusMessage ?? err.message,
      responseHeaders: err.response?.headers.map,
      responseBody: err.response?.data,
      error: err.message,
    );
    handler.next(err);
  }

  void _record(
    RequestOptions options, {
    int? statusCode,
    String? statusMessage,
    Map<String, List<dynamic>>? responseHeaders,
    dynamic responseBody,
    String? error,
  }) {
    final start = options.extra[_startKey] as DateTime?;
    final duration = start == null
        ? 0
        : DateTime.now().difference(start).inMilliseconds;

    _logService.addLog(NetworkLogEntry(
      timestamp: start ?? DateTime.now(),
      method: options.method,
      url: options.uri.toString(),
      requestHeaders: options.headers,
      requestBody: options.data,
      statusCode: statusCode,
      statusMessage: statusMessage,
      responseHeaders: responseHeaders?.map((k, v) => MapEntry(k, v.join(','))),
      responseBody: responseBody,
      error: error,
      durationMs: duration,
      isRequestError: error != null,
    ));
  }
}
