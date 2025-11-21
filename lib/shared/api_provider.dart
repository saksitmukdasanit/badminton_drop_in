// import 'package:camera/camera.dart';

import 'dart:io';
import 'package:badminton/navigator_key.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';

const String appName = 'Badmintion Club';
const String versionName = '0.0.1';
const int versionNumber = 01;

class ApiProvider {
  late final Dio _dio;

  final String server = 'http://line-ddpm.we-builds.com/drop-in-api/api';
  final String serverHub = 'http://line-ddpm.we-builds.com/drop-in-api';
  final String serverDocument =
      'http://line-ddpm.we-builds.com/drop-in-document/api/Files/upload';

  ApiProvider() {
    final options = BaseOptions(
      baseUrl: server,
      connectTimeout: const Duration(seconds: 10), // 10 วินาที
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    );
    _dio = Dio(options);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('accessToken');

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final accessToken = prefs.getString('accessToken');
              final refreshToken = prefs.getString('refreshToken');

              if (refreshToken == null) {
                // ถ้าไม่มี Refresh Token ก็ไม่ต้องทำอะไรต่อ
                return handler.next(e);
              }

              final refreshDio = Dio(BaseOptions(baseUrl: server));
              final refreshResponse = await refreshDio.post(
                '/Auth/refresh',
                data: {
                  'accessToken': accessToken,
                  'refreshToken': refreshToken,
                },
              );

              if (refreshResponse.statusCode == 200) {
                // 4. ถ้าได้ Token ใหม่สำเร็จ, บันทึกทับของเดิม
                final newAccessToken =
                    refreshResponse.data['data']['accessToken'];
                final newRefreshToken =
                    refreshResponse.data['data']['refreshToken'];
                await prefs.setString('accessToken', newAccessToken);
                await prefs.setString('refreshToken', newRefreshToken);

                // 5. อัปเดต Header ของ Request เดิมที่เคยล้มเหลว
                e.requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';

                // 6. สั่งให้ยิง Request เดิมซ้ำอีกครั้ง
                // Dio จะคืน response ของ request ใหม่นี้กลับไปให้ผู้เรียกเดิม
                return handler.resolve(await _dio.fetch(e.requestOptions));
              }
            } on DioException catch (refreshError) {
              // ถ้าการ Refresh Token ล้มเหลว (เช่น Refresh Token หมดอายุ)
              // ให้ส่ง Error เดิมออกไป (ซึ่งจะทำให้ผู้ใช้ต้อง Login ใหม่)
              // --- ADDED: เพิ่มการ print log เพื่อให้เห็นข้อผิดพลาดชัดเจนขึ้น ---
              print('--- TOKEN REFRESH FAILED ---');
              print('Error: ${refreshError.message}');
              print('Response: ${refreshError.response?.data}');

              // --- ADDED: บังคับ Logout เมื่อ Refresh Token ล้มเหลว ---
              // ใช้ global context ที่เราสร้างไว้เพื่อเข้าถึง AuthProvider
              final context = navigatorKey.currentContext;
              if (context != null && context.mounted) {
                await Provider.of<AuthProvider>(
                  context,
                  listen: false,
                ).logout();
              }

              return handler.next(e);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// Generic GET method
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);

      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Generic POST method
  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Generic PUT method
  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Generic DELETE method
  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  void _handleDioException(DioException e) {
    final errorMessage =
        e.response?.data ?? e.message ?? 'An unknown error occurred';
    throw Exception(errorMessage);
  }

  Future<dynamic> uploadFiles({
    required List<File> files,
    required String folderName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'folderName': folderName,
        'files': files.map((file) {
          return MultipartFile.fromFileSync(
            file.path,
            filename: file.path.split('/').last,
          );
        }).toList(),
      });
      final response = await _dio.post(serverDocument, data: formData);
      return response.data;
    } on DioException catch (e) {
      _handleDioException(e);
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // --- NEW: ฟังก์ชันสำหรับดึง Access Token ปัจจุบัน ---
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  // --- NEW: ฟังก์ชันกลางสำหรับสร้าง SignalR Hub Connection ---
  HubConnection createHubConnection(String hubPath) {
    final serverUrl = '$serverHub$hubPath';
    final hubConnection = HubConnectionBuilder()
        .withUrl(
          serverUrl,
          options: HttpConnectionOptions(
            // ใช้ฟังก์ชัน getAccessToken ที่มีอยู่แล้วเพื่อดึง Token
            accessTokenFactory: () async => await getAccessToken() ?? '',
          ),
        )
        .withAutomaticReconnect() // ให้พยายามต่อใหม่อัตโนมัติถ้าหลุด
        .build();

    return hubConnection;
  }
}
