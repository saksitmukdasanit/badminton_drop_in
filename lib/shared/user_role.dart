import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Role { player, organizer }

class UserRoleProvider with ChangeNotifier {
  Role _currentRole = Role.player; // ค่าเริ่มต้นคือ Player

  Role get currentRole => _currentRole;

  static const String _rolePreferenceKey = 'user_role';

  UserRoleProvider() {
    // เมื่อ Provider ถูกสร้างขึ้น ให้ทำการโหลด Role ที่เคยบันทึกไว้ทันที
    _loadRole();
  }

  // Getter สำหรับดึง Theme ตาม Role ปัจจุบัน
  ThemeData get currentTheme =>
      _currentRole == Role.player ? playerTheme : organizerTheme;

  // ฟังก์ชันสำหรับสลับ Role
  Future<void> toggleRole() async {
    _currentRole = _currentRole == Role.player ? Role.organizer : Role.player;
    notifyListeners();

    // เพิ่มบรรทัดนี้เพื่อบันทึกค่าใหม่ลง SharedPreferences ด้วย
    await _saveRole(_currentRole);
  }

  Future<void> setRole(Role newRole) async {
    if (_currentRole != newRole) {
      _currentRole = newRole;
      notifyListeners();
      await _saveRole(newRole);
    }
  }

  Future<void> _saveRole(Role role) async {
    final prefs = await SharedPreferences.getInstance();
    // แปลง enum เป็น String โดยใช้ .name แล้วบันทึก
    await prefs.setString(_rolePreferenceKey, role.name);
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRoleString = prefs.getString(_rolePreferenceKey);

    if (savedRoleString != null) {
      try {
        _currentRole = Role.values.byName(savedRoleString);
      } catch (e) {
        _currentRole = Role.player;
      }
    }

    // เพิ่มบรรทัดนี้ เพื่อให้แน่ใจว่า UI จะอัปเดตตามค่าที่โหลดมา
    notifyListeners();
  }
}

final ThemeData playerTheme = ThemeData(
  primaryColor: const Color(0XFF0E9D7A),
  scaffoldBackgroundColor: const Color(0xFFE8F8F5),
  colorScheme: const ColorScheme.light(
    primary: Color(0XFF0E9D7A), // สีหลัก
    secondary: Color(0xFF1ABC9C), // สีรอง
    onPrimary: Colors.white, // สีตัวอักษรบนสีหลัก
    surface: Colors.white, // สีพื้นหลังของ Card
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0XFF0E9D7A),
    foregroundColor: Colors.white,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0XFF0E9D7A),
    selectedItemColor: Colors.white,
    unselectedItemColor: Colors.white70,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0XFF0E9D7A),
      foregroundColor: Colors.white,
    ),
  ),
  fontFamily: 'Poppins',
);

// --- Theme สำหรับ Organizer (สีน้ำเงิน) ---
final ThemeData organizerTheme = ThemeData(
  primaryColor: const Color(0XFF243F94),
  scaffoldBackgroundColor: const Color(0xFFECF0F1),
  colorScheme: const ColorScheme.light(
    primary: Color(0XFF243F94), // สีหลัก
    secondary: Color(0xFF2980B9), // สีรอง
    onPrimary: Colors.white,
    surface: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0XFF243F94),
    foregroundColor: Colors.white,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0XFF243F94),
    selectedItemColor: Colors.white,
    unselectedItemColor: Colors.white70,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0XFF243F94),
      foregroundColor: Colors.white,
    ),
  ),
  fontFamily: 'Poppins',
);

class AuthProvider extends ChangeNotifier {
  String? _accessToken;
  String? _redirectAfterLogin;

  bool get isLoggedIn => _accessToken != null;
  String? get accessToken => _accessToken;
  String? get redirectAfterLogin => _redirectAfterLogin;

  set redirectAfterLogin(String? value) {
    _redirectAfterLogin = value;
    // notifyListeners();
  }

  // --- NEW: ฟังก์ชันสำหรับเช็ค Login อัตโนมัติ ---
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('accessToken')) {
      return;
    }
    _accessToken = prefs.getString('accessToken');
    notifyListeners();
  }

  Future<void> login(dynamic token) async {
    _accessToken = token['accessToken'];
    notifyListeners();
    // --- NEW: บันทึก token ลงเครื่อง ---
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token['accessToken']);
    await prefs.setString('refreshToken', token['refreshToken']);
  }

  Future<void> logout() async {
    _accessToken = null;
    _redirectAfterLogin = null;
    notifyListeners();
    // --- NEW: ลบ token ออกจากเครื่อง ---
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }
}
