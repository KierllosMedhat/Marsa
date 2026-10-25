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
  String _baseUrl = resolveDefaultBaseUrl();
  String? _accessToken;
  String? _refreshToken;
  bool _isRefreshing = false;

  static const String productionBaseUrl =
      'https://marsa-clinic-xi.vercel.app/api';

  static String normalizeBaseUrl(String rawUrl) {
    var url = rawUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) {
      return productionBaseUrl;
    }
    // Automatically append /api if pointing to Next.js/Vercel server without /api suffix
    if (!url.endsWith('/api') && !url.endsWith(':8000')) {
      url = '$url/api';
    }
    return url;
  }

  static String resolveDefaultBaseUrl() {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return normalizeBaseUrl(envUrl);
    }
    final base = Uri.base;
    if (base.scheme == 'http' || base.scheme == 'https') {
      // When running Flutter Web locally via `flutter run`, route to local Next.js server
      if (base.host == 'localhost' || base.host == '127.0.0.1') {
        return 'http://${base.host}:3000/api';
      }
      return '${base.origin}/api';
    }
    // Native Android / Windows / Tablet app connects directly to the live Vercel backend
    return productionBaseUrl;
  }

  String get baseUrl => _baseUrl;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  void setBaseUrl(String url) {
    _baseUrl = normalizeBaseUrl(url);
  }

  void resetBaseUrl() {
    _baseUrl = resolveDefaultBaseUrl();
  }

  void setTokens({required String accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
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
    if (includeAuth && _accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing ||
        _refreshToken == null ||
        _refreshToken!.isEmpty ||
        _refreshToken!.startsWith('offline_')) {
      return false;
    }
    _isRefreshing = true;
    try {
      final uri = Uri.parse('$_baseUrl/auth/refresh');
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(includeAuth: false),
            body: jsonEncode({'refresh_token': _refreshToken}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final newAccess = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          _accessToken = newAccess;
          if (newRefresh != null && newRefresh.isNotEmpty) {
            _refreshToken = newRefresh;
          }
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(String base) requestFn,
  ) async {
    try {
      return await requestFn(_baseUrl).timeout(const Duration(seconds: 10));
    } catch (firstErr) {
      // If running inside an Android emulator where host machine is 10.0.2.2 instead of localhost
      if (_baseUrl.contains('localhost:3000')) {
        final emulatorBase = _baseUrl.replaceFirst('localhost:3000', '10.0.2.2:3000');
        try {
          final res =
              await requestFn(emulatorBase).timeout(const Duration(seconds: 6));
          _baseUrl = emulatorBase;
          return res;
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool includeAuth = true,
  }) async {
    try {
      http.Response response = await _sendWithFallback((base) {
        var uri = Uri.parse('$base$endpoint');
        if (queryParams != null && queryParams.isNotEmpty) {
          uri = uri.replace(queryParameters: queryParams);
        }
        return http.get(uri, headers: _buildHeaders(includeAuth: includeAuth));
      });

      if (response.statusCode == 401 &&
          includeAuth &&
          endpoint != '/auth/refresh' &&
          await _tryRefreshToken()) {
        response = await _sendWithFallback((base) {
          var uri = Uri.parse('$base$endpoint');
          if (queryParams != null && queryParams.isNotEmpty) {
            uri = uri.replace(queryParameters: queryParams);
          }
          return http.get(uri, headers: _buildHeaders(includeAuth: includeAuth));
        });
      }

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
      http.Response response = await _sendWithFallback((base) {
        final uri = Uri.parse('$base$endpoint');
        return http.post(
          uri,
          headers: _buildHeaders(includeAuth: includeAuth),
          body: body != null ? jsonEncode(body) : null,
        );
      });

      if (response.statusCode == 401 &&
          includeAuth &&
          endpoint != '/auth/login' &&
          endpoint != '/auth/refresh' &&
          await _tryRefreshToken()) {
        response = await _sendWithFallback((base) {
          final uri = Uri.parse('$base$endpoint');
          return http.post(
            uri,
            headers: _buildHeaders(includeAuth: includeAuth),
            body: body != null ? jsonEncode(body) : null,
          );
        });
      }

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
      http.Response response = await _sendWithFallback((base) {
        final uri = Uri.parse('$base$endpoint');
        return http.patch(
          uri,
          headers: _buildHeaders(includeAuth: includeAuth),
          body: body != null ? jsonEncode(body) : null,
        );
      });

      if (response.statusCode == 401 &&
          includeAuth &&
          await _tryRefreshToken()) {
        response = await _sendWithFallback((base) {
          final uri = Uri.parse('$base$endpoint');
          return http.patch(
            uri,
            headers: _buildHeaders(includeAuth: includeAuth),
            body: body != null ? jsonEncode(body) : null,
          );
        });
      }

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
      http.Response response = await _sendWithFallback((base) {
        final uri = Uri.parse('$base$endpoint');
        return http.put(
          uri,
          headers: _buildHeaders(includeAuth: includeAuth),
          body: body != null ? jsonEncode(body) : null,
        );
      });

      if (response.statusCode == 401 &&
          includeAuth &&
          await _tryRefreshToken()) {
        response = await _sendWithFallback((base) {
          final uri = Uri.parse('$base$endpoint');
          return http.put(
            uri,
            headers: _buildHeaders(includeAuth: includeAuth),
            body: body != null ? jsonEncode(body) : null,
          );
        });
      }

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
      http.Response response = await _sendWithFallback((base) {
        final uri = Uri.parse('$base$endpoint');
        return http.delete(
          uri,
          headers: _buildHeaders(includeAuth: includeAuth),
          body: body != null ? jsonEncode(body) : null,
        );
      });

      if (response.statusCode == 401 &&
          includeAuth &&
          await _tryRefreshToken()) {
        response = await _sendWithFallback((base) {
          final uri = Uri.parse('$base$endpoint');
          return http.delete(
            uri,
            headers: _buildHeaders(includeAuth: includeAuth),
            body: body != null ? jsonEncode(body) : null,
          );
        });
      }

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
      http.Response response = await _sendWithFallback((base) {
        var uri = Uri.parse('$base$endpoint');
        if (queryParams != null && queryParams.isNotEmpty) {
          uri = uri.replace(queryParameters: queryParams);
        }
        return http.get(uri, headers: _buildHeaders(includeAuth: includeAuth));
      });

      if (response.statusCode == 401 &&
          includeAuth &&
          await _tryRefreshToken()) {
        response = await _sendWithFallback((base) {
          var uri = Uri.parse('$base$endpoint');
          if (queryParams != null && queryParams.isNotEmpty) {
            uri = uri.replace(queryParameters: queryParams);
          }
          return http.get(uri, headers: _buildHeaders(includeAuth: includeAuth));
        });
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return ApiResponse(
          isSuccess: true,
          statusCode: response.statusCode,
          data: decoded is List ? decoded : [decoded],
        );
      } else {
        String error = 'خطأ (${response.statusCode})';
        try {
          final errJson = jsonDecode(utf8.decode(response.bodyBytes));
          if (errJson is Map && errJson['detail'] != null) {
            error = errJson['detail'].toString();
          }
        } catch (_) {}
        return ApiResponse(
          isSuccess: false,
          statusCode: response.statusCode,
          errorMessage: error,
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
        if (response.bodyBytes.isEmpty) {
          return ApiResponse(
            isSuccess: true,
            statusCode: response.statusCode,
            data: {},
          );
        }
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
      String error = 'حدث خطأ في الاتصال بالخادم (${response.statusCode})';
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
