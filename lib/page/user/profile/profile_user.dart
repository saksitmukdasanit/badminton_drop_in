import 'dart:async';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/loading_image_network.dart';
import 'package:badminton/component/qrcode_dialog.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/user_role.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class ProFileUserPage extends StatefulWidget {
  const ProFileUserPage({super.key});

  @override
  ProFileUserPageState createState() => ProFileUserPageState();
}

class ProFileUserPageState extends State<ProFileUserPage> {
  late Future<dynamic> futureModel;
  bool overdue = false;

  @override
  void initState() {
    futureModel = _callReadMe();

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _callReadMe() {
    return ApiProvider().get('/Auth/me');
  }

  Future<void> _handleAccountDeletion(BuildContext context) async {
    showDialogMsg(
      context,
      title: 'ยืนยันการลบบัญชี',
      subtitle:
          'เมื่อยืนยัน บัญชีของคุณจะถูกระงับทันทีและจะถูกลบถาวรภายใน 30 วัน '
          '(คุณสามารถ login กลับเข้ามาภายใน 30 วันเพื่อกู้คืนได้)\n\n'
          'ก่อนลบ ตรวจสอบให้แน่ใจว่า:\n'
          '• ถอนเงินจาก Wallet ออกหมดแล้ว\n'
          '• ไม่มีก๊วนที่กำลังจะมาถึง (ทั้งในฐานะผู้จัดและผู้เล่น)',
      btnLeft: 'ลบบัญชี',
      btnLeftBackColor: const Color(0xFFE53935),
      btnRight: 'ยกเลิก',
      btnRightBackColor: Colors.white,
      btnRightForeColor: Theme.of(context).colorScheme.primary,
      onConfirm: () async {
        try {
          final response = await ApiProvider().post('/Auth/request-deletion');
          if (response['status'] == 200) {
            if (!mounted) return;
            final scheduledAt = response['data']?['scheduledForDeletionAt'];
            final scheduleText = scheduledAt != null
                ? 'จะถูกลบถาวรในวันที่ ${_formatDate(scheduledAt)}'
                : 'จะถูกลบถาวรภายใน 30 วัน';
            showDialogMsg(
              context,
              title: 'ระงับบัญชีเรียบร้อย',
              subtitle: 'บัญชีของคุณ$scheduleText',
              btnLeft: 'ไปหน้า Log In',
              onConfirm: () {
                Provider.of<AuthProvider>(context, listen: false).logout();
              },
            );
          }
        } catch (e) {
          if (!mounted) return;
          final msg = e.toString().replaceFirst('Exception: ', '');
          showDialogMsg(
            context,
            title: 'ไม่สามารถลบบัญชี',
            subtitle: msg,
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
        }
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  void _showQrDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return QrCodeDialog(qrData: userId);
      },
    );
  }

  static const _playerProfileGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBarSubMain(title: 'Profile', isBack: false),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: _playerProfileGradient),
        child: FutureBuilder<dynamic>(
          future: futureModel,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('No data found.'));
            }

            final userData = snapshot.data;
            final bool isOrganizer =
                userData['data']['isOrganizer'] ?? false;
            final bottomPad = MediaQuery.of(context).padding.bottom;

            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPad + 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          profile(context, userData),
                          menu('แก้ไขข้อมูลส่วนตัว', () async {
                            await context.push('/edit-profile-user');
                            if (mounted) {
                              setState(() => futureModel = _callReadMe());
                            }
                          }),
                          menu('เปลี่ยนรหัสผ่าน', () {
                            context.push('/change-password');
                          }),
                          menu('กระเป๋าเงินของฉัน (Wallet)', () {
                            context.push('/my-wallet');
                          }),
                          menu('บัญชีรับเงิน (ถอนเงิน)', () {
                            context.push('/saved-payment');
                          }),
                          menu('Favourite', () {
                            context.push('/favourite');
                          }),
                          menu('QR code เข้าร่วมเกม', () {
                            final qrData = userData['data']
                                    ['userPublicId'] ??
                                userData['data']['userId'] ??
                                userData['data']['id'];
                            _showQrDialog(context, qrData.toString());
                          }),
                          const SizedBox(height: 20),
                          if (isOrganizer)
                            menu('ไปหน้าผู้จัด', () {
                              context.read<UserRoleProvider>().setRole(
                                    Role.organizer,
                                  );
                              context.push('/profile-organizer');
                            })
                          else
                            menu('สมัครเป็นผู้จัด', () {
                              context.push('/apply-organizer');
                            }),
                          menu('เกี่ยวกับแอป / ข้อกำหนด', () {
                            context.push('/about');
                          }),
                          menu('ลบบัญชี',
                              path: 'assets/icon/delete.png', () {
                            _handleAccountDeletion(context);
                          }),
                          menu('Log out', path: 'assets/icon/exit.png', () {
                            final authProvider =
                                Provider.of<AuthProvider>(context,
                                    listen: false);
                            showDialogMsg(
                              context,
                              title: 'ยืนยับการออกจากระบบ',
                              subtitle: '',
                              btnLeft: 'ออกจากระบบ',
                              btnLeftBackColor: Color(0xFF000000),
                              onConfirm: () {
                                showDialogMsg(
                                  context,
                                  title: 'ออกจากระบบเรียบร้อย',
                                  subtitle: '',
                                  btnLeft: 'ไปหน้า Log In',
                                  onConfirm: () {
                                    authProvider.logout();
                                  },
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  profile(BuildContext context, dynamic userData) {
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
                child: ((userData['data']['profilePhotoUrl'] ?? '') != '')
                    ? LoadingImageNetwork(
                        userData['data']['profilePhotoUrl'],
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
                '${userData['data']['firstName']} ${userData['data']['lastName']}',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: getResponsiveFontSize(context, fontSize: 22),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                '${userData['data']['primaryContactEmail'] ?? '-'}',
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 14),
                  color: Color(0XFF64646D),
                ),
              ),
              Text(
                '${userData['data']['phoneNumber'] ?? '-'}',
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 14),
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

  menu(String title, Function()? callBack, {path = ''}) {
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
                  fontSize: 20,
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
}
