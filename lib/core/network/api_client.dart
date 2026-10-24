import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../errors/app_exception.dart';

/// Signature used by data sources to fetch JSON. Allows tests to inject a fake
/// without touching the network.
typedef JsonFetcher = Future<Map<String, dynamic>> Function(
  String path,
  Map<String, dynamic> query,
);

/// Thin Dio wrapper: timeouts, one retry for transient failures, and mapping
/// of transport errors to [AppException]. Provider-specific error bodies are
/// interpreted by the data source (HTTP error bodies are returned, not thrown).
class ApiClient {
  ApiClient({Dio? dio, this.maxRetries = 1})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.twelveDataBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.json,
                // We interpret status codes ourselves from the JSON body.
                validateStatus: (_) => true,
              ),
            );

  final Dio _dio;
  final int maxRetries;

  Future<Map<String, dynamic>> getJson(
    String path,
    Map<String, dynamic> query,
  ) async {
    var attempt = 0;
    while (true) {
      try {
        final response = await _dio.get<dynamic>(path, queryParameters: query);
        final status = response.statusCode ?? 0;
        final data = response.data;

        if (status >= 500) {
          throw const AppException(
            AppErrorType.unknown,
            'The data provider is having problems right now.',
            hint: 'Try again in a moment.',
          );
        }
        if (data is! Map) {
          throw const AppException(
            AppErrorType.parse,
            'The data provider returned an unexpected response.',
          );
        }
        final map = Map<String, dynamic>.from(data);
        if (status >= 400 && map['code'] is! num) {
          map['code'] = status;
          map['status'] = 'error';
        }
        return map;
      } on AppException catch (e) {
        if (e.retryable && attempt < maxRetries) {
          attempt++;
          await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
          continue;
        }
        rethrow;
      } on DioException catch (e) {
        final mapped = _mapDio(e);
        if (mapped.retryable && attempt < maxRetries) {
          attempt++;
          await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
          continue;
        }
        throw mapped;
      } on FormatException {
        throw const AppException(
          AppErrorType.parse,
          'The data provider returned data that could not be read.',
        );
      }
    }
  }

  AppException _mapDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AppException(
          AppErrorType.timeout,
          'The request timed out.',
          hint: 'Check your connection and try again.',
        );

      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      case DioExceptionType.cancel:
        return const AppException(
          AppErrorType.network,
          'Unable to reach the data provider. You may be offline.',
          hint: 'Check your internet connection, or switch to demo mode.',
        );

      case DioExceptionType.badResponse:
        return const AppException(
          AppErrorType.unknown,
          'The data provider returned an error.',
        );
    }
  }


  void close() => _dio.close();
}
