import 'dart:io' show Platform;

import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// ผลลัพธ์ของการ login ผ่าน social provider
class SocialLoginResult {
  final String accessToken;
  final String refreshToken;
  final bool requiresPhoneVerification;
  final String? phoneNumber;

  const SocialLoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.requiresPhoneVerification,
    this.phoneNumber,
  });

  factory SocialLoginResult.fromJson(Map<String, dynamic> json) {
    return SocialLoginResult(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      requiresPhoneVerification:
          (json['requiresPhoneVerification'] ?? false) as bool,
      phoneNumber: json['phoneNumber'] as String?,
    );
  }

  Map<String, dynamic> toAuthProviderToken() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };
}

class SocialLoginException implements Exception {
  final String message;
  final bool userCancelled;
  const SocialLoginException(this.message, {this.userCancelled = false});

  @override
  String toString() => message;
}

/// ห่อ Google + Apple SDK และโทร backend `/api/Auth/login-google` / `/api/Auth/login-apple`
///
/// **การตั้งค่า** (ใส่ครั้งเดียวจาก main.dart หรือ AuthProvider ก่อนเรียกใช้):
/// - `iosClientId` — iOS OAuth 2.0 Client ID จาก Google Cloud Console (เฉพาะ iOS)
/// - `serverClientId` — Web OAuth 2.0 Client ID (สำหรับ backend verify ID token)
class SocialLoginService {
  SocialLoginService._();
  static final SocialLoginService instance = SocialLoginService._();

  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized({
    String? iosClientId,
    String? serverClientId,
  }) async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: iosClientId,
      serverClientId: serverClientId,
    );
    _googleInitialized = true;
  }

  /// Login ด้วย Google
  ///
  /// ต้องเรียกจาก main thread (UI) ครั้งแรก เพราะ `authenticate()` จะเปิด UI เลือกบัญชี
  Future<SocialLoginResult> signInWithGoogle({
    String? iosClientId,
    String? serverClientId,
  }) async {
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const SocialLoginException(
        'อุปกรณ์นี้ไม่รองรับการเข้าสู่ระบบด้วย Google',
      );
    }

    await _ensureGoogleInitialized(
      iosClientId: iosClientId,
      serverClientId: serverClientId,
    );

    GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialLoginException(
          'ยกเลิกการเข้าสู่ระบบ',
          userCancelled: true,
        );
      }
      throw SocialLoginException('Google sign-in ล้มเหลว: ${e.description ?? e.code}');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const SocialLoginException(
        'ไม่ได้รับ ID token จาก Google — ตรวจสอบ serverClientId / Web Client ID ใน config',
      );
    }

    final response = await ApiProvider().post(
      '/Auth/login-google',
      data: {'idToken': idToken},
    );
    if (response['status'] != 200 || response['data'] == null) {
      throw SocialLoginException(
        response['message'] ?? 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ',
      );
    }
    return SocialLoginResult.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Login ด้วย Apple
  ///
  /// **iOS:** ใช้ native flow (เร็ว, ไม่ออก browser); ต้องเปิด capability "Sign in with Apple"
  /// **Android:** sign_in_with_apple จะใช้ web flow (เปิด browser) — ต้องตั้ง webAuthenticationOptions
  Future<SocialLoginResult> signInWithApple({String? webAuthClientId, String? webAuthRedirectUri}) async {
    if (!await SignInWithApple.isAvailable()) {
      throw const SocialLoginException(
        'อุปกรณ์นี้ไม่รองรับ Sign in with Apple (ต้องการ iOS 13+ หรือ Android web flow)',
      );
    }

    AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions:
            (!kIsWeb && Platform.isAndroid && webAuthClientId != null && webAuthRedirectUri != null)
                ? WebAuthenticationOptions(
                  clientId: webAuthClientId,
                  redirectUri: Uri.parse(webAuthRedirectUri),
                )
                : null,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialLoginException(
          'ยกเลิกการเข้าสู่ระบบ',
          userCancelled: true,
        );
      }
      throw SocialLoginException('Apple sign-in ล้มเหลว: ${e.message}');
    }

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const SocialLoginException(
        'ไม่ได้รับ identityToken จาก Apple',
      );
    }

    String? fullName;
    if (credential.givenName != null || credential.familyName != null) {
      fullName = [credential.givenName, credential.familyName]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' ');
      if (fullName.isEmpty) fullName = null;
    }

    final response = await ApiProvider().post(
      '/Auth/login-apple',
      data: {
        'identityToken': identityToken,
        'authorizationCode': credential.authorizationCode,
        'fullName': fullName,
        'email': credential.email,
      },
    );
    if (response['status'] != 200 || response['data'] == null) {
      throw SocialLoginException(
        response['message'] ?? 'เข้าสู่ระบบด้วย Apple ไม่สำเร็จ',
      );
    }
    return SocialLoginResult.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Sign out จาก Google (ไม่กระทบกับ session ของแอปเรา — เรา clear AuthProvider แยก)
  Future<void> googleSignOut() async {
    if (!_googleInitialized) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // ignore — sign out failure ไม่ใช่เรื่องคอขาดบาดตาย
    }
  }
}
