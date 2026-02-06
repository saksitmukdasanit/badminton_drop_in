import 'package:badminton/component/Button.dart';
import 'package:badminton/component/add_guest_dialog.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/game_card2.dart';
import 'package:badminton/page/organizer/history/history_organizer.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum PlayerWidgetPart { header, content }

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  ManagePageState createState() => ManagePageState();
}

class ManagePageState extends State<ManagePage> {
  bool isUse = true;
  int indexData = 0;
  bool _showDetailsOnMobile = false;

  late Future<List<dynamic>> _futureMyGames;
  List<dynamic> _myGamesData = [];
  List<dynamic> _skillLevels = [];
  final Map<int, bool> _updatingSkill =
      {}; // Map to track loading state for each player

  void _backToListOnMobile() {
    setState(() {
      _showDetailsOnMobile = !_showDetailsOnMobile;
    });
  }

  @override
  void initState() {
    _futureMyGames = _fetchMyUpcomingGames();
    _fetchSkillLevels();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<List<dynamic>> _fetchMyUpcomingGames() async {
    try {
      final response = await ApiProvider().get('/GameSessions/my-upcoming');
      if (response != null && response['data'] is List) {
        return response['data']; // คืนค่า List ของข้อมูลก๊วน
      } else {
        throw Exception('Invalid API response format');
      }
    } catch (e) {
      // โยน Error ออกไปเพื่อให้ FutureBuilder จัดการ
      rethrow;
    }
  }

  Future<void> _fetchSkillLevels() async {
    try {
      final response = await ApiProvider().get('/organizer/skill-levels');
      if (mounted && response['data'] is List) {
        setState(() {
          _skillLevels = (response['data'] as List).map((level) {
            return {
              "code": level['skillLevelId'].toString(),
              "value": level['levelName'],
            };
          }).toList();
        });
      }
    } catch (e) {
      // Handle error silently or show a snackbar
    }
  }

  Future<void> _cancelGameSession(int sessionId, String groupName) async {
    try {
      // เรียก API เพื่อยกเลิกก๊วน
      await ApiProvider().post('/GameSessions/$sessionId/cancel-by-organizer');

      // หากสำเร็จ แสดง Dialog แจ้งเตือนและอัปเดตข้อมูล
      if (mounted) {
        showDialogMsg(
          context,
          title: 'ยกเลิกก๊วนสำเร็จ',
          subtitle: 'คุณได้ยกเลิก $groupName เรียบร้อยแล้ว',
          btnLeft: 'ตกลง',
          onConfirm: () {
            context.pop(); // ปิด Dialog
            // โหลดข้อมูลก๊วนใหม่
            setState(() {
              _futureMyGames = _fetchMyUpcomingGames();
            });
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการยกเลิกก๊วน: $e')),
        );
      }
    }
  }

  Future<void> _updateSkillLevel(
    int sessionId,
    String participantType,
    int participantId,
    String newSkillLevelId,
  ) async {
    setState(() {
      _updatingSkill[participantId] = true;
    });
    try {
      await ApiProvider().put(
        // --- UPDATED: เปลี่ยน Endpoint ตามที่ร้องขอ ---
        '/GameSessions/$sessionId/participants/$participantType/$participantId/skill-level',
        data: {'skillLevelId': int.parse(newSkillLevelId)},
      );

      // --- CHANGED: อัปเดตข้อมูลใน State โดยตรง แทนการโหลดใหม่ทั้งหมด ---
      if (mounted) {
        setState(() {
          // 1. ค้นหาเกมที่กำลังดูอยู่
          final gameIndex = _myGamesData.indexWhere(
            (g) => g['sessionId'] == sessionId,
          );
          if (gameIndex != -1) {
            // 2. ค้นหาผู้เล่นในเกมนั้น
            final participants =
                _myGamesData[gameIndex]['participants'] as List;
            final playerIndex = participants.indexWhere(
              (p) => p['participantId'] == participantId,
            );

            if (playerIndex != -1) {
              // 3. อัปเดตข้อมูลของผู้เล่นคนนั้น
              final newSkill = _skillLevels.firstWhere(
                (s) => s['code'] == newSkillLevelId,
              );
              _myGamesData[gameIndex]['participants'][playerIndex]['skillLevelId'] =
                  int.parse(newSkillLevelId);
              _myGamesData[gameIndex]['participants'][playerIndex]['skillLevelName'] =
                  newSkill['value'];
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('อัปเดตระดับมือล้มเหลว: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _updatingSkill.remove(participantId));
      }
    }
  }

  Future<void> _startGameSession(int sessionId) async {
    try {
      // เรียก API เพื่อเริ่มก๊วน
      await ApiProvider().post('/GameSessions/$sessionId/start');

      // หากสำเร็จ วิ่งไปหน้าจัดการก๊วน
      if (mounted) {
        context.push('/manage-game/$sessionId').then((_) {
          // เมื่อกลับมาจากหน้า manage-game ให้ทำการรีเฟรชข้อมูลใหม่
          setState(() {
            _futureMyGames = _fetchMyUpcomingGames();
          });
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเปิดก๊วน: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddGuestDialog(Map<String, dynamic> game) async {
    final int sessionId = game['sessionId'];

    // --- FIX: ป้องกันข้อผิดพลาด type 'String' is not a subtype of type 'num?' ---
    double _parseFee(dynamic value) {
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      } else if (value is num) {
        return value.toDouble();
      }
      return 0.0;
    }

    final double courtFee = _parseFee(game['courtFeePerPerson']);
    final double shuttleFee = _parseFee(game['shuttlecockFeePerPerson']);

    final result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddGuestDialog(
          sessionId: sessionId,
          courtFee: courtFee,
          shuttleFee: shuttleFee,
        );
      },
    );

    if (result == true) {
      setState(() {
        _futureMyGames = _fetchMyUpcomingGames();
      });
    }
  }

   void _showQrScannerDialog() {
    // Controller สำหรับจัดการกล้อง
    final MobileScannerController controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal, // ความเร็วในการตรวจจับ
      facing: CameraFacing.back, // ใช้กล้องหลัง
    );

    bool isScanCompleted = false; // ตัวแปรป้องกันการสแกนซ้ำซ้อน

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 300,
            height: 350,
            child: Column(
              children: [
                // --- Header ของ Dialog ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Scan QR Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // --- พื้นที่แสดงกล้อง ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MobileScanner(
                        controller: controller,
                        // onDetect จะถูกเรียกเมื่อสแกนเจอ QR Code
                        onDetect: (capture) {
                          // ป้องกันการทำงานซ้ำซ้อนถ้าสแกนติดกันเร็วๆ
                          if (isScanCompleted) return;

                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty &&
                              barcodes.first.rawValue != null) {
                            isScanCompleted = true;
                            final String scannedData = barcodes.first.rawValue!;

                            // --- NEW: Call Check-in API ---
                            // --- FIX: แก้ไข Endpoint และ Body ให้ตรงกับ API ---
                            ApiProvider()
                                .post(
                                  '/gamesessions/${_myGamesData[indexData]['id']}/checkin',
                                  data: {
                                    // "scannedData" คือ key ที่ API ต้องการ
                                    "scannedData": scannedData,
                                  },
                                )
                                .then((response) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(response['message']),
                                    ),
                                  );
                                })
                                .catchError((error) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Check-in ล้มเหลว: $error'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      // หยุดการทำงานของกล้องเมื่อ Dialog ถูกปิด
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBarSubMain(title: 'Manage', isBack: false),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD5DCF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        // --- CHANGED: ครอบ LayoutBuilder ด้วย FutureBuilder ---
        child: FutureBuilder<List<dynamic>>(
          future: _futureMyGames,
          builder: (context, snapshot) {
            // --- 1. กรณี: กำลังโหลดข้อมูล ---
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // --- 2. กรณี: เกิด Error ---
            if (snapshot.hasError) {
              return Center(
                child: Text('เกิดข้อผิดพลาดในการดึงข้อมูล: ${snapshot.error}'),
              );
            }

            // --- 3. กรณี: ไม่มีข้อมูล ---
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('ไม่พบก๊วนที่คุณกำลังจะไป'));
            }

            // --- 4. กรณี: มีข้อมูล ---
            // นำข้อมูลที่ได้มาเก็บไว้ใน State
            _myGamesData = snapshot.data!;

            // สร้าง Layout เดิมโดยใช้ข้อมูลที่ดึงมาได้
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 820) {
                  return _buildTabletLayout();
                } else if (constraints.maxWidth > 600) {
                  return _buildTabletVerticalLayout();
                } else {
                  return _buildMobileLayout();
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildbottomBar(Map<String, dynamic> game) {
    final int status = game['status'] ?? 0; // FIX: ป้องกันกรณี status เป็น null

    switch (status) {
      case 1:
        // ถ้า status เป็น 1, ตรวจสอบเวลาที่เหลือ
        final String sessionStartString = game['sessionStart'];
        final DateTime startTime = DateTime.parse(sessionStartString);
        final Duration timeUntilStart = startTime.difference(DateTime.now());

        if (timeUntilStart.inHours > 3) {
          // มากกว่า 3 ชั่วโมง, แสดงปุ่มยกเลิก/แก้ไข
          return _buildBottomBar();
        } else {
          // 3 ชั่วโมงหรือน้อยกว่า, แสดงปุ่มเปิดก๊วน
          return _buildBottomBarW();
        }
      case 2:
        // ถ้า status เป็น 2, แสดงปุ่มจัดการก๊วน
        return _buildBottomBarS();
      case 3:
        return _buildBottomBar();
      case 4:
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
              backgroundColor: Color(0xFF0E9D7A),
              foregroundColor: Color(0xFFFFFFFF),
              fontSize: 11,
              onPressed: () {
                final game = _myGamesData[indexData];
                final sessionId = game['sessionId'];
                final groupName = game['groupName'];

                showDialogMsg(
                  context,
                  title: 'ยืนยันการยกเลิกก๊วน',
                  subtitle: 'คุณต้องการยกเลิก $groupName',
                  isWarning: true,
                  isSlideAction: true,
                  onConfirm: () {
                    _cancelGameSession(sessionId, groupName);
                  },
                );
              },
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: CustomElevatedButton(
              text: 'แก้ไขข้อมูลก๊วน',
              backgroundColor: Color(0xFFFFFFFF),
              foregroundColor: Color(0xFF0E9D7A),

              fontSize: 11,
              onPressed: () {
                context
                    .push('/add-game/${_myGamesData[indexData]['sessionId']}')
                    .then((result) {
                      if (result == true) {
                        // ถ้ามีการแก้ไขข้อมูล ให้โหลดข้อมูลใหม่
                        setState(
                          () => _futureMyGames = _fetchMyUpcomingGames(),
                        );
                      }
                    });
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
                  subtitle:
                      'คุณต้องการเปิดก๊วน "${_myGamesData[indexData]['groupName']}"',
                  // btnLeft: 'ยกเลิก',
                  btnRight: 'ยกเลิก',
                  btnRightBackColor: Color(0xFFFFFFFF),
                  btnRightForeColor: Color(0xFF0E9D7A),
                  isWarning: true,
                  onConfirm: () =>
                      _startGameSession(_myGamesData[indexData]['sessionId']),
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
                    _showAddGuestDialog(_myGamesData[indexData]);
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
                    _showQrScannerDialog();
                    // context
                    //     .push(
                    //       '/add-game/${_myGamesData[indexData]['sessionId']}',
                    //     )
                    //     .then((result) {
                    //       if (result == true) {
                    //         // ถ้ามีการแก้ไขข้อมูล ให้โหลดข้อมูลใหม่
                    //         setState(
                    //           () => _futureMyGames = _fetchMyUpcomingGames(),
                    //         );
                    //       }
                    //     });
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
                context.push(
                  '/manage-game/${_myGamesData[indexData]['sessionId']}',
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
                    _showAddGuestDialog(_myGamesData[indexData]);
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
                    _showQrScannerDialog();
                    // context
                    //     .push(
                    //       '/add-game/${_myGamesData[indexData]['sessionId']}',
                    //     )
                    //     .then((result) {
                    //       if (result == true) {
                    //         // ถ้ามีการแก้ไขข้อมูล ให้โหลดข้อมูลใหม่
                    //         setState(
                    //           () => _futureMyGames = _fetchMyUpcomingGames(),
                    //         );
                    //       }
                    //     });
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
                  listData: _myGamesData,
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
              listData: _myGamesData,
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
                  child: GroupInfoCard(model: _myGamesData[indexData]),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: ImageSlideshow(model: _myGamesData[indexData]),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: DetailsCard(model: _myGamesData[indexData]),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: _buildbottomBar(_myGamesData[indexData]),
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
                      listData: _myGamesData[indexData]['participants'],
                      minPlayer: _myGamesData[indexData]['currentParticipants'],
                      maxPlayer: _myGamesData[indexData]['maxParticipants'],
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
                        listData: _myGamesData[indexData]['participants'],
                        minPlayer:
                            _myGamesData[indexData]['currentParticipants'],
                        maxPlayer: _myGamesData[indexData]['maxParticipants'],
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
              listData: _myGamesData,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 16, 7, 16),
            child: ListView(
              children: [
                GroupInfoCard(model: _myGamesData[indexData]),
                SizedBox(height: 16),
                ImageSlideshow(model: _myGamesData[indexData]),
                SizedBox(height: 16),
                DetailsCard(model: _myGamesData[indexData]),
                SizedBox(height: 16),
                _buildbottomBar(_myGamesData[indexData]),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: _buildPlayer(
              true,
              listData: _myGamesData[indexData]['participants'],
              minPlayer: _myGamesData[indexData]['currentParticipants'],
              maxPlayer: _myGamesData[indexData]['maxParticipants'],
            ),
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
          SliverToBoxAdapter(
            child: GroupInfoCard(model: _myGamesData[indexData]),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: ImageSlideshow(model: _myGamesData[indexData]),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: DetailsCard(model: _myGamesData[indexData]),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildbottomBar(_myGamesData[indexData])),
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
                listData: _myGamesData[indexData]['participants'],
                minPlayer: _myGamesData[indexData]['currentParticipants'],
                maxPlayer: _myGamesData[indexData]['maxParticipants'],
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
                  listData: _myGamesData[indexData]['participants'],
                  minPlayer: _myGamesData[indexData]['currentParticipants'],
                  maxPlayer: _myGamesData[indexData]['maxParticipants'],
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
              final formattedDateTime = formatSessionStart(
                game['sessionStart'],
              );
              return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: GameCard2(
                  teamName: game['groupName'] ?? 'N/A',
                  imageUrl: game['imageUrl'], // Placeholder
                  day: formattedDateTime['day']!,
                  date: '${game['dayOfWeek']} ${game['sessionDate']}',
                  time: '${game['startTime']}-${game['endTime']}',
                  courtName:
                      game['courtName'] ??
                      'N/A', // แสดงชื่อสนาม+ที่อยู่รวมกันไปก่อน
                  location: game['location'], // ไม่มีข้อมูล location แยก
                  price: game['price'], // ไม่มีข้อมูลราคา
                  shuttlecockInfo: game['shuttlecockModelName'],
                  shuttlecockBrand: game['shuttlecockBrandName'],
                  gameInfo: game['gameTypeName'],
                  currentPlayers: game['currentParticipants'] ?? 0,
                  maxPlayers: game['maxParticipants'] ?? 0,
                  organizerName: game['organizerName'], // ไม่มีข้อมูลผู้จัด
                  organizerImageUrl:
                      game['organizerImageUrl'] ?? "", // Placeholder
                  isInitiallyBookmarked: false,
                  // isInitiallyBookmarked: game['isInitiallyBookmarked'],
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

  _buildPlayer(
    bool isVertical, {
    PlayerWidgetPart? partToBuild,
    dynamic listData,
    int minPlayer = 0,
    int maxPlayer = 0,
  }) {
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
                        text: minPlayer.toString(),
                        style: TextStyle(
                          color: Color(0xFF0E9D7A),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '/${maxPlayer.toString()}',
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
                  itemCount: listData.length,
                  itemBuilder: (context, index) {
                    return _buildPlayerRow(index, listData[index]);
                  },
                ),
              )
            : ListView.builder(
                itemCount: listData.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return _buildPlayerRow(index, listData[index]);
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
  Widget _buildPlayerRow(int index, dynamic player) {
    // --- ADDED: ตรวจสอบประเภทของข้อมูล player ---
    // ป้องกัน Error กรณีที่ข้อมูลใน List ไม่ใช่ Map (อาจจะเป็น int หรือ null)
    if (player is! Map<String, dynamic>) {
      return ListTile(title: Text('ข้อมูลผู้เล่นไม่ถูกต้อง #${index + 1}'));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                if ((player['profilePhotoUrl'] ?? "") != "")
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(player['profilePhotoUrl']),
                  ),
                const SizedBox(width: 8),
                Text(
                  player['nickname'],
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              player['genderName'],
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DropdownButton<String>(
              value: player['skillLevelId']?.toString(),
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: _skillLevels.map<DropdownMenuItem<String>>((
                dynamic skill,
              ) {
                return DropdownMenuItem<String>(
                  value: skill['code'],
                  child: Text(
                    skill['value'],
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  final int? sessionId = _myGamesData[indexData]['sessionId'];
                  final String? participantType = player['participantType'];
                  final int? participantId = player['participantId'];
                  if (sessionId != null &&
                      participantType != null &&
                      participantId != null) {
                    _updateSkillLevel(
                      sessionId,
                      participantType,
                      participantId,
                      newValue,
                    );
                  }
                }
              },
            ),
          ),
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
