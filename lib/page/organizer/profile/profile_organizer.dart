import 'dart:io';

import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker.dart';
import 'package:badminton/component/image_picker_form.dart';
import 'package:badminton/component/loading_image_network.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/page/organizer/history/history_organizer.dart';
import 'package:badminton/page/organizer/history/history_organizer_payment.dart';
import 'package:badminton/page/organizer/profile/edit_skill_levels.dart';
import 'package:badminton/page/organizer/profile/finance.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ProfileMenuItem {
  final String code;
  final String title;
  final String? mobileRoute; // Route ที่จะใช้บนมือถือ
  final VoidCallback? onTap; // Action พิเศษอื่นๆ (ถ้ามี)
  final String iconPath;
  final WidgetBuilder contentWidget; // Widget ที่จะแสดงบน Tablet

  ProfileMenuItem({
    this.code = '',
    required this.title,
    this.mobileRoute,
    this.onTap,
    this.iconPath = '',
    required this.contentWidget,
  });
}

class ProFileOrganizerPage extends StatefulWidget {
  const ProFileOrganizerPage({super.key});

  @override
  ProFileOrganizerPageState createState() => ProFileOrganizerPageState();
}

class ProFileOrganizerPageState extends State<ProFileOrganizerPage> {
  late Future<dynamic> futureModel;
  bool _isLoading = true;
  bool _isSaving = false;
  int _selectedIndex = 0;
  bool _isPanelVisible = false;
  late final List<ProfileMenuItem> _topMenuItems;
  late final List<ProfileMenuItem> _bottomMenuItems;
  String profileImageUrl = '';

  // ---- Edit profile
  final _firstNameController = TextEditingController(text: '');
  final _lastNameController = TextEditingController(text: '');
  final _emailController = TextEditingController(text: '');
  final _phoneController = TextEditingController(text: '');
  final _publicPhoneController = TextEditingController(text: '');
  final _lineIdController = TextEditingController(text: '');
  final _facebookController = TextEditingController(text: '');
  late TextEditingController emergencyNameController;
  late TextEditingController emergencyPhoneController;
  String? _selectedGender = '1';

  // ---- Edit Transfer
  late TextEditingController idcardController;
  late TextEditingController bookBankNoController;
  String? bookbankUrl;
  String? _selectedBank;
  int? _phoneVisibility;
  int? _facebookVisibility;
  int? _lineVisibility;
  final List<dynamic> _banks = [
    {"code": "1", "value": 'ธนาคารกสิกรไทย'},
    {"code": "2", "value": 'ธนาคารไทยพาณิชย์'},
    {"code": "3", "value": 'ธนาคารกรุงเทพ'},
    {"code": "4", "value": 'ธนาคารกรุงไทย'},
  ];

  // ---- Edit SkillLevel
  String _numberOfLevels = '4';
  List<SkillLevel> _skillLevels = [];

  // ----- Change Password
  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // ----- Finance
  static const Color playersColor = Colors.blue;
  static const Color paidColor = Colors.green;
  bool isHistory = false;
  bool isHistoryFinance = false;

  @override
  void initState() {
    emergencyNameController = TextEditingController();
    emergencyPhoneController = TextEditingController();

    idcardController = TextEditingController();
    bookBankNoController = TextEditingController();

    _oldPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _generateSkillLevels(int.parse(_numberOfLevels));
    _fetchData();
    super.initState();
    _topMenuItems = [
      ProfileMenuItem(
        title: 'แก้ไขข้อมูลติดต่อผู้จัด',
        mobileRoute: '/edit-profile-organizer',
        contentWidget: (context) => _buildContactInfoForm(context),
      ),
      ProfileMenuItem(
        title: 'แก้ไขข้อมูลโอนเงิน',
        mobileRoute: '/edit-transfer', // สมมติ path
        contentWidget: (context) => _buildTransferInfoForm(context),
      ),
      ProfileMenuItem(
        title: 'แก้ไขเกณฑ์ระดับมือ',
        mobileRoute: '/edit-skill-level',
        contentWidget: (context) => _buildSkillLevelInfoForm(context),
      ),
      ProfileMenuItem(
        title: 'แก้ไขรหัสผ่าน',
        mobileRoute: '/change-password-organizer', // แก้เป็น path ที่ถูกต้อง
        contentWidget: (context) => _buildChangePasswordContent(context),
      ),
      ProfileMenuItem(
        title: 'การเงิน',
        mobileRoute: '/finance',
        contentWidget: (context) => _buildFinanceForm(context),
      ),
    ];

    // --- กำหนดข้อมูลเมนูส่วนล่าง ---
    _bottomMenuItems = [
      ProfileMenuItem(
        title: 'ไปหน้าผู้เล่น',
        onTap: () {
          context.read<UserRoleProvider>().setRole(Role.player);
          context.push('/profile-user');
        },
        contentWidget: (context) => Container(), // ไม่มีหน้า content
      ),
      ProfileMenuItem(
        title: 'ยกเลิกการเป็นผู้จัด',
        iconPath: 'assets/icon/delete.png',
        onTap: () {
          /* ... */
        },
        contentWidget: (context) => Container(),
      ),
      ProfileMenuItem(
        title: 'Log out',
        iconPath: 'assets/icon/exit.png',
        onTap: _handleLogout,
        contentWidget: (context) => Container(),
      ),
    ];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _publicPhoneController.dispose();
    _lineIdController.dispose();
    _facebookController.dispose();
    emergencyNameController.dispose();
    emergencyPhoneController.dispose();

    idcardController.dispose();
    bookBankNoController.dispose();

    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    showDialogMsg(
      context,
      title: 'ยืนยันการออกจากระบบ',
      subtitle: '',
      btnLeft: 'ออกจากระบบ',
      btnLeftBackColor: Colors.black,
      onConfirm: () {
        // Pop the confirmation dialog
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        showDialogMsg(
          context,
          title: 'ออกจากระบบเรียบร้อย',
          subtitle: '',
          btnLeft: 'ไปหน้า Log In',
          onConfirm: () {
            context.read<UserRoleProvider>().setRole(Role.player);
            authProvider.logout();
          },
        );
      },
    );
  }

