import 'dart:math';

import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/game_card2.dart';
import 'package:badminton/page/organizer/history/history_organizer.dart';
import 'package:badminton/page/user/player_list.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:go_router/go_router.dart';

enum PlayerWidgetPart { header, content }

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  ManagePageState createState() => ManagePageState();
}

class ManagePageState extends State<ManagePage> {
  late List<Player> players;
  bool isUse = true;
  int indexData = 0;
  bool _showDetailsOnMobile = false;

  void _backToListOnMobile() {
    setState(() {
      _showDetailsOnMobile = !_showDetailsOnMobile;
    });
  }

  @override
  void initState() {
    players = _generateMockPlayers(56);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<Player> _generateMockPlayers(int count) {
    return List.generate(count, (i) {
      return Player(
        id: i + 1,
        nickname: 'แก้ว',
        gender: 'หญิง',
        skillLevel: skillLevels.keys.elementAt(
          Random().nextInt(skillLevels.length),
        ),
        imageUrl:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=687&q=80',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBarSubMain(title: 'Manage', isBack: false),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD5DCF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 820) {
              return _buildTabletLayout();
            } else if (constraints.maxWidth > 600) {
              return _buildTabletVerticalLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildbottomBar(String status) {
    switch (status) {
      case 'S':
        return _buildBottomBarS();
      case 'W':
        return _buildBottomBarW();
      case 'WR' || 'C':
        return _buildBottomBar();
      case 'O':
        return _buildBottomBar();
      default:
        return _buildBottomBar();
    }
  }

  _buildBottomBar() {
    return Container(
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: CustomElevatedButton(
              text: 'ยกเลิกก๊วน',
              backgroundColor: Color(0xFFFFFFFF),
              foregroundColor: Color(0xFF0E9D7A),
              fontSize: 11,
              onPressed: () {
                showDialogMsg(
                  context,
                  title: 'ยืนยันการยกเลิกก๊วน',
                  subtitle: 'คุณต้องการยกเลิก ก๊วนแมวเหมียว',
                  isWarning: true,
                  isSlideAction: true,
                  onConfirm: () {
                    showDialogMsg(
                      context,
                      title: 'ยืนยันการยกเลิก',
                      subtitle: 'คุณได้ยกเลิก ก๊วนแมวเหมียว',
                      btnLeft: 'ไปหน้าข้อมูลก๊วน',
                      onConfirm: () {},
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: CustomElevatedButton(
              text: 'แก้ไขข้อมูลก๊วน',
              backgroundColor: Color(0xFF0E9D7A),
              foregroundColor: Color(0xFFFFFFFF),
              fontSize: 11,
              onPressed: () {
                context.push('/add-game/1');
              },
            ),
          ),
        ],
      ),
    );
  }

  _buildBottomBarW() {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: CustomElevatedButton(
              text: 'เปิดก๊วน',
              fontSize: 16,
              onPressed: () {
                showDialogMsg(
                  context,
                  title: 'ยืนยันการเปิดก๊วน',
                  subtitle: 'คุณต้องการเปิด ก๊วนแมวเหมียว',
                  // btnLeft: 'ยกเลิก',
                  btnRight: 'ยกเลิก',
                  btnRightBackColor: Color(0xFFFFFFFF),
                  btnRightForeColor: Color(0xFF0E9D7A),

                  isWarning: true,
                  onConfirm: () {},
                );
              },
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomElevatedButton(
                  text: 'เพิ่มผู้เล่น Walk In',
                  backgroundColor: Color(0xFFFFFFFF),
                  foregroundColor: Color(0xFF0E9D7A),
                  fontSize: 11,
                  onPressed: () {
                    showDialogMsg(
                      context,
                      title: 'ยืนยันการยกเลิกก๊วน',
                      subtitle: 'คุณต้องการยกเลิก ก๊วนแมวเหมียว',
                      isWarning: true,
                      isSlideAction: true,
                      onConfirm: () {
                        showDialogMsg(
                          context,
                          title: 'ยืนยันการยกเลิก',
                          subtitle: 'คุณได้ยกเลิก ก๊วนแมวเหมียว',
                          btnLeft: 'ไปหน้าข้อมูลก๊วน',
                          onConfirm: () {},
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: CustomElevatedButton(
                  text: 'Scan QR code',
                  backgroundColor: Color(0xFF0E9D7A),
                  foregroundColor: Color(0xFFFFFFFF),
                  fontSize: 11,
                  enabled: true,
                  onPressed: () {
                    context.push('/add-game/1');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _buildBottomBarS() {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: CustomElevatedButton(
              text: 'จัดการก๊วน',
              fontSize: 16,
              onPressed: () {
                showDialogMsg(
                  context,
                  title: 'ยืนยันการเปิดก๊วน',
                  subtitle: 'คุณต้องการเปิด ก๊วนแมวเหมียว',
                  // btnLeft: 'ยกเลิก',
                  btnRight: 'ยกเลิก',
                  btnRightBackColor: Color(0xFFFFFFFF),
                  btnRightForeColor: Color(0xFF0E9D7A),

                  isWarning: true,
                  onConfirm: () {
                    context.push('/manage-game/1');
                  },
                );
              },
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomElevatedButton(
                  text: 'เพิ่มผู้เล่น Walk In',
                  backgroundColor: Color(0xFFFFFFFF),
                  foregroundColor: Color(0xFF0E9D7A),
                  fontSize: 11,
                  onPressed: () {
                    showDialogMsg(
                      context,
                      title: 'ยืนยันการยกเลิกก๊วน',
                      subtitle: 'คุณต้องการยกเลิก ก๊วนแมวเหมียว',
                      isWarning: true,
                      isSlideAction: true,
                      onConfirm: () {
                        showDialogMsg(
                          context,
                          title: 'ยืนยันการยกเลิก',
                          subtitle: 'คุณได้ยกเลิก ก๊วนแมวเหมียว',
                          btnLeft: 'ไปหน้าข้อมูลก๊วน',
                          onConfirm: () {},
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: CustomElevatedButton(
                  text: 'Scan QR code',
                  backgroundColor: Color(0xFF0E9D7A),
                  foregroundColor: Color(0xFFFFFFFF),
                  fontSize: 11,
                  onPressed: () {
                    context.push('/add-game/1');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _buildMobileLayout() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showDetailsOnMobile
          ? detailsView(context, onBack: _backToListOnMobile) // หน้ารายละเอียด
          : Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                child: _buildPlaying(
                  context,
                  title: 'ก๊วนที่กำลังมาถึง',
                  listData: dataList,
                ),
              ),
            ),
    );
  }

  _buildTabletVerticalLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 6, 16),
            child: _buildPlaying(
              context,
              title: 'ก๊วนที่กำลังมาถึง',
              listData: dataList,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 16, 16, 16),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Text(
                    '',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: getResponsiveFontSize(context, fontSize: 20),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: GroupInfoCard(model: dataList[indexData]),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: ImageSlideshow(model: dataList[indexData]),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(child: DetailsCard()),
                SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: _buildbottomBar(dataList[indexData]['status']),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverStickyHeader(
                  // Header จะถูกสร้างจาก _buildPlayer โดยบอกให้สร้างแค่ส่วน header
                  header: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: _buildPlayer(
                      false,
                      partToBuild: PlayerWidgetPart.header,
                    ),
                  ),

                  // Sliver จะถูกสร้างจาก _buildPlayer โดยบอกให้สร้างแค่ส่วน content
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: _buildPlayer(
                        false,
                        partToBuild: PlayerWidgetPart.content,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
            child: _buildPlaying(
              context,
              title: 'ก๊วนที่กำลังมาถึง',
              listData: dataList,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 16, 7, 16),
            child: ListView(
              children: [
                GroupInfoCard(model: dataList[indexData]),
                SizedBox(height: 16),
                ImageSlideshow(model: dataList[indexData]),
                SizedBox(height: 16),
                DetailsCard(),
                SizedBox(height: 16),
                _buildbottomBar(dataList[indexData]['status']),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: _buildPlayer(true),
          ),
        ),
      ],
    );
  }

  Widget detailsView(BuildContext context, {Function()? onBack}) {
    final bool isMobile = onBack != null;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: CustomScrollView(
        slivers: [
          // ปุ่ม Back สำหรับ Mobile
          if (isMobile)
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_back_ios),
                  label: const Text('กลับไปที่รายการ'),
                  onPressed: onBack,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Text(
              '',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: getResponsiveFontSize(context, fontSize: 20),
              ),
            ),
          ),
          SliverToBoxAdapter(child: GroupInfoCard(model: dataList[indexData])),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: ImageSlideshow(model: dataList[indexData])),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: DetailsCard()),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: _buildbottomBar(dataList[indexData]['status']),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverStickyHeader(
            // Header จะถูกสร้างจาก _buildPlayer โดยบอกให้สร้างแค่ส่วน header
            header: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: _buildPlayer(false, partToBuild: PlayerWidgetPart.header),
            ),

            // Sliver จะถูกสร้างจาก _buildPlayer โดยบอกให้สร้างแค่ส่วน content
            sliver: SliverToBoxAdapter(
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: _buildPlayer(
                  false,
                  partToBuild: PlayerWidgetPart.content,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _buildPlaying(
    BuildContext context, {
    String title = '',
    List<dynamic>? listData,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: getResponsiveFontSize(context, fontSize: 20),
          ),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: listData!.length,
            itemBuilder: (context, index) {
              final game = listData[index];
              return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: GameCard2(
                  teamName: game['teamName'],
                  imageUrl: game['imageUrl'],
                  day: game['day'],
                  date: game['date'],
                  time: game['time'],
                  courtName: game['courtName'],
                  location: game['location'],
                  price: game['price'],
                  shuttlecockInfo: game['shuttlecockInfo'],
                  gameInfo: game['gameInfo'],
                  currentPlayers: game['currentPlayers'],
                  maxPlayers: game['maxPlayers'],
                  organizerName: game['organizerName'],
                  organizerImageUrl: game['organizerImageUrl'],
                  isInitiallyBookmarked: game['isInitiallyBookmarked'],
                  onCardTap: () {
                    _backToListOnMobile();
                    setState(() {
                      indexData = index;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  _buildPlayer(bool isVertical, {PlayerWidgetPart? partToBuild}) {
    // Widget ส่วน Header
    final headerWidget = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ผู้เล่นที่ชำระเงินแล้ว',
                  style: TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  textAlign: TextAlign.end,
                  text: TextSpan(
                    text: "ผู้เล่น ",
                    style: TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
                        text: '56',
                        style: TextStyle(
                          color: Color(0xFF0E9D7A),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '/80',
                        style: TextStyle(
                          color: Color(0xFF000000),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!isVertical) _buildPagination(),
        ],
      ),
    );

    // Widget ส่วน Content
    final contentWidget = Column(
      children: [
        _buildHeader(context),
        isVertical
            ? Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    return _buildPlayerRow(players[index]);
                  },
                ),
              )
            : ListView.builder(
                itemCount: players.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return _buildPlayerRow(players[index]);
                },
              ),
        if (isVertical) _buildPagination(),
      ],
    );

    // --- Logic การ return Widget ตาม Parameter ที่ส่งเข้ามา ---
    if (partToBuild == PlayerWidgetPart.header) {
      return headerWidget;
    }
    if (partToBuild == PlayerWidgetPart.content) {
      return contentWidget;
    }

    // ถ้าไม่ได้ระบุ partToBuild (ค่าเป็น null) ให้ return Card เต็มๆ เหมือนเดิม
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Column(
        children: [
          headerWidget,
          isVertical ? Expanded(child: contentWidget) : contentWidget,
        ],
      ),
    );
  }

  // Widget สำหรับ Header ของตาราง
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              'ลำดับ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ชื่อเล่น',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'เพศ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'ระดับมือ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget สำหรับแสดงข้อมูลผู้เล่นแต่ละแถว
  Widget _buildPlayerRow(Player player) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '${player.id}',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(player.imageUrl),
                ),
                const SizedBox(width: 8),
                Text(
                  player.nickname,
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              player.gender,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              player.skillLevel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Expanded(flex: 2, child: _buildSkillLevelDropdown(player)),
        ],
      ),
    );
  }

  // Widget สำหรับ Pagination ด้านล่าง
  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageNumber('ผู้เล่น', isActive: isUse),
          _buildPageNumber('ตัวสำรอง', isActive: !isUse),
        ],
      ),
    );
  }

  Widget _buildPageNumber(String text, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            isUse = !isUse;
          });
        },
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.green : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
