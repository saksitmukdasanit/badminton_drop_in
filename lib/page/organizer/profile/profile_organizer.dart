import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/image_picker_form.dart';
import 'package:badminton/component/loading_image_network.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/page/organizer/history/history_organizer.dart';
import 'package:badminton/page/organizer/history/history_organizer_payment.dart';
import 'package:badminton/page/organizer/profile/edit_skill_levels.dart';
import 'package:badminton/page/organizer/profile/finance.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  int _selectedIndex = 0;
  bool _isPanelVisible = false;
  late final List<ProfileMenuItem> _topMenuItems;
  late final List<ProfileMenuItem> _bottomMenuItems;
  String profileImageUrl = '';

  // ---- Edit profile
  final _firstNameController = TextEditingController(text: 'สวย');
  final _lastNameController = TextEditingController(text: 'คงทน');
  final _emailController = TextEditingController(text: 'somsuay@mail.com');
  final _phoneController = TextEditingController(text: '0878087785');
  final _publicPhoneController = TextEditingController(text: '0844438273');
  final _lineIdController = TextEditingController(text: 'somsuay1996');
  final _facebookController = TextEditingController(
    text: 'www.facebook.com/somsuay',
  );
  late TextEditingController emergencyNameController;
  late TextEditingController emergencyPhoneController;
  String? _selectedGender = 'หญิง';

  // ---- Edit Transfer
  late TextEditingController idcardController;
  late TextEditingController bookBankNoController;
  String? _selectedBank;
  XFile? _bookbankImage;
  final List<String> _banks = [
    'ธนาคารกสิกรไทย',
    'ธนาคารไทยพาณิชย์',
    'ธนาคารกรุงเทพ',
    'ธนาคารกรุงไทย',
  ];

  // ---- Edit SkillLevel
  String _numberOfLevels = '6';
  List<SkillLevel> _skillLevels = [];

  // ----- Change Password
  late TextEditingController _oldPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

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
        Navigator.of(context).pop();

        // Show success dialog
        showDialogMsg(
          context,
          title: 'ออกจากระบบเรียบร้อย',
          subtitle: '',
          btnLeft: 'ไปหน้า Log In',
          onConfirm: () {
            // TODO: Navigate to Login Page
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const double tabletBreakpoint = 768;
    final bool isTablet = MediaQuery.of(context).size.width >= tabletBreakpoint;

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
                            child: ElevatedButton(
                              onPressed: () {
                                // TODO: Add save logic here
                                print('บันทึกข้อมูล');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade900,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('บันทึกข้อมูล'),
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
                child: (profileImageUrl != '')
                    ? LoadingImageNetwork(
                        "",
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
                "Somsuay Meesook",
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
                  fontSize: getResponsiveFontSize(context, fontSize: 16),
                  fontWeight: FontWeight.w400,
                ),
              ),
              path == ''
                  ? Icon(
                      Icons.arrow_forward,
                      color: Color(0xFF000000),
                      size: 16,
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
                children: const [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                      'https://i.pravatar.cc/150?img=26',
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
            ),
            const SizedBox(height: 16),
            CustomDropdown(
              labelText: 'เพศ',
              initialValue: _selectedGender,
              items: ['ชาย', 'หญิง', 'อื่นๆ'],
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
            CustomTextFormField(
              controller: _publicPhoneController,
              labelText: 'เบอร์โทรศัพท์ติดต่อ',
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'แสดงข้อมูลก่อนจอง',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: getResponsiveFontSize(context, fontSize: 16),
                      ),
                    ),
                    value: false,
                    onChanged: (bool? value) => {},
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'แสดงข้อมูลหลังจอง',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: getResponsiveFontSize(context, fontSize: 16),
                      ),
                    ),
                    value: false,
                    onChanged: (bool? value) => {},
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextFormField(
              controller: _publicPhoneController,
              labelText: 'เบอร์โทรศัพท์สำรอง',
              isRequired: true,
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text(
                      'แสดงข้อมูลก่อนจอง',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: getResponsiveFontSize(context, fontSize: 16),
                      ),
                    ),
                    value: false,
                    onChanged: (bool? value) => {},
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
                        fontSize: getResponsiveFontSize(context, fontSize: 16),
                      ),
                    ),
                    value: false,
                    onChanged: (bool? value) => {},
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
                        fontSize: getResponsiveFontSize(context, fontSize: 16),
                      ),
                    ),
                    value: false,
                    onChanged: (bool? value) => {},
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
                        fontSize: getResponsiveFontSize(context, fontSize: 16),
                      ),
                    ),
                    value: false,
                    onChanged: (bool? value) => {},
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
                        fontSize: getResponsiveFontSize(context, fontSize: 16),
                      ),
                    ),
                    value: false,
                    onChanged: (bool? value) => {},
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
                        fontSize: getResponsiveFontSize(context, fontSize: 16),
                      ),
                    ),
                    value: false,
                    onChanged: (bool? value) => {},
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
            ),
            SizedBox(height: 16),
            ImagePickerFormField(
              labelText: 'รูป Bookbank',
              isRequired: true,
              onImageSelected: (XFile? image) {
                // รับไฟล์ที่เลือกกลับมาเก็บใน State ของหน้านี้
                setState(() {
                  _bookbankImage = image;
                });
                print('Image selected: ${_bookbankImage?.path}');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------- Tap 3 -------
  void _generateSkillLevels(int count) {
    if (_skillLevels.isNotEmpty) {
      for (var level in _skillLevels) {
        level.dispose();
      }
    }
    _skillLevels = List.generate(
      count,
      (index) => SkillLevel(
        name: index == 0 ? 'มือใหม่' : 'ระดับ ${index + 1}',
        // กำหนดสีเริ่มต้นแบบสุ่มหรือแบบไล่สีก็ได้
        selectedColor: HSLColor.fromAHSL(
          1.0,
          (360 / 10) * index,
          0.8,
          0.6,
        ).toColor(),
      ),
    );
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
              items: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'],
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
                    'ความเก่ง',
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
            ),
            SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'รหัสผ่านใหม่',
              hintText: 'กรุณากรอกรหัสผ่านใหม่',
              isRequired: true,
              controller: _newPasswordController,
            ),
            SizedBox(height: 16),
            CustomTextFormField(
              labelText: 'ยืนยันรหัสผ่านใหม่',
              hintText: 'กรุณากรอกยืนยันรหัสผ่านใหม่',
              isRequired: true,
              controller: _confirmPasswordController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณากรอกข้อมูลช่องนี้';
                }
                if (value != _newPasswordController.text) {
                  return 'รหัสผ่านใหม่ไม่ตรงกัน';
                }
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
                  child: const Text('ยืนยันการถอนเงิน'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
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
                            'วันนี้',
                            'สัปดาห์นี้',
                            'เดือนนี้',
                            'ทั้งหมด',
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
                          'วันนี้',
                          'สัปดาห์นี้',
                          'เดือนนี้',
                          'ทั้งหมด',
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
