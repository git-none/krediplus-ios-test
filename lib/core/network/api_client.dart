import 'dart:async';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/session_store.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this.store) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 60),
        headers: const {
          'Accept': 'application/json',
          'Connection': 'keep-alive',
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await store.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['retried'] != true) {
            try {
              await _refreshSession();
              final request = error.requestOptions;
              request.extra['retried'] = true;
              final token = await store.accessToken;
              request.headers['Authorization'] = 'Bearer $token';
              final response = await dio.fetch(request);
              return handler.resolve(response);
            } catch (_) {}
          }
          handler.next(error);
        },
      ),
    );
  }

  final SessionStore store;
  late final Dio dio;
  Completer<void>? _refreshing;

  Future<void> _refreshSession() async {
    if (_refreshing != null) return _refreshing!.future;
    _refreshing = Completer<void>();
    try {
      final refresh = await store.refreshToken;
      if (refresh == null || refresh.isEmpty) {
        throw const ApiException('La sesión expiró.');
      }
      final raw = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final response = await raw.post(
        '/auth/mobile/refresh',
        data: {'refreshToken': refresh},
      );
      final map = _asMap(response.data);
      final access = map['accessToken']?.toString() ?? '';
      final nextRefresh = map['refreshToken']?.toString() ?? refresh;
      if (access.isEmpty) {
        throw const ApiException('No fue posible renovar la sesión.');
      }
      await store.saveTokens(access, nextRefresh);
      final user = map['user'];
      if (user is Map) await store.saveUser(Map<String, dynamic>.from(user));
      _refreshing!.complete();
    } catch (e) {
      _refreshing!.completeError(e);
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Options? options,
  }) async {
    try {
      final r = await dio.get(path, queryParameters: query, options: options);
      return r.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<List<int>> getBytes(String path, {Map<String, dynamic>? query}) async {
    try {
      final r = await dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
      return List<int>.from(r.data ?? const <int>[]);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> post(
    String path, {
    Object? data,
    Options? options,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final r = await dio.post(
        path,
        data: data,
        options: options,
        onSendProgress: onSendProgress,
      );
      return r.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> put(String path, {Object? data}) async {
    try {
      final r = await dio.put(path, data: data);
      return r.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> patch(String path, {Object? data}) async {
    try {
      final r = await dio.patch(path, data: data);
      return r.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<dynamic> delete(String path, {Object? data}) async {
    try {
      final r = await dio.delete(path, data: data);
      return r.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  ApiException _toApiException(DioException e) {
    final data = e.response?.data;
    String message = 'No fue posible completar la solicitud.';
    if (data is Map) {
      for (final key in const ['message', 'mensaje', 'error', 'detail']) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          message = value.toString();
          break;
        }
      }
    } else if (data is String && data.trim().isNotEmpty) {
      message = data.trim();
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      message =
          'No hay conexión con Kredi+. Verifica Internet e inténtalo nuevamente.';
    }
    return ApiException(message, e.response?.statusCode);
  }
}
