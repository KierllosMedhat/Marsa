import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int statusCode;

  ApiResponse({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    required this.statusCode,
  });
}

class ApiClient {
  // Configurable via --dart-define=API_BASE_URL=https://... at build time,
  // or auto-detects same-origin /api when running in web browser (e.g. on Vercel).
  String _baseUrl = _resolveDefaultBaseUrl();
  String? _accessToken;
  String? _refreshToken;

  static String _resolveDefaultBaseUrl() {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl.endsWith('/') ? envUrl.substring(0, envUrl.length - 1) : envUrl;
    }
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      return '${base.origin}/api';
    }
    return 'http://localhost:3000/api';
  }

  String get baseUrl => _baseUrl;
  String? get refreshToken => _refreshToken;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  void setTokens({required String accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  Map<String, String> _buildHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (includeAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<ApiResponse<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool includeAuth = true,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        uri,
        headers: _buildHeaders(includeAuth: includeAuth),
      );

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        errorMessage: 'تعذر الاتصال بالخادم: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http.post(
        uri,
        headers: _buildHeaders(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        errorMessage: 'تعذر الاتصال بالخادم: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http.patch(
        uri,
        headers: _buildHeaders(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        errorMessage: 'تعذر الاتصال بالخادم: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http.put(
        uri,
        headers: _buildHeaders(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        errorMessage: 'تعذر الاتصال بالخادم: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool includeAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http.delete(
        uri,
        headers: _buildHeaders(includeAuth: includeAuth),
        body: body != null ? jsonEncode(body) : null,
      );

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        errorMessage: 'تعذر الاتصال بالخادم: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<List<dynamic>>> getList(
    String endpoint, {
    Map<String, String>? queryParams,
    bool includeAuth = true,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        uri,
        headers: _buildHeaders(includeAuth: includeAuth),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return ApiResponse(
          isSuccess: true,
          statusCode: response.statusCode,
          data: decoded is List ? decoded : [decoded],
        );
      } else {
        return ApiResponse(
          isSuccess: false,
          statusCode: response.statusCode,
          errorMessage: 'خطأ: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        errorMessage: 'تعذر الاتصال: $e',
      );
    }
  }

  ApiResponse<Map<String, dynamic>> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ApiResponse(
          isSuccess: true,
          statusCode: response.statusCode,
          data: data,
        );
      } catch (_) {
        return ApiResponse(
          isSuccess: true,
          statusCode: response.statusCode,
          data: {},
        );
      }
    } else {
      String error = 'حدث خطأ غير متوقع (${response.statusCode})';
      try {
        final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
        if (errorJson is Map && errorJson.containsKey('detail')) {
          error = errorJson['detail'].toString();
        }
      } catch (_) {}
      return ApiResponse(
        isSuccess: false,
        statusCode: response.statusCode,
        errorMessage: error,
      );
    }
  }
}
