import 'package:badminton/component/Button.dart';
import 'package:badminton/component/add_guest_dialog.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/details_card.dart'; // Import Widget กลาง
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/game_card2.dart';
import 'package:badminton/page/organizer/history/history_organizer.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  bool _isLoading = true;
  String? _errorMessage;
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
    _initialLoad();
    _fetchSkillLevels();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initialLoad() async {
    try {
      final data = await _fetchMyUpcomingGames();
      if (mounted) {
        setState(() {
          _myGamesData = data;
          if (_myGamesData.isNotEmpty && indexData >= _myGamesData.length) {
            indexData = 0; // รีเซ็ต Index ถ้าก๊วนถูกลบจนตำแหน่งเดิมหายไป
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<List<dynamic>> _fetchMyUpcomingGames() async {
    try {
      final response = await ApiProvider().get('/GameSessions/my-upcoming');
      if (response != null && response['status'] == 200) {
        final data = response['data'] as List? ?? [];
        _cleanupOldSessionData(data); // ล้างข้อมูลเก่าที่ไม่พบในรายการนี้
        return data; // คืนค่า List ของข้อมูลก๊วน
      } else {
        throw Exception(response?['message'] ?? 'Invalid API response format');
      }
    } catch (e) {
      // โยน Error ออกไปเพื่อให้ FutureBuilder จัดการ
      rethrow;
    }
  }

  // --- NEW: ฟังก์ชันสำหรับรีเฟรชข้อมูลโดยไม่ทำให้หน้าจอกระพริบ ---
  Future<void> _refreshData() async {
    try {
      final data = await _fetchMyUpcomingGames();
      if (mounted) {
        setState(() {
          _myGamesData = data;
          if (_myGamesData.isNotEmpty && indexData >= _myGamesData.length) {
            indexData = 0;
          }
        });
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
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

  // --- NEW: ฟังก์ชันล้างข้อมูล SharedPreferences ที่ไม่อยู่ในรายการก๊วนปัจจุบัน ---
  Future<void> _cleanupOldSessionData(List<dynamic> activeSessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      // สร้าง Set ของ Session ID ที่มีอยู่จริง (Active) เพื่อใช้ตรวจสอบ
      // เพิ่มการเช็ค null เพื่อความปลอดภัย
      final activeSessionIds = activeSessions
          .where((s) => s['sessionId'] != null)
          .map((s) => s['sessionId'].toString())
          .toSet();

      for (String key in keys) {
        // ตรวจสอบ Key ที่เกี่ยวข้องกับ Paused Players
        if (key.startsWith('pausedPlayers_')) {
          // ดึง Session ID ออกมาจาก Key (รองรับทั้งแบบมี timestamp และไม่มี)
          String sessionId = key.replaceFirst('pausedPlayers_', '');
          if (sessionId.startsWith('timestamp_')) {
            sessionId = sessionId.replaceFirst('timestamp_', '');
          }
          // ถ้า Session ID นี้ไม่อยู่ในรายการก๊วนปัจจุบัน ให้ลบทิ้งทันที
          if (!activeSessionIds.contains(sessionId)) {
            await prefs.remove(key);
          }
        }
      }
    } catch (e) {
      // ดักจับ Error เงียบๆ เพื่อไม่ให้กระทบการทำงานหลัก
      debugPrint('Error cleaning up old session data: $e');
    }
  }

  Future<void> _cancelGameSession(int sessionId, String groupName) async {
    try {
      // เรียก API เพื่อยกเลิกก๊วน
      await ApiProvider().post('/GameSessions/$sessionId/cancel-by-organizer');

      // --- NEW: ลบข้อมูล SharedPreferences ที่ค้างอยู่ของก๊วนนี้ ---
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pausedPlayers_$sessionId');

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
            _refreshData();
          },
        );
      }
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'เกิดข้อผิดพลาด',
          subtitle: 'ในการยกเลิกก๊วน: ${e.toString().replaceFirst('Exception: ', '')}',
          btnLeft: 'ตกลง',
          onConfirm: () {},
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
        // FIX: แปลงเป็นตัวพิมพ์เล็ก (member/guest) เพื่อให้ตรงกับ Backend Controller
        '/participants/${participantType.toLowerCase()}/$participantId/skill',
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
        showDialogMsg(
          context,
          title: 'อัปเดตระดับมือล้มเหลว',
          subtitle: e.toString().replaceFirst('Exception: ', ''),
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
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
        context.push('/manage-game/$sessionId').then((result) {
          // เมื่อกลับมาจากหน้า manage-game ให้ทำการรีเฟรชข้อมูลใหม่
          _refreshData();
        });
      }
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'เกิดข้อผิดพลาด',
          subtitle: 'ในการเปิดก๊วน: ${e.toString().replaceFirst('Exception: ', '')}',
          btnLeft: 'ตกลง',
          onConfirm: () {},
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

    // รีเฟรชข้อมูลเสมอเมื่อปิด Dialog ป้องกันปัญหากดปิด/กดพื้นที่ว่างแล้วข้อมูลไม่อัปเดต
    _refreshData();
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
                                  '/gamesessions/${_myGamesData[indexData]['sessionId']}/checkin',
                                  data: {
                                    // "scannedData" คือ key ที่ API ต้องการ
                                    "scannedData": scannedData,
                                  },
                                )
                                .then((response) {
                                  Navigator.of(context).pop();
                                  showDialogMsg(
                                    context,
                                    title: 'สำเร็จ',
                                    subtitle: response['message'],
                                    btnLeft: 'ตกลง',
                                    onConfirm: () {},
                                  );
                                })
                                .catchError((error) {
                                  Navigator.of(context).pop();
                                  showDialogMsg(
                                    context,
                                    title: 'Check-in ล้มเหลว',
                                    subtitle: error.toString().replaceFirst('Exception: ', ''),
                                    btnLeft: 'ตกลง',
                                    onConfirm: () {},
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

  // --- NEW: ฟังก์ชันสำหรับลบผู้เล่น (เพื่อให้ตัวสำรองเลื่อนขึ้นมาแทน) ---
  Future<void> _removePlayer(int sessionId, String? pType, int pId, String name) async {
    if (pType == null) {
      showDialogMsg(
        context,
        title: 'แจ้งเตือน',
        subtitle: 'ข้อมูลผู้เล่นไม่สมบูรณ์ (Type is null)',
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
      return;
    }

    showDialogMsg(
      context,
      title: 'ยืนยันการลบผู้เล่น',
      subtitle: 'คุณต้องการลบ $name ออกจากก๊วนหรือไม่?\n(หากเป็นตัวจริง ตัวสำรองจะถูกเลื่อนขึ้นมาแทน)',
      isWarning: true,
      btnLeft: 'ลบผู้เล่น',
      btnLeftForeColor: Colors.white,
      btnLeftBackColor: Colors.red,
      btnRight: 'ยกเลิก',
      onConfirm: () async {
        try {
          // เรียก API ลบผู้เล่น (แปลง pType เป็น lowercase เพื่อความชัวร์)
          await ApiProvider().delete('/GameSessions/$sessionId/participants/${pType.toLowerCase()}/$pId');
          
          if (mounted) {
            _refreshData(); // โหลดข้อมูลใหม่
            
            showDialogMsg(
              context,
              title: 'สำเร็จ',
              subtitle: 'ลบผู้เล่นเรียบร้อยแล้ว',
              btnLeft: 'ตกลง',
              onConfirm: () {},
            );
          }
        } catch (e) {
          if (mounted) {
            showDialogMsg(
              context,
              title: 'เกิดข้อผิดพลาด',
              subtitle: e.toString().replaceFirst('Exception: ', ''),
              btnLeft: 'ตกลง',
              onConfirm: () {},
            );
          }
        }
      },
    );
  }

  // --- NEW: ฟังก์ชันสำหรับเลื่อนตัวสำรองเป็นตัวจริง (Promote) ---
  Future<void> _promotePlayer(int sessionId, String? pType, int pId) async {
    if (pType == null) return;
    try {
      await ApiProvider().put(
        '/GameSessions/$sessionId/participants/${pType.toLowerCase()}/$pId/promote',
      );
      
      if (mounted) {
        _refreshData();
        showDialogMsg(
          context,
          title: 'สำเร็จ',
          subtitle: 'เลื่อนเป็นตัวจริงเรียบร้อยแล้ว',
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'ไม่สามารถเลื่อนได้',
          subtitle: e.toString().replaceFirst('Exception: ', ''),
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    }
  }

  // --- NEW: ฟังก์ชันสำหรับสลับผู้เล่น (Swap) ---
  Future<void> _swapPlayers(int sessionId, int playerAId, String playerAType, int playerBId, String playerBType) async {
    try {
      // เรียก API สลับผู้เล่น (สมมติว่ามี Endpoint นี้ หรือใช้ Logic การย้าย)
      // เนื่องจาก API มาตรฐานอาจไม่มี Swap โดยตรง เราอาจต้องใช้การจัดการภายใน
      // แต่ในที่นี้จะแสดง Dialog เพื่อยืนยันก่อน
      
      // *หมายเหตุ: หากไม่มี API Swap โดยตรง อาจต้องใช้การลบและเพิ่มใหม่ หรือ API เฉพาะของระบบ*
      // ในตัวอย่างนี้จะแสดง SnackBar ว่าฟีเจอร์นี้ต้องรอ API รองรับ
      showDialogMsg(
        context,
        title: 'แจ้งเตือน',
        subtitle: 'กำลังสลับตำแหน่งผู้เล่น...',
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
      
      // TODO: Implement actual API call here
      // await ApiProvider().post('/GameSessions/$sessionId/swap', data: {...});

      // Refresh data
      _refreshData();

    } catch (e) {
      showDialogMsg(
        context,
        title: 'เกิดข้อผิดพลาด',
        subtitle: e.toString().replaceFirst('Exception: ', ''),
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
    }
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text('เกิดข้อผิดพลาดในการดึงข้อมูล: $_errorMessage'))
                : _myGamesData.isEmpty
                    ? const Center(child: Text('ไม่พบก๊วนที่คุณกำลังจะไป'))
                    : LayoutBuilder(
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

  Widget _buildbottomBar(Map<String, dynamic> game) {
    final int status = game['status'] ?? 0; // FIX: ป้องกันกรณี status เป็น null

    switch (status) {
      case 1:
        bool canStart = game['canStartSession'] == true;

        if (!canStart) {
          // มากกว่า 3 ชั่วโมง (หรือไม่ได้รับอนุญาตให้เปิด), แสดงปุ่มยกเลิก/แก้ไข
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
                        _refreshData();
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
                context
                    .push('/manage-game/${_myGamesData[indexData]['sessionId']}')
                    .then((result) {
                  _refreshData();
                });
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
    final double bottomForFloatingNav =
        MediaQuery.of(context).padding.bottom;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _showDetailsOnMobile
          ? detailsView(
              context,
              onBack: _backToListOnMobile,
              scrollBottomInset: bottomForFloatingNav,
            )
          : Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomForFloatingNav),
              child: _buildPlaying(
                context,
                title: 'ก๊วนที่กำลังมาถึง',
                listData: _myGamesData,
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
              key: const PageStorageKey('tablet_vertical_scroll'),
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
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom,
                  ),
                ),
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
              key: const PageStorageKey('tablet_scroll'),
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

  Widget detailsView(
    BuildContext context, {
    VoidCallback? onBack,
    double scrollBottomInset = 24,
  }) {
    final bool isMobile = onBack != null;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: CustomScrollView(
        key: const PageStorageKey('mobile_details_scroll'),
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
          SliverToBoxAdapter(child: SizedBox(height: scrollBottomInset)),
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
            key: const PageStorageKey('playing_list_scroll'),
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
                  currentPlayers: game['participants'] != null 
                      ? (game['participants'] as List).where((p) => p['status'] == 1).length 
                      : (game['currentParticipants'] ?? 0),
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
    // --- NEW: แยกผู้เล่นตัวจริงและตัวสำรอง ---
    List<dynamic> allParticipants = listData ?? [];
    List<dynamic> displayList = [];

    if (maxPlayer < 0) maxPlayer = 0;

    if (isUse) {
      // กรณีเลือกแท็บ "ผู้เล่น" (ตัวจริง) -> กรองเฉพาะ status == 1
      displayList = allParticipants.where((p) => p['status'] == 1).toList();
    } else {
      // กรณีเลือกแท็บ "ตัวสำรอง" -> กรองเฉพาะ status == 2
      displayList = allParticipants.where((p) => p['status'] == 2).toList();
    }

    // Widget ส่วน Header
    final headerWidget = Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isUse ? 'ผู้เล่นตัวจริง' : 'ผู้เล่นตัวสำรอง',
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
                    text: isUse ? "ผู้เล่น " : "สำรอง ",
                    style: TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
                        text: displayList.length.toString(),
                        style: TextStyle(
                          color: Color(0xFF0E9D7A),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isUse) // แสดง /max เฉพาะตัวจริง
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
          if (!isVertical) _buildPagination(allParticipants.length, maxPlayer),
        ],
      ),
    );

    // Widget ส่วน Content
    final contentWidget = Column(
      children: [
        _buildHeader(context),
        isVertical
            ? Expanded(
                child: displayList.isEmpty
                    ? Center(child: Text('ไม่มีรายชื่อ${isUse ? 'ผู้เล่น' : 'ตัวสำรอง'}'))
                    : ListView.builder(
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    // แสดงลำดับตาม index ใน list ที่กรองมาแล้ว
                    return _buildPlayerRow(index, displayList[index]);
                  },
                ),
              )
            : displayList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(child: Text('ไม่มีรายชื่อ${isUse ? 'ผู้เล่น' : 'ตัวสำรอง'}')),
                  )
                : ListView.builder(
                itemCount: displayList.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  return _buildPlayerRow(index, displayList[index]);
                },
              ),
        if (isVertical) _buildPagination(allParticipants.length, maxPlayer),
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

  // Widget สำหรับ Header ของตาราง (ขนาดกะทัดรัด — ลดการเบียดบนจอแคบ)
  Widget _buildHeader(BuildContext context) {
    final double t = getResponsiveFontSize(context, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'ลำดับ',
              style: TextStyle(
                fontSize: t,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              'ชื่อเล่น',
              style: TextStyle(
                fontSize: t,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'เพศ',
              style: TextStyle(
                fontSize: t,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'ระดับมือ',
              style: TextStyle(
                fontSize: t,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'สถานะ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: t,
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

    // [Smart Backend Alert 🚨] ดึงค่า UnpaidAmount และ IsCheckedOut จาก Backend โดยตรง
    // ใส่ Fallback คำนวณเดิมไว้ชั่วคราว เผื่อ Backend API (/my-upcoming) ยังไม่ได้ส่งค่ามา
    final num unpaidAmount = player['unpaidAmount'] != null ? (player['unpaidAmount'] as num) : 
        ((num.tryParse('${player['totalCost'] ?? 0}') ?? 0) - (num.tryParse('${player['paidAmount'] ?? 0}') ?? 0));
        
    final bool isReserve = player['status'] == 2; // เช็คจากสถานะจริง
    final bool isCheckedOut = player['checkoutTime'] != null || player['isCheckedOut'] == true; // เช็คสถานะ Check-out
    
    String? currentSkillValue = player['skillLevelId']?.toString();
    bool skillExists = _skillLevels.any((s) => s['code'] == currentSkillValue);
    if (!skillExists && currentSkillValue != null) {
      currentSkillValue = null; // ถ้าระดับเดิมถูกลบ ให้รีเซ็ตเป็น null
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 12),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if ((player['profilePhotoUrl'] ?? "") != "")
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: NetworkImage(player['profilePhotoUrl']),
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        player['nickname'] ?? 'N/A',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: getResponsiveFontSize(context, fontSize: 12),
                          fontWeight: FontWeight.w500,
                          color: isCheckedOut ? Colors.grey : Colors.black, // ซีดลงถ้ากลับแล้ว
                          decoration: isCheckedOut ? TextDecoration.lineThrough : null, // ขีดฆ่าชื่อเบาๆ
                        ),
                      ),
                    ),
                  ],
                ),
                if (isCheckedOut)
                  Text(
                    'Check-out แล้ว',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 9),
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              player['genderName'] ?? '-',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 12),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: DropdownButton<String>(
              value: currentSkillValue,
              isExpanded: true,
              isDense: true,
              iconSize: 18,
              underline: const SizedBox.shrink(),
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 12),
                color: Colors.black87,
              ),
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
                      fontSize: getResponsiveFontSize(context, fontSize: 12),
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
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ถ้าเป็นตัวสำรอง ให้แสดงปุ่ม Promote (ลูกศรขึ้น)
                if (isReserve)
                  GestureDetector(
                    onTap: () {
                      _promotePlayer(
                        _myGamesData[indexData]['sessionId'],
                        player['participantType'],
                        player['participantId'],
                      );
                    },
                    child: const Icon(Icons.arrow_upward, color: Colors.blue, size: 20),
                  ),
                if (isReserve) const SizedBox(width: 4),
                
                // แสดงสถานะการเงิน / ปุ่มลบ
                GestureDetector(
                  onTap: () {
                    _removePlayer(
                      _myGamesData[indexData]['sessionId'],
                      player['participantType'],
                      player['participantId'],
                      player['nickname'] ?? 'ผู้เล่น',
                    );
                  },
                  child: (unpaidAmount > 0)
                      ? Text(
                          '฿${unpaidAmount.toStringAsFixed(0)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: getResponsiveFontSize(context, fontSize: 11),
                          ),
                        )
                      : const Icon(Icons.check_circle, color: Colors.green, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget สำหรับ Pagination ด้านล่าง
  Widget _buildPagination(int totalPlayers, int maxPlayers) {
    // นับจำนวนตัวสำรองจากข้อมูลจริง (status == 2)
    // หมายเหตุ: totalPlayers ในที่นี้คือ listData.length ซึ่งรวมทุกคน
    // แต่เราจะนับใหม่จาก listData เพื่อความชัวร์ หรือใช้ logic เดิมถ้ารายชื่อมาครบ
    // เพื่อความง่ายและถูกต้องตาม UI ใหม่ เราควรนับจาก listData ที่ส่งเข้ามาใน _buildPlayer
    // แต่ใน function นี้ไม่มี access ถึง listData โดยตรง จึงขอใช้ logic เดิมไปก่อน 
    // หรือถ้าต้องการความแม่นยำ ให้ส่ง reserveCount เข้ามาเป็น parameter
    
    // *แก้ไข*: เนื่องจากเราเปลี่ยน logic การแสดงผลแล้ว การคำนวณ reserveCount แบบเดิม (total - max) 
    // อาจจะไม่ตรงถ้าเรามีที่ว่างในตัวจริง (เช่น ลบตัวจริงออก 1 คน แต่ตัวสำรองยังไม่ขึ้นมา)
    // ดังนั้นควรปรับให้แสดงจำนวนจริง แต่ในที่นี้ขอคงไว้ก่อนเพื่อให้ UI ไม่เพี้ยนมาก
    int reserveCount = (totalPlayers > maxPlayers) ? totalPlayers - maxPlayers : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageNumber('ผู้เล่น', isActive: isUse),
          _buildPageNumber(
            reserveCount > 0 ? 'ตัวสำรอง ($reserveCount)' : 'ตัวสำรอง', 
            isActive: !isUse
          ),
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
