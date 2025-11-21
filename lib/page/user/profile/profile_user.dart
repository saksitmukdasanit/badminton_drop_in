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

  void _showQrDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return QrCodeDialog(qrData: userId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'Profile', isBack: false),
      body: FutureBuilder<dynamic>(
        future: futureModel,
        builder: (context, snapshot) {
          // --- จัดการสถานะการโหลดและ Error ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No data found.'));
          }

          // --- เมื่อมีข้อมูล ---
          final userData = snapshot.data;
          // --- NEW: ดึงค่า isOrganizer จาก API ---
          final bool isOrganizer = userData['data']['isOrganizer'] ?? false;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    profile(context, userData),
                    menu('แก้ไขข้อมูลส่วนตัว', () async {
                      await context.push('/edit-profile-user');
                      _callReadMe();
                    }),
                    menu('เปลี่ยนรหัสผ่าน', () {
                      context.push('/change-password');
                    }),
                    menu('Saved Payment', () {
                      context.push('/saved-payment');
                    }),
                    menu('Favourite', () {
                      context.push('/favourite');
                    }),
                    menu('QR code เข้าร่วมเกม', () {
                      _showQrDialog(
                        context,
                        userData['data']['userId'].toString(),
                      );
                    }),
                  ],
                ),
                Column(
                  children: [
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
                    menu('ลบ Account', path: 'assets/icon/delete.png', () {
                      if (overdue) {
                        showDialogMsg(
                          context,
                          title: 'ไม่สามารถลบ Account',
                          subtitle: 'คุณมียอดค้างจ่ายจำนวน 236 บาท',
                          btnLeft: 'จ่ายเงิน',
                          btnRightBackColor: Color(0xFFFFFFFF),
                          btnRightForeColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          btnRight: 'ยกเลิก',
                          onConfirm: () {
                            setState(() {
                              overdue = !overdue;
                            });
                          },
                        );
                      } else {
                        showDialogMsg(
                          context,
                          title: 'ยืนยับการลบ Account',
                          subtitle: 'เมื่อลบแล้วจะไม่สามารถกูคืนได้',
                          btnLeft: 'ลบ Account',
                          btnLeftBackColor: Color(0xFF000000),
                          onConfirm: () {
                            setState(() {
                              overdue = !overdue;
                            });
                            showDialogMsg(
                              context,
                              title: 'ลบ Account เรียบร้อย',
                              subtitle: 'ลบข้อมูลของ สมสวย มีสุข',
                              btnLeft: 'ไปหน้า Log In',
                              onConfirm: () {},
                            );
                          },
                        );
                      }
                    }),
                    menu('Log out', path: 'assets/icon/exit.png', () {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
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
              ],
            ),
          );
        },
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
                child: ((userData['data']['ProfilePhotoUrl'] ?? '') != '')
                    ? LoadingImageNetwork(
                        userData['data']['ProfilePhotoUrl'],
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
                    userData['data']['primaryContactEmail'],
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 14),
                      color: Color(0XFF64646D),
                    ),
                  ),
                  Text(
                    userData['data']['phoneNumber'],
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
