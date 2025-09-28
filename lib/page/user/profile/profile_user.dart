import 'dart:async';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/loading_image_network.dart';
import 'package:badminton/component/qrcode_dialog.dart';
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
  String profileImageUrl = '';
  bool overdue = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const QrCodeDialog(qrData: 'user_id_12345');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'Profile', isBack: false),
      body: Container(
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
                profile(),
                menu('แก้ไขข้อมูลส่วนตัว', () {
                  context.push('/edit-profile-user');
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
                  _showQrDialog(context);
                }),
              ],
            ),
            Column(
              children: [
                menu('สมัครเป็นผู้จัด', () {
                  // context.push('/apply-organizer');
                  context.read<UserRoleProvider>().setRole(Role.organizer);
                  context.push('/profile-organizer');
                }),
                menu('ลบ Account', path: 'assets/icon/delete.png', () {
                  if (overdue) {
                    showDialogMsg(
                      context,
                      title: 'ไม่สามารถลบ Account',
                      subtitle: 'คุณมียอดค้างจ่ายจำนวน 236 บาท',
                      btnLeft: 'จ่ายเงิน',
                      btnRightBackColor: Color(0xFFFFFFFF),
                      btnRightForeColor: Theme.of(context).colorScheme.primary,
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
                  showDialogMsg(
                    context,
                    title: 'ยืนยับการออกจากระบบ',
                    subtitle: '',
                    btnLeft: 'ออกจากระบบ',
                    btnLeftBackColor: Color(0xFF000000),
                    onConfirm: () {
                      setState(() {
                        overdue = !overdue;
                      });
                      showDialogMsg(
                        context,
                        title: 'ออกจากระบบเรียบร้อย',
                        subtitle: '',
                        btnLeft: 'ไปหน้า Log In',
                        onConfirm: () {},
                      );
                    },
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
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
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'somsuay@mail.com',
                    style: TextStyle(fontSize: 10, color: Color(0XFF64646D)),
                  ),
                  Text(
                    '0878067785',
                    style: TextStyle(fontSize: 10, color: Color(0XFF64646D)),
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
