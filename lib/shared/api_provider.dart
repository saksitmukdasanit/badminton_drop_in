// import 'package:camera/camera.dart';

import 'package:badminton/shared/firebase_messaging_service.dart';
import 'dart:io';
import 'dart:async'; // NEW: Import สำหรับ Completer
import 'package:badminton/navigator_key.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart'; // --- NEW: Import GoRouter ---
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';

const String appName = 'Badmintion Club';
const String versionName = '0.0.1';
const int versionNumber = 01;

class ApiProvider {
  // --- FIX: ทำ Singleton เพื่อให้แชร์สถานะ _isRefreshing ร่วมกันทั้งแอป ---
  static final ApiProvider _instance = ApiProvider._internal();
  factory ApiProvider() => _instance;

  late final Dio _dio;

  final String server = 'http://line-ddpm.we-builds.com/drop-in-api/api';
  final String serverHub = 'http://line-ddpm.we-builds.com/drop-in-api';
  final String serverDocument =
      'http://line-ddpm.we-builds.com/drop-in-document/api/Files/upload';

  // --- Social Login Config ---
  // Google OAuth 2.0 Client IDs (ดูคำแนะนำใน docs/SOCIAL_LOGIN_SETUP.md)
  // - serverClientId = Web Client ID (ใช้ verify ID token ฝั่ง backend)
  // - iosClientId = iOS Client ID (เฉพาะ iOS, Android อ่านจาก google-services.json)
  // ปล่อยเป็น null ถ้ายังไม่ได้ตั้งค่า — SocialLoginService จะ throw exception แจ้งให้ทราบ
  final String? googleServerClientId = '857647867745-kdakum1g1nl83ghgv1vniqm9cntgn56e.apps.googleusercontent.com';
  final String? googleIosClientId = '857647867745-q5m3t1ql9gr3a9lfq70re74m3vi6s176.apps.googleusercontent.com';