  Future<void> _fetchData() async {
    try {
      // 1. เรียก API เพื่อดึงข้อมูลโปรไฟล์ของผู้จัด
      // final response = await ApiProvider().get('/Organizer/profile');
      // final userData = response['data']; // สมมติว่าข้อมูลจริงอยู่ใน key 'data'
      final responses = await Future.wait([
        ApiProvider().get('/Organizer/profile'),
        ApiProvider().get('/organizer/skill-levels'),
      ]);
      final userData = responses[0]['data'];
      final skillLevelsData = responses[1]['data'];

      // 2. ใช้ setState เพื่อนำข้อมูลไปใส่ใน Controllers และ State ต่างๆ
      setState(() {
        // --- ส่วน Profile หลัก ---
        profileImageUrl = userData['profilePhotoUrl'] ?? '';

        // --- ส่วนแก้ไขข้อมูลติดต่อ (Tap 1) ---
        _firstNameController.text = userData['firstName'] ?? '';
        _lastNameController.text = userData['lastName'] ?? '';
        _emailController.text = userData['email'] ?? '';
        _phoneController.text = userData['phoneNumber'] ?? '';
        _publicPhoneController.text = userData['publicPhoneNumber'] ?? '';
        _lineIdController.text = userData['lineId'] ?? '';
        _facebookController.text = userData['facebookLink'] ?? '';
        _selectedGender = (userData['gender'] ?? "1").toString();
        emergencyNameController.text = userData['emergencyContactName'] ?? '';
        emergencyPhoneController.text = userData['emergencyContactPhone'] ?? '';

        // --- ส่วนแก้ไขข้อมูลโอนเงิน (Tap 2) ---
        idcardController.text = userData['nationalId'] ?? '';
        bookBankNoController.text = userData['bankAccountNumber'] ?? '';
        bookbankUrl = userData['bankAccountPhotoUrl'] ?? '';
        _selectedBank = userData['bankId']?.toString();

        _phoneVisibility = userData['phoneVisibility'];
        _facebookVisibility = userData['facebookVisibility'];
        _lineVisibility = userData['lineVisibility'];

        // --- ส่วนแก้ไขระดับมือ (Tap 3) ---
        // สมมติว่า API คืนค่า skillLevels มาเป็น List of maps
        if (skillLevelsData is List && skillLevelsData.isNotEmpty) {
          final List<SkillLevel> levelsFromApi = skillLevelsData.map((
            levelData,
          ) {
            return SkillLevel(
              skillLevelId: levelData['skillLevelId'],
              levelRank: levelData['levelRank'],
              name: levelData['levelName'],
              // (Optional) แปลง Hex color string เป็น Color object
              selectedColor: Color(
                int.parse(
                      levelData['colorHexCode'].substring(1, 7),
                      radix: 16,
                    ) +
                    0xFF000000,
              ),
            );
          }).toList();

          setState(() {
            // Dispose controllers เก่าก่อน
            for (var level in _skillLevels) {
              level.dispose();
            }
            // อัปเดต List ด้วยข้อมูลจาก API
            _skillLevels = levelsFromApi;
            _numberOfLevels = _skillLevels.length.toString();
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      // จัดการ Error หากดึงข้อมูลไม่ได้
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('ไม่สามารถดึงข้อมูลได้: $e'),
          ),
        );
      }
    } finally {
      // 3. เมื่อทุกอย่างเสร็จสิ้น ให้ซ่อน Loading และแสดงฟอร์ม
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  _uploadImage(List<File> file,String type) async {
    try {
      final response = await ApiProvider().uploadFiles(
        files: file,
        folderName: type,
      );

      if (response.length > 0) {
        if (mounted) {
          setState(() {
            switch (type) {
              case 'ProfileOrganizer':
                profileImageUrl = response[0]['imageUrl'];
                break;
              case 'Bookbank':
                bookbankUrl = response[0]['imageUrl'];
                break;
              default:
            }
          });
        }
      } else {
        if (mounted) {
          final errorMessage =
              response['message'] ?? 'เกิดข้อผิดพลาดไม่ทราบสาเหตุ';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.orange,
              content: Text(errorMessage),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _saveData() async {
    setState(() {
      _isSaving = true;
    });

    try {
      switch (_selectedIndex) {
        case 0: // แก้ไขข้อมูลติดต่อ
          await _saveContactInfo();
          break;
        case 1: // แก้ไขข้อมูลโอนเงิน
          await _saveTransferInfo();
          break;
        case 2: // แก้ไขเกณฑ์ระดับมือ
          await _saveSkillLevels();
          break;
        case 3: // แก้ไขรหัสผ่าน
          await _saveNewPassword();
          break;
      }
      // ถ้าสำเร็จ แสดง SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('บันทึกข้อมูลสำเร็จ'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('บันทึกข้อมูลล้มเหลว: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveContactInfo() async {
    final Map<String, dynamic> data = {
      'firstName': _firstNameController.text,
      'lastName': _lastNameController.text,
      'email': _emailController.text,
      "gender": _selectedGender,
      "profilePhotoUrl": profileImageUrl,
      'emergencyContactName': emergencyNameController.text,
      'emergencyContactPhone': emergencyPhoneController.text,
      'publicPhoneNumber': _publicPhoneController.text,
      'facebookLink': _facebookController.text,
      'lineId': _lineIdController.text,
      "phoneVisibility": _phoneVisibility,
      "facebookVisibility": _facebookVisibility,
      "lineVisibility": _lineVisibility,
    };
    await ApiProvider().put('/Organizer/profileUserAndOrganizer', data: data);
  }

  Future<void> _saveTransferInfo() async {
    final Map<String, dynamic> data = {
      'nationalId': idcardController.text,
      'bankId': int.tryParse(_selectedBank ?? '0'),
      'bankAccountNumber': bookBankNoController.text,
      'bankAccountPhotoUrl': bookbankUrl,
    };
    await ApiProvider().put('/Organizer/updateTransferBooking', data: data);
  }

  Future<void> _saveSkillLevels() async {
    final List<Map<String, dynamic>> levelsData = _skillLevels.map((level) {
      return {
        'skillLevelId': level.skillLevelId,
        'levelRank': level.levelRank,
        'levelName': level.nameController.text,
        'colorHexCode':
            '#${level.selectedColor.value.toRadixString(16).substring(2)}',
      };
    }).toList();

    await ApiProvider().post('/organizer/skill-levels', data: levelsData);
  }

  Future<void> _saveNewPassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      throw Exception('รหัสผ่านใหม่ไม่ตรงกัน');
    }
    final Map<String, dynamic> data = {
      'oldPassword': _oldPasswordController.text,
      'newPassword': _newPasswordController.text,
    };
    await ApiProvider().post('/Auth/change-password', data: data);
  }

  @override
  Widget build(BuildContext context) {
    const double tabletBreakpoint = 768;
    final bool isTablet = MediaQuery.of(context).size.width >= tabletBreakpoint;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBarSubMain(title: 'Profile', isBack: false),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (isTablet) {
      // --- 🖥️ Layout สำหรับ Tablet ---
      double menuWidth = _isPanelVisible
          ? 350
          : MediaQuery.of(context).size.width;
      return Scaffold(
        appBar: AppBarSubMain(title: 'Profile', isBack: false),
        body: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: menuWidth,
              color: Colors.white,
              child: _buildMenuView(isTablet: true),
            ),
            if (_isPanelVisible)
              Expanded(
                child: Container(
                  color: Colors.white,
                  // color: isHistory || isHistoryFinance
                  //     ? Color(0xFFB3B3C1)
                  //     : Colors.white,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          // แสดง Widget ตามเมนูที่เลือก
                          child: _topMenuItems[_selectedIndex].contentWidget(
                            context,
                          ),
                        ),
                      ),
                      // ปุ่มบันทึกข้อมูล
                      if (_topMenuItems[_selectedIndex].title != 'การเงิน')
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: CustomElevatedButton(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue.shade900,
                              onPressed: _isSaving ? () {} : _saveData,
                              text: 'บันทึกการแก้ไข',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      // --- 📱 Layout สำหรับ Mobile ---
      return Scaffold(
        appBar: AppBarSubMain(title: 'Profile', isBack: false),
        body: _buildMenuView(isTablet: false),
      );
    }
  }

  profile() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(5.0),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(45)),
            child: GestureDetector(
              onTap: () {},
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: (profileImageUrl.isNotEmpty)
                    ? LoadingImageNetwork(
                        profileImageUrl,
                        fit: BoxFit.cover,
                        isProfile: true,
                      )
                    : ClipOval(
                        child: Image.asset(
                          'assets/icon/profile.png',
                          width: 50,
                          height: 50,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${_firstNameController.text} ${_lastNameController.text}",
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: getResponsiveFontSize(context, fontSize: 20),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'somsuay@mail.com',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 10),
                      color: Color(0XFF64646D),
                    ),
                  ),
                  Text(
                    '0878067785',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 10),
                      color: Color(0XFF64646D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  menu(
    String title,
    Function()? callBack, {
    path = '',
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: GestureDetector(
        onTap: callBack,
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: title == 'Log out'
                      ? Color(0XFFDB2C2C)
                      : Color(0xFF000000),
                  fontSize: getResponsiveFontSize(context, fontSize: 20),
                  fontWeight: FontWeight.w400,
                ),
              ),
              path == ''
                  ? Icon(
                      Icons.arrow_forward,
                      color: Color(0xFF000000),
                      size: 20,
                      fontWeight: FontWeight.w400,
                    )
                  : Image.asset(
                      path,
                      color: title == 'Log out'
                          ? Color(0XFFDB2C2C)
                          : Color(0xFF000000),
                      width: 16,
                      height: 16,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuView({required bool isTablet}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFD5DCF4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          profile(),
          // สร้างเมนูส่วนบนจาก List
          ..._topMenuItems.asMap().entries.map((entry) {
            int index = entry.key;
            ProfileMenuItem item = entry.value;
            return menu(
              item.title,
              () {
                if (isTablet) {
                  setState(() {
                    isHistory = false;
                    isHistoryFinance = false;
                    final selectedIndexOld = _selectedIndex;
                    _selectedIndex = index;
                    _isPanelVisible =
                        selectedIndexOld == index && _isPanelVisible
                        ? false
                        : true;
                  });
                } else {
                  if (item.mobileRoute != null) {
                    context.push(item.mobileRoute!);
                  } else if (item.onTap != null) {
                    item.onTap!();
                  }
                }
              },
              path: item.iconPath,
              isSelected:
                  isTablet && _isPanelVisible && _selectedIndex == index,
            );
          }),
          const Spacer(),
          // สร้างเมนูส่วนล่างจาก List
          ..._bottomMenuItems.map((item) {
            return menu(item.title, item.onTap, path: item.iconPath);
          }),
        ],
      ),
    );
  }

  // ------- Tap 1 -------
  Widget _buildContactInfoForm(BuildContext context) {
    // ใช้ LayoutBuilder เพื่อเช็คขนาดของพื้นที่ที่วาดได้
    return LayoutBuilder(
      builder: (context, constraints) {
        //  กำหนดขนาดขั้นต่ำของหน้าจอที่เราจะถือว่าเป็น "จอใหญ่" (Tablet)
        const double tabletBreakpoint = 600;

        // ตรวจสอบว่าความกว้างปัจจุบันมากกว่า breakpoint ที่เราตั้งไว้หรือไม่
        final bool isTablet = constraints.maxWidth >= tabletBreakpoint;

        if (isTablet) {
          //  ถ้าเป็นจอใหญ่ (Tablet) -> ใช้ Row เหมือนเดิมเพื่อแสดงผลข้างกัน
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPersonalInfoCard()),
                const SizedBox(width: 24),
                Expanded(child: _buildPublicContactCard()),
              ],
            ),
          );
        } else {
          //  ถ้าเป็นจอเล็ก (Mobile) -> ใช้ Column เพื่อแสดงผลบน-ล่าง
          return Padding(
            padding: const EdgeInsets.all(16.0), // ลด Padding ให้เหมาะกับมือถือ
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPersonalInfoCard(),
                const SizedBox(height: 24), // เพิ่มระยะห่างแนวตั้ง
                _buildPublicContactCard(),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ข้อมูลส่วนตัว',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: getResponsiveFontSize(context, fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: [
                  // CircleAvatar(
                  //   radius: 50,
                  //   backgroundImage: NetworkImage(profileImageUrl),
                  // ),
                  ImageUploadPicker(
                    callback: (file) => {
                      setState(() {
                        _uploadImage(file, 'ProfileOrganizer');
                      }),
                    },
                    child: profileImageUrl != ''
                        ? Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: NetworkImage(profileImageUrl),
                                fit: BoxFit.cover,
                              ),
                              borderRadius: BorderRadius.circular(100.0),
                            ),
                          )
                        : Image.asset(
                            'assets/icon/profile.png',
                            fit: BoxFit.cover,
                            height: 120,
                            width: 120,
                            color: Colors.black,
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.black,
                      radius: 15,
                      child: Icon(Icons.edit, size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              controller: _firstNameController,
              labelText: 'ชื่อจริง',
              isRequired: true,
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              controller: _lastNameController,
              labelText: 'นามสกุล',
              isRequired: true,
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              controller: _emailController,
              labelText: 'Email',
              isRequired: true,
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              controller: _phoneController,
              labelText: 'เบอร์โทรศัพท์',
              isRequired: true,
              enabled: false,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            CustomDropdown(
              labelText: 'เพศ',
              initialValue: _selectedGender,
              items: [
                {"code": "1", "value": 'ชาย'},
                {"code": "2", "value": 'หญิง'},
                {"code": "3", "value": 'อื่นๆ'},
              ],
              isRequired: true,
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาเลือกเพศ';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomTextFormField(
                    labelText: 'ชื่อผู้ติดต่อฉุกเฉิน',
                    hintText: 'กรอกชื่อผู้ฉุกเฉิน',
                    controller: emergencyNameController,
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                Expanded(
                  child: CustomTextFormField(
                    labelText: 'เบอร์ผู้ติดต่อฉุกเฉิน',
                    hintText: 'กรอกเบอร์ผฉุกเฉิน',
                    controller: emergencyPhoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicContactCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ข้อมูลติดต่อส่วนตัว',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: getResponsiveFontSize(context, fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            // CustomTextFormField(
            //   controller: _phoneController,
            //   labelText: 'เบอร์โทรลงทะเบียน',
            //   enabled: false,
            // ),
            // Row(
            //   children: [
            //     Expanded(
            //       child: CheckboxListTile(
            //         title: Text(
            //           'แสดงข้อมูลก่อนจอง',
            //           style: TextStyle(
            //             fontWeight: FontWeight.w400,
            //             fontSize: getResponsiveFontSize(context, fontSize: 12),
            //           ),
            //         ),
            //         value: false,
            //         onChanged: (bool? value) => {},
            //         controlAffinity: ListTileControlAffinity.leading,
            //         contentPadding: EdgeInsets.zero,
            //       ),
            //     ),
            //     Expanded(
            //       child: CheckboxListTile(
            //         title: Text(
            //           'แสดงข้อมูลหลังจอง',
            //           style: TextStyle(
            //             fontWeight: FontWeight.w400,
            //             fontSize: getResponsiveFontSize(context, fontSize: 12),
            //           ),
            //         ),
            //         value: false,
            //         onChanged: (bool? value) => {},
            //         controlAffinity: ListTileControlAffinity.leading,
            //         contentPadding: EdgeInsets.zero,
            //       ),
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 16),
            CustomTextFormField(
              controller: _publicPhoneController,
              labelText: 'เบอร์โทรสาธารณะ',
              isRequired: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'แสดงข้อมูลก่อนจอง',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: getResponsiveFontSize(context, fontSize: 12),
                      ),
                    ),
                    value: _phoneVisibility == 3 ? true : false,
                    onChanged: (bool? value) => {
                      if (value == true)
                        setState(() {
                          _phoneVisibility = 3;
                        }),
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'แสดงข้อมูลก่อนจอง',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: getResponsiveFontSize(context, fontSize: 12),
                      ),
                    ),
                    value: _phoneVisibility == 2 ? true : false,
                    onChanged: (bool? value) => {
                      if (value == true)
                        setState(() {
                          _phoneVisibility = 2;
                        }),
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              controller: _facebookController,
              labelText: 'Facebook link',
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'แสดงข้อมูลก่อนจอง',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: getResponsiveFontSize(context, fontSize: 12),
                      ),
                    ),
                    value: _facebookVisibility == 3 ? true : false,
                    onChanged: (bool? value) => {
                      if (value == true)
                        setState(() {
                          _facebookVisibility = 3;
                        }),
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'แสดงข้อมูลก่อนจอง',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: getResponsiveFontSize(context, fontSize: 12),
                      ),
                    ),
                    value: _facebookVisibility == 2 ? true : false,
                    onChanged: (bool? value) => {
                      if (value == true)
                        setState(() {
                          _facebookVisibility = 2;
                        }),
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              controller: _lineIdController,
              labelText: 'Line ID',
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'แสดงข้อมูลก่อนจอง',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: getResponsiveFontSize(context, fontSize: 12),
                      ),
                    ),
                    value: _lineVisibility == 3 ? true : false,
                    onChanged: (bool? value) => {
                      if (value == true)
                        setState(() {
                          _lineVisibility = 3;
                        }),
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'แสดงข้อมูลก่อนจอง',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: getResponsiveFontSize(context, fontSize: 12),
                      ),
                    ),
                    value: _lineVisibility == 2 ? true : false,
                    onChanged: (bool? value) => {
                      if (value == true)
                        setState(() {
                          _lineVisibility = 2;
                        }),
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------- Tap 2 -------
  Widget _buildTransferInfoForm(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ข้อมูลโอนเงิน',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: getResponsiveFontSize(context, fontSize: 22),
                color: Color(0XFF64646D),
              ),
            ),
            SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'เลขบัตรประจำตัวประชาชน',
              hintText: 'กรุณากรอกเลขบัตรประจำตัวประชาชน',
              isRequired: true,
              controller: idcardController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return 'กรุณากรอกข้อมูล';
                if (value.length != 13) return 'เลขบัตรต้องมี 13 หลัก';
                return null;
              },
            ),
            SizedBox(height: 16),
            CustomDropdown(
              labelText: 'ธนาคาร',
              initialValue: _selectedBank,
              items: _banks,
              isRequired: true,
              onChanged: (value) {
                setState(() {
                  _selectedBank = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาเลือกเพศ';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'เลขบัญชี',
              hintText: 'กรุณากรอกเลขบัญชี',
              isRequired: true,
              controller: bookBankNoController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            SizedBox(height: 16),
            ImagePickerFormField(
              labelText: 'รูป Bookbank',
              isRequired: true,
              initialImageUrl: bookbankUrl,
              onImageSelected: (File image) {
                _uploadImage([image], 'Bookbank');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------- Tap 3 -------
  void _generateSkillLevels(int count) {
    final currentCount = _skillLevels.length;

    // ถ้าจำนวนไม่เปลี่ยนแปลง ก็ไม่ต้องทำอะไร
    if (count == currentCount) return;

    setState(() {
      if (count > currentCount) {
        // --- กรณีเพิ่มจำนวน ---
        // เพิ่มเฉพาะส่วนที่ขาดหายไป
        for (int i = currentCount; i < count; i++) {
          _skillLevels.add(
            SkillLevel(
              levelRank: i + 1,
              name: 'ระดับ ${i + 1}', // ชื่อเริ่มต้นสำหรับรายการใหม่
              selectedColor: HSLColor.fromAHSL(
                1.0,
                (360 / 10) * i,
                0.8,
                0.6,
              ).toColor(),
            ),
          );
        }
      } else {
        // --- กรณีลดจำนวน ---
        // 1. Dispose controllers ของรายการที่จะถูกลบก่อน
        for (int i = count; i < currentCount; i++) {
          _skillLevels[i].dispose();
        }
        // 2. ลบรายการส่วนเกินออกจาก List
        _skillLevels.removeRange(count, currentCount);
      }
    });
  }

  void _showColorPickerDialog(SkillLevel level) {
    Color pickerColor = level.selectedColor; // สีเริ่มต้นใน picker

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เลือกสี'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (Color color) {
                pickerColor = color; // อัปเดตสีชั่วคราวเมื่อผู้ใช้เลื่อน
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false, // ปิดตัวเลือกความโปร่งใส
              displayThumbColor: true,
              paletteType: PaletteType.hsv,
              pickerAreaBorderRadius: const BorderRadius.all(
                Radius.circular(8.0),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('ยืนยัน'),
              onPressed: () {
                setState(() {
                  level.selectedColor =
                      pickerColor; // อัปเดตสีจริงเมื่อกดยืนยัน
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkillLevelInfoForm(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'แก้ไขระดับทักษะฝีมือ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            // --- Dropdown สำหรับเลือกจำนวนระดับ ---
            CustomDropdown(
              labelText: '',
              initialValue: _numberOfLevels,
              items: [
                {"code": "1", "value": '1'},
                {"code": "2", "value": '2'},
                {"code": "3", "value": '3'},
                {"code": "4", "value": '4'},
                {"code": "5", "value": '5'},
                {"code": "6", "value": '6'},
                {"code": "7", "value": '7'},
                {"code": "8", "value": '8'},
                {"code": "9", "value": '9'},
                {"code": "10", "value": '10'},
              ],
              onChanged: (value) {
                setState(() {
                  _numberOfLevels = value ?? '0';
                  _generateSkillLevels(int.parse(value ?? ''));
                });
              },
            ),
            const SizedBox(height: 24),
            // --- ส่วนหัวของตาราง ---
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'ฝีมือ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: getResponsiveFontSize(context, fontSize: 16),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'ชื่อ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: getResponsiveFontSize(context, fontSize: 16),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'สี',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: getResponsiveFontSize(context, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // --- ListView สำหรับสร้างรายการแก้ไขระดับ ---
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _skillLevels.length,
              itemBuilder: (context, index) {
                final level = _skillLevels[index];
                final levelName = index == 0
                    ? 'น้อยสุด'
                    : (index == _skillLevels.length - 1
                          ? 'มากสุด'
                          : '${index + 1}');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          levelName,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: getResponsiveFontSize(
                              context,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: CustomTextFormField(
                          labelText: '',
                          hintText: '',
                          controller: level.nameController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () => _showColorPickerDialog(level),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: level.selectedColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                // แปลงรหัสสีเป็น Hex code เพื่อแสดงผล
                                '#${level.selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                                style: TextStyle(
                                  color:
                                      level.selectedColor.computeLuminance() >
                                          0.5
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.w400,
                                  fontSize: getResponsiveFontSize(
                                    context,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------- Tap 4 -------
  Widget _buildChangePasswordContent(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextFormField(
              labelText: 'รหัสผ่านเดิม',
              hintText: 'กรุณากรอกรหัสผ่านเดิม',
              isRequired: true,
              controller: _oldPasswordController,
              obscureText: !_isPasswordVisible,
              prefixIconData: Icons.lock_outline,
              suffixIconData: _isPasswordVisible
                  ? Icons.visibility_off
                  : Icons.visibility,
              onSuffixIconPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'รหัสผ่านใหม่',
              hintText: 'กรุณากรอกรหัสผ่านใหม่',
              isRequired: true,
              controller: _newPasswordController,
              obscureText: !_isNewPasswordVisible,
              prefixIconData: Icons.lock_outline,
              suffixIconData: _isNewPasswordVisible
                  ? Icons.visibility_off
                  : Icons.visibility,
              onSuffixIconPressed: () => setState(
                () => _isNewPasswordVisible = !_isNewPasswordVisible,
              ),
            ),
            SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'ยืนยันรหัสผ่านใหม่',
              hintText: 'กรุณากรอกยืนยันรหัสผ่านใหม่',
              isRequired: true,
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              prefixIconData: Icons.lock_outline,
              suffixIconData: _isConfirmPasswordVisible
                  ? Icons.visibility_off
                  : Icons.visibility,
              onSuffixIconPressed: () => setState(
                () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณายืนยันรหัสผ่าน';
                }
                // เปรียบเทียบค่ากับ password controller ตัวแรก
                if (value != _newPasswordController.text) {
                  return 'รหัสผ่านไม่ตรงกัน';
                }
                // ถ้าทุกอย่างถูกต้อง ให้ return null
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------- Tap 5 -------
  void _showWithdrawAmountSheet() {
    final amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ถอนเงินจำนวน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ระบุจำนวนเงิน',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // ปิด Bottom Sheet
                  _showWithdrawConfirmationDialog(); // เปิด Dialog ยืนยัน
                },
                child: const Text('ถอนเงิน'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showWithdrawConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              _buildDialogRow('ถอนเงิน', '100 บาท'),
              _buildDialogRow('ค่าธรรมเนียม', '10 บาท'),
              const Divider(height: 24),
              _buildDialogRow('ราคารวม', '90 บาท', isBold: true),
              const SizedBox(height: 20),
              const Text('ยืนยันการถอนเงินไปที่'),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'เลขบัตรประชาชน *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                items: const [
                  DropdownMenuItem(value: 'Kbank', child: Text('Kbank')),
                ],
                onChanged: (v) {},
                decoration: const InputDecoration(
                  labelText: 'ธนาคาร *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Bookbank *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'รูป Bookbank *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: () {},
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('ยืนยันการถอนเงิน'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogRow(String title, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceForm(BuildContext context) {
    // ใช้ LayoutBuilder เพื่อเช็คขนาดของพื้นที่ที่วาดได้
    return LayoutBuilder(
      builder: (context, constraints) {
        //  กำหนดขนาดขั้นต่ำของหน้าจอที่เราจะถือว่าเป็น "จอใหญ่" (Tablet)
        const double tabletBreakpoint = 600;

        // ตรวจสอบว่าความกว้างปัจจุบันมากกว่า breakpoint ที่เราตั้งไว้หรือไม่
        final bool isTablet = constraints.maxWidth >= tabletBreakpoint;

        if (isTablet) {
          //  ถ้าเป็นจอใหญ่ (Tablet) -> ใช้ Row เหมือนเดิมเพื่อแสดงผลข้างกัน
          return Padding(
            padding: const EdgeInsets.all(14.0),
            child: !isHistory && !isHistoryFinance
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            // _balanceCardFinance(),
                            BalanceCardFinance(
                              balance: '1860 บาท',
                              incomeText: 'รายได้: 4000 บาท',
                              pendingText: 'รอชำระ: 1600 บาท',
                              onWithdrawPressed: () =>
                                  _showWithdrawAmountSheet(),
                            ),
                            SizedBox(height: 16),
                            IncomeChartCard(
                              title: 'รายละเอียด 5 เกมล่าสุด',
                              totalIncomeText: 'รายได้ 2,560 บาท',
                              chartData: [
                                ChartGroup(
                                  name: 'ก๊วนแซมสเดย์',
                                  playersValue: 42,
                                  paidValue: 30,
                                ),
                                ChartGroup(
                                  name: 'ก๊วนแมวเหมียว',
                                  playersValue: 78,
                                  paidValue: 52,
                                ),
                                ChartGroup(
                                  name: 'ก๊วนหมาบ้า',
                                  playersValue: 50,
                                  paidValue: 38,
                                ),
                                ChartGroup(
                                  name: 'ก๊วนช้าง',
                                  playersValue: 65,
                                  paidValue: 45,
                                ),
                                ChartGroup(
                                  name: 'ก๊วนหมีง่วง',
                                  playersValue: 42,
                                  paidValue: 32,
                                ),
                              ],
                              onDetailsPressed: () {
                                print('Details button pressed!');
                                // Navigate to details page
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: HistoryCardFinance(
                          initialTimeRange: 'วันนี้',
                          timeRangeItems: [
                            {"1": 'วันนี้'},
                            {"2": 'สัปดาห์นี้'},
                            {"3": 'เดือนนี้'},
                            {"4": 'ทั้งหมด'},
                          ],
                          incomeHistory: [
                            HistoryItem(
                              date: '21/04/25',
                              time: '13:03 PM',
                              amount: '3000',
                              totalAmount: '4500',
                              groupName: 'ก๊วนแบดหรรษา',
                            ),
                            HistoryItem(
                              date: '21/04/25',
                              time: '13:03 PM',
                              amount: '3000',
                              totalAmount: '4500',
                              groupName: 'ก๊วนแบดหรรษา',
                            ),
                            HistoryItem(
                              date: '21/04/25',
                              time: '13:03 PM',
                              amount: '3000',
                              totalAmount: '4500',
                              groupName: 'ก๊วนแบดหรรษา',
                            ),
                            HistoryItem(
                              date: '21/04/25',
                              time: '13:03 PM',
                              amount: '3000',
                              totalAmount: '4500',
                              groupName: 'ก๊วนแบดหรรษา',
                            ),
                            HistoryItem(
                              date: '21/04/25',
                              time: '13:03 PM',
                              amount: '3000',
                              totalAmount: '4500',
                              groupName: 'ก๊วนแบดหรรษา',
                            ),
                          ],
                          withdrawalHistoryView: const Center(
                            child: Text('ประวัติเงินออกแสดงที่นี่'),
                          ),
                          onTimeRangeChanged: (value) {
                            print('Selected time range: $value');
                            // Fetch new data based on the selected time range
                          },
                          onIncomeItemAmountTap: (item) {
                            print('Tapped on amount of: ${item.groupName}');
                            setState(() {
                              isHistoryFinance = true;
                            });
                          },
                          onIncomeItemGroupTap: (item) {
                            print('Tapped on group: ${item.groupName}');
                            setState(() {
                              isHistory = true;
                            });
                          },
                        ),
                      ),
                    ],
                  )
                : isHistory
                ? detailsViewHistoryRow(
                    context,
                    onBack: () => setState(() {
                      isHistory = false;
                    }),
                  )
                : isHistoryFinance
                ? detailsViewHistoryFinanceRow(
                    context,
                    onBack: () => setState(() {
                      isHistoryFinance = false;
                    }),
                  )
                : Container(),
          );
        } else {
          //  ถ้าเป็นจอเล็ก (Mobile) -> ใช้ Column เพื่อแสดงผลบน-ล่าง
          return Padding(
            padding: const EdgeInsets.all(16.0), // ลด Padding ให้เหมาะกับมือถือ
            child: !isHistory && !isHistoryFinance
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BalanceCardFinance(
                        balance: '1860 บาท',
                        incomeText: 'รายได้: 4000 บาท',
                        pendingText: 'รอชำระ: 1600 บาท',
                        onWithdrawPressed: () => _showWithdrawAmountSheet(),
                      ),
                      SizedBox(height: 16),
                      IncomeChartCard(
                        title: 'รายละเอียด 5 เกมล่าสุด',
                        totalIncomeText: 'รายได้ 2,560 บาท',
                        chartData: [
                          ChartGroup(
                            name: 'ก๊วนแซมสเดย์',
                            playersValue: 42,
                            paidValue: 30,
                          ),
                          ChartGroup(
                            name: 'ก๊วนแมวเหมียว',
                            playersValue: 78,
                            paidValue: 52,
                          ),
                          ChartGroup(
                            name: 'ก๊วนหมาบ้า',
                            playersValue: 50,
                            paidValue: 38,
                          ),
                          ChartGroup(
                            name: 'ก๊วนช้าง',
                            playersValue: 65,
                            paidValue: 45,
                          ),
                          ChartGroup(
                            name: 'ก๊วนหมีง่วง',
                            playersValue: 42,
                            paidValue: 32,
                          ),
                        ],
                        onDetailsPressed: () {
                          print('Details button pressed!');
                          // Navigate to details page
                        },
                      ),
                      SizedBox(height: 16),
                      HistoryCardFinance(
                        initialTimeRange: 'วันนี้',
                        timeRangeItems: [
                          {"1": 'วันนี้'},
                          {"2": 'สัปดาห์นี้'},
                          {"3": 'เดือนนี้'},
                          {"4": 'ทั้งหมด'},
                        ],
                        incomeHistory: [
                          HistoryItem(
                            date: '21/04/25',
                            time: '13:03 PM',
                            amount: '3000',
                            totalAmount: '4500',
                            groupName: 'ก๊วนแบดหรรษา',
                          ),
                          HistoryItem(
                            date: '21/04/25',
                            time: '13:03 PM',
                            amount: '3000',
                            totalAmount: '4500',
                            groupName: 'ก๊วนแบดหรรษา',
                          ),
                          HistoryItem(
                            date: '21/04/25',
                            time: '13:03 PM',
                            amount: '3000',
                            totalAmount: '4500',
                            groupName: 'ก๊วนแบดหรรษา',
                          ),
                          HistoryItem(
                            date: '21/04/25',
                            time: '13:03 PM',
                            amount: '3000',
                            totalAmount: '4500',
                            groupName: 'ก๊วนแบดหรรษา',
                          ),
                          HistoryItem(
                            date: '21/04/25',
                            time: '13:03 PM',
                            amount: '3000',
                            totalAmount: '4500',
                            groupName: 'ก๊วนแบดหรรษา',
                          ),
                        ],
                        withdrawalHistoryView: const Center(
                          child: Text('ประวัติเงินออกแสดงที่นี่'),
                        ),
                        onTimeRangeChanged: (value) {
                          print('Selected time range: $value');
                          // Fetch new data based on the selected time range
                        },
                        onIncomeItemAmountTap: (item) {
                          print('Tapped on amount of: ${item.groupName}');
                          setState(() {
                            isHistoryFinance = true;
                          });
                        },
                        onIncomeItemGroupTap: (item) {
                          print('Tapped on group: ${item.groupName}');
                          setState(() {
                            isHistory = true;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                    ],
                  )
                : isHistory
                ? detailsViewHistory(
                    context,
                    onBack: () => setState(() {
                      isHistory = false;
                    }),
                  )
                : isHistoryFinance
                ? detailsViewHistoryFinance(
                    context,
                    onBack: () => setState(() {
                      isHistoryFinance = false;
                    }),
                  )
                : Container(),
          );
        }
      },
    );
  }

  Widget detailsViewHistory(BuildContext context, {Function()? onBack}) {
    final bool isMobile = onBack != null;
    return Column(
      children: [
        // ปุ่ม Back สำหรับ Mobile
        if (isMobile)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back_ios),
              label: const Text('กลับไปที่รายการ'),
              onPressed: onBack,
            ),
          ),
        badmintonSummaryPage(context),
        badmintonSummaryPage2(context),
      ],
    );
  }

  Widget detailsViewHistoryRow(BuildContext context, {Function()? onBack}) {
    final bool isMobile = onBack != null;
    return Column(
      children: [
        // ปุ่ม Back สำหรับ Mobile
        if (isMobile)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back_ios),
              label: const Text('กลับไปที่รายการ'),
              onPressed: onBack,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: badmintonSummaryPage(context)),
            SizedBox(width: 3),
            Expanded(child: badmintonSummaryPage2(context)),
          ],
        ),
      ],
    );
  }

  Widget badmintonSummaryPage(BuildContext context) {
    return Column(
      children: [
        GroupInfoCard(model: dataList[0]),
        SizedBox(height: 16),
        ImageSlideshow(model: dataList[0]),
        SizedBox(height: 16),
        DetailsCard(),
        SizedBox(height: 16),
        ActionButtons(),
        SizedBox(height: 16),
      ],
    );
  }

  Widget badmintonSummaryPage2(BuildContext context) {
    return Column(
      children: const [SummaryCard(), SizedBox(height: 16), GameTimingCard()],
    );
  }

  Widget detailsViewHistoryFinance(BuildContext context, {Function()? onBack}) {
    final bool isMobile = onBack != null;
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // ปุ่ม Back สำหรับ Mobile
        if (isMobile)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back_ios),
              label: const Text('กลับไปที่รายการ'),
              onPressed: onBack,
            ),
          ),
        CostsSummary(),
        PlayerListCard(
          padding: EdgeInsetsGeometry.symmetric(vertical: 16),
          onPlayerTap: () {},
        ),
      ],
    );
  }

  Widget detailsViewHistoryFinanceRow(
    BuildContext context, {
    Function()? onBack,
  }) {
    final bool isMobile = onBack != null;
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // ปุ่ม Back สำหรับ Mobile
        if (isMobile)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back_ios),
              label: const Text('กลับไปที่รายการ'),
              onPressed: onBack,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(child: CostsSummary()),
            Expanded(
              child: PlayerListCard(
                padding: EdgeInsetsGeometry.only(left: 5),
                onPlayerTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}