  // --- NEW: ตัวแปรสำหรับระบบ Lock การ Refresh Token ---
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  // เปลี่ยน Constructor เป็น _internal (Private)
  ApiProvider._internal() {
    final options = BaseOptions(
      baseUrl: server,
      connectTimeout: const Duration(seconds: 30), // เพิ่มเป็น 30 วินาที
      receiveTimeout: const Duration(seconds: 30), // เพิ่มเป็น 30 วินาที
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
            // --- NEW: ตรวจสอบว่ากำลัง Refresh อยู่หรือไม่ (Locking Mechanism) ---
            if (_isRefreshing) {
              // ถ้ามีคนอื่นทำอยู่ ให้รอจนเสร็จ
              final newToken = await _refreshCompleter?.future;
              if (newToken != null) {
                // ถ้าได้ Token ใหม่แล้ว ให้ Retry Request นี้ด้วย Token ใหม่
                e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                return handler.resolve(await _dio.fetch(e.requestOptions));
              } else {
                // ถ้า Refresh ล้มเหลว ให้ Error ตามปกติ
                return handler.next(e);
              }
            }

            // --- เริ่มกระบวนการ Refresh (Lock) ---
            _isRefreshing = true;
            _refreshCompleter = Completer<String?>();

            try {
              final prefs = await SharedPreferences.getInstance();
              final accessToken = prefs.getString('accessToken');
              final refreshToken = prefs.getString('refreshToken');

              if (refreshToken == null) {
                // ถ้าไม่มี Refresh Token ก็ไม่ต้องทำอะไรต่อ
                _isRefreshing = false;
                _refreshCompleter?.complete(null);
              // --- FIX: เช็คก่อนว่าเคย Login ไหม ถ้าเป็น Guest ไม่ต้องบังคับเด้งไปหน้า Login ---
              final context = navigatorKey.currentContext;
              if (context != null && context.mounted) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                if (authProvider.isLoggedIn) {
                  _handleLogout(); 
                }
              }
                return handler.next(e);
              }

              final refreshDio = Dio(BaseOptions(
                baseUrl: server,
                validateStatus: (status) => true, // FIX: ไม่ต้อง throw error ถ้าเจอ 401/400 ตอน refresh
                headers: {'Content-Type': 'application/json'},
              ));
              final refreshResponse = await refreshDio.post(
                '/Auth/refresh',
                data: {
                  'accessToken': accessToken,
                  'refreshToken': refreshToken,
                },
              );

              // --- DEBUG LOG: ดูผลลัพธ์การ Refresh ---
              print('Refresh Token Status: ${refreshResponse.statusCode}');

              if (refreshResponse.statusCode == 200) {
                // 4. ถ้าได้ Token ใหม่สำเร็จ, บันทึกทับของเดิม
                final newAccessToken =
                    refreshResponse.data['data']['accessToken'];
                final newRefreshToken =
                    refreshResponse.data['data']['refreshToken'];
                await prefs.setString('accessToken', newAccessToken);
                await prefs.setString('refreshToken', newRefreshToken);

                // --- ปลด Lock และแจ้งคนอื่นว่าเสร็จแล้ว ---
                _isRefreshing = false;
                _refreshCompleter?.complete(newAccessToken);

                // --- NEW: อัปเดต FCM Token ทุกครั้งที่ Refresh Token สำเร็จ ---
                // เพื่อให้แน่ใจว่า User ที่ Auto-Login จะมี Token ในระบบเสมอ
                FirebaseMessagingService().updateTokenToServer();

                // 5. อัปเดต Header ของ Request เดิมที่เคยล้มเหลว
                e.requestOptions.headers['Authorization'] =
                    'Bearer $newAccessToken';

                // 6. สั่งให้ยิง Request เดิมซ้ำอีกครั้ง
                // Dio จะคืน response ของ request ใหม่นี้กลับไปให้ผู้เรียกเดิม
                return handler.resolve(await _dio.fetch(e.requestOptions));
              } else {
                // --- FIX: Refresh ไม่สำเร็จ (Token หมดอายุจริง หรือ Invalid) ---
                // ปลด Lock และแจ้งว่าล้มเหลว
                _isRefreshing = false;
                _refreshCompleter?.complete(null);
                _handleLogout(); // ใช้ฟังก์ชันกลาง
                return handler.next(e); // ส่ง Error 401 เดิมกลับไปให้ UI จัดการต่อ (ถ้าจำเป็น)
              }
            } on DioException catch (refreshError) {
              // --- ปลด Lock และแจ้งว่าล้มเหลว ---
              _isRefreshing = false;
              _refreshCompleter?.complete(null);

              print('--- TOKEN REFRESH FAILED ---');
              print('Error: ${refreshError.message}');
              _handleLogout(); // ใช้ฟังก์ชันกลาง
              return handler.next(e);
            } catch (err) {
               _isRefreshing = false;
               _refreshCompleter?.complete(null);
               _handleLogout(); // ใช้ฟังก์ชันกลาง
               return handler.next(e);
            }
          }

          return handler.next(e);
        },
      ),
    );
  }

  // --- NEW: ฟังก์ชันกลางสำหรับจัดการ Logout ---
  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');

    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      print('Force Logout: Token expired or invalid');
      // ใช้ Future.delayed เพื่อหลีกเลี่ยง Exception: '!_debugLocked': is not true (ปัญหา Router ทำงานซ้อนกัน)
      Future.delayed(Duration.zero, () async {
        await Provider.of<AuthProvider>(context, listen: false).logout();
        if (context.mounted) context.go('/login');
      });
    } else {
      print('CRITICAL: Navigator Context is NULL. Cannot redirect to login.');
    }
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

  /// Generic PATCH method
  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      final response = await _dio.patch(path, data: data);
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
    var errorMessage = e.response?.data;
    if (errorMessage is Map && errorMessage['message'] != null) {
      errorMessage = errorMessage['message'];
    }
    errorMessage = errorMessage ?? e.message ?? 'An unknown error occurred';
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
