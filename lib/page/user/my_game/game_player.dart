import 'dart:async';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/manage_game_models.dart';
import 'package:badminton/component/player_match_card.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/model/player.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:go_router/go_router.dart';

class GamePlayerPage extends StatefulWidget {
  final String id; // Session ID
  const GamePlayerPage({super.key, required this.id});

  @override
  GamePlayerPageState createState() => GamePlayerPageState();
}

class GamePlayerPageState extends State<GamePlayerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  // --- SignalR & State ---
  HubConnection? _hubConnection;
  bool _isLoading = true;
  int? _myUserId;
  int? _myParticipantId;
  List<dynamic> _allParticipants = [];

  // --- ข้อมูล Live State ---
  Map<String, dynamic> _liveState = {};
  String _groupName = '';
  int _currentParticipants = 0;
  int _maxParticipants = 0;
  bool _isStartGame = false;
  Duration _sessionDuration = Duration.zero;
  Timer? _sessionTimer;
  // --- NEW: Data for Expense Panel ---
  double _shuttlecockFee = 0.0;
  double _courtFee = 0.0;

  // --- ข้อมูลส่วนตัวของผู้เล่น ---
  String _myStatusBaseText = 'รอโหลดข้อมูล...';
  DateTime? _myMatchStartTime; // NEW: เก็บเวลาเริ่มแมตช์ของตัวเอง
  bool _isPlayingInMainCourt = false;
  bool _isPaused = false;
  List<dynamic> _myMatchHistory = [];
  String _totalMinutesPlayed = "0";
  Map<String, dynamic>? _myBillData;

  // FAB Menu
  final GlobalKey _fabKey = GlobalKey();
  OverlayEntry? _fabMenuOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // --- NEW: ผูก Observer เพื่อดักจับสถานะหน้าจอ ---
    _tabController = TabController(length: 2, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    await _fetchMyUserId();
    await _fetchMyParticipantId();
    await _fetchSessionDetails();
    await _fetchLiveState();
    _fetchMyMatchHistory();
    _fetchMyBill();
    _initSignalR();
  }

  Future<void> _fetchMyUserId() async {
    try {
      final res = await ApiProvider().get('/Profiles/me');
      if (mounted) {
        setState(() {
          _myUserId = res['data']['userId'] ?? res['data']['id'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  Future<void> _fetchMyParticipantId() async {
    if (_myUserId == null) return;
    try {
      final res = await ApiProvider().get('/player/gamesessions/${widget.id}');
      if (mounted && res['data'] != null) {
        final participants = res['data']['participants'] as List? ?? [];
        final myIdStr = _myUserId.toString();
        final myParticipantData = participants.firstWhere(
          (p) => p['userId']?.toString() == myIdStr,
          orElse: () => null,
        );
        setState(() {
          _allParticipants = participants;
          if (myParticipantData != null) {
            _myParticipantId = myParticipantData['participantId'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching participant ID: $e');
    }
  }

  Future<void> _fetchSessionDetails() async {
    try {
      final res = await ApiProvider().get('/GameSessions/${widget.id}');
      if (mounted && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _maxParticipants = data['maxParticipants'] ?? 0;
          // NOTE: This assumes 'shuttlecockFeePerPerson' is the per-game fee.
          _shuttlecockFee = (data['shuttlecockFeePerPerson'] ?? 0.0).toDouble();
          _courtFee = (data['courtFeePerPerson'] ?? 0.0).toDouble();
        });
      }
    } catch (e) {}
  }

  String _formatTotalMinutes(String minutesStr) {
    int total = int.tryParse(minutesStr) ?? 0;
    if (total == 0) return "0 นาที";
    int h = total ~/ 60;
    int m = total % 60;
    if (h > 0 && m > 0) return "$h ชม. $m นาที";
    if (h > 0) return "$h ชม.";
    return "$m นาที";
  }

  Future<void> _fetchMyMatchHistory() async {
    if (_myUserId == null) return;
    try {
      // ดึงสถิติของตัวเอง
      final res = await ApiProvider().get(
        '/player/gamesessions/${widget.id}/my-stats',
      );
      if (mounted && res['data'] != null) {
        setState(() {
          // หาข้อมูลของตัวเองจากรายชื่อทั้งหมดเพื่อนำไปแสดงรูป
          final myInfo = _allParticipants.firstWhere(
            (p) => p['userId']?.toString() == _myUserId.toString(),
            orElse: () => null,
          );

          _totalMinutesPlayed = res['data']['totalMinutesPlayed']?.toString() ?? "0";

          List<dynamic> history = res['data']['matchHistory'] ?? [];
          for (var match in history) {
            if (match['teammate'] != null) {
              match['teammate'] = _getFullParticipant(match['teammate']);
            }
            if (match['opponents'] != null && match['opponents'] is List) {
              match['opponents'] = (match['opponents'] as List)
                  .map((o) => _getFullParticipant(o))
                  .toList();
            }

            // ประกอบร่างข้อมูลตัวเองใส่เข้าไปใน match เพื่อให้ Widget การ์ดนำรูปไปแสดงผลได้
            if (myInfo != null) {
              match['me'] = myInfo;
              match['myTeam'] = [
                myInfo,
                if (match['teammate'] != null && match['teammate']['nickname'] != 'N/A') match['teammate']
              ];
            }
          }
          _myMatchHistory = history;
        });
      }
    } catch (e) {}
  }

  Future<void> _fetchMyBill() async {
    if (_myUserId == null) return;
    try {
      final res = await ApiProvider().get(
        '/player/gamesessions/${widget.id}/my-bill',
      );
      if (mounted) setState(() => _myBillData = res['data']);
    } catch (e) {}
  }

  Future<void> _initSignalR() async {
    _hubConnection = ApiProvider().createHubConnection('/managementGameHub');

    _hubConnection!.on("ReceiveLiveStateUpdate", (arguments) {
      if (arguments != null && arguments.isNotEmpty && arguments[0] is Map) {
        _processLiveStateData(Map<String, dynamic>.from(arguments[0] as Map));
        _fetchMyMatchHistory(); // อัปเดตประวัติเกมเผื่อเพิ่งตีเสร็จ
      }
    });

    // --- NEW: ดักจับตอนผู้จัดกดยืนยันรับเงิน (Checkout) เพื่อเตะผู้เล่นไปหน้าประวัติ ---
    _hubConnection!.on("PlayerCheckedOut", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        int checkedOutUserId = int.tryParse(arguments[0].toString()) ?? 0;
        if (_myUserId != null && checkedOutUserId == _myUserId) {
          if (mounted) {
            showDialogMsg(
              context,
              title: 'เช็คเอาท์สำเร็จ',
              subtitle: 'ผู้จัดยืนยันการรับชำระเงินเรียบร้อยแล้ว\nระบบจะพาคุณไปยังหน้าประวัติ',
              btnLeft: 'ตกลง',
              btnLeftBackColor: const Color(0xFF0E9D7A),
              onConfirm: () {
                context.pushReplacement('/history-detail/${widget.id}');
              },
            );
          }
        }
      }
    });

    try {
      await _hubConnection!.start();
      await _hubConnection!.invoke("JoinSessionGroup", args: [widget.id]);
    } catch (e) {
      debugPrint("SignalR Error: $e");
    }
  }

  Future<void> _fetchLiveState() async {
    try {
      final response = await ApiProvider().get(
        '/player/gamesessions/${widget.id}/live-state',
      );
      if (response['data'] != null) {
        _processLiveStateData(response['data']);
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processLiveStateData(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      _liveState = data;
      _groupName = data['groupName'] ?? '';

      // จัดการเวลา
      if (data['competitionStartTime'] != null) {
        _isStartGame = true;
        final startTime = DateTime.parse(data['competitionStartTime']);
        _sessionDuration = DateTime.now().difference(startTime);
        if (_sessionTimer == null || !_sessionTimer!.isActive)
          _startSessionTimer();
      } else {
        _isStartGame = false;
        _sessionDuration = Duration.zero;
        _sessionTimer?.cancel();
        _sessionTimer = null;
      }

      // ค้นหาสถานะของตัวเอง
      _updateMyStatus(data);
    });
  }

  void _updateMyStatus(Map<String, dynamic> data) {
    if (_myUserId == null) return;
    _myStatusBaseText = 'รอจัดลงสนาม';
    _myMatchStartTime = null;
    _isPlayingInMainCourt = false; // Reset this flag

    // คำนวณจำนวนผู้เข้าร่วมทั้งหมดจากทุกส่วน
    final courts = data['courts'] as List? ?? [];
    final stagedMatches = data['stagedMatches'] as List? ?? [];
    final waitingPool = data['waitingPool'] as List? ?? [];
    final allPlayerIds = <String>{};
    courts.forEach(
      (c) => (c['currentMatch']?['teamA'] as List? ?? []).forEach(
        (p) => allPlayerIds.add("p_${p['userId'] ?? p['walkinId']}"),
      ),
    );
    courts.forEach(
      (c) => (c['currentMatch']?['teamB'] as List? ?? []).forEach(
        (p) => allPlayerIds.add("p_${p['userId'] ?? p['walkinId']}"),
      ),
    );
    stagedMatches.forEach(
      (m) => (m['teamA'] as List? ?? []).forEach(
        (p) => allPlayerIds.add("p_${p['userId'] ?? p['walkinId']}"),
      ),
    );
    stagedMatches.forEach(
      (m) => (m['teamB'] as List? ?? []).forEach(
        (p) => allPlayerIds.add("p_${p['userId'] ?? p['walkinId']}"),
      ),
    );
    waitingPool.forEach((p) => allPlayerIds.add("w_${p['participantId']}"));
    _currentParticipants = allPlayerIds.length;

    for (var court in courts) {
      final match = court['currentMatch'];
      if (match != null) {
        final teamA = match['teamA'] as List? ?? [];
        final teamB = match['teamB'] as List? ?? [];

        bool inTeamA = teamA.any(
          (p) => p['userId']?.toString() == _myParticipantId.toString(),
        );
        bool inTeamB = teamB.any(
          (p) => p['userId']?.toString() == _myParticipantId.toString(),
        );

        if (inTeamA || inTeamB) {
          final courtId =
              court['courtIdentifier'] ?? court['courtNumber'] ?? '-';
          List<dynamic> myTeam = inTeamA ? teamA : teamB;
          List<dynamic> opponents = inTeamA ? teamB : teamA;

          String myTeammate = myTeam
              .where(
                (p) => p['userId']?.toString() != _myParticipantId.toString(),
              )
              .map((p) => p['nickname'] ?? 'N/A')
              .join(', ');
          String oppNames = opponents
              .map((p) => p['nickname'] ?? 'N/A')
              .join(', ');

          if (match['startTime'] != null) {
            _isPlayingInMainCourt = true;
            try {
              _myMatchStartTime = DateTime.parse(match['startTime']).toLocal();
            } catch (e) {
              _myMatchStartTime = null;
            }
            _myStatusBaseText =
                'กำลังเล่นอยู่: สนาม $courtId\nคู่กับ: ${myTeammate.isEmpty ? '-' : myTeammate}\nVS: ${oppNames.isEmpty ? '-' : oppNames}';
          } else {
            _myMatchStartTime = null;
            _myStatusBaseText =
                'เตรียมลงเล่น: สนาม $courtId\nคู่กับ: ${myTeammate.isEmpty ? '-' : myTeammate}\nVS: ${oppNames.isEmpty ? '-' : oppNames}';
          }
          return;
        }
      }
    }

    for (var match in stagedMatches) {
      final teamA = match['teamA'] as List? ?? [];
      final teamB = match['teamB'] as List? ?? [];

      bool inTeamA = teamA.any(
        (p) => p['userId']?.toString() == _myParticipantId.toString(),
      );
      bool inTeamB = teamB.any(
        (p) => p['userId']?.toString() == _myParticipantId.toString(),
      );

      if (inTeamA || inTeamB) {
        final cId = match['courtIdentifier'] ?? match['courtNumber'];
        List<dynamic> myTeam = inTeamA ? teamA : teamB;
        List<dynamic> opponents = inTeamA ? teamB : teamA;

        String myTeammate = myTeam
            .where(
              (p) => p['userId']?.toString() != _myParticipantId.toString(),
            )
            .map((p) => p['nickname'] ?? 'N/A')
            .join(', ');
        String oppNames = opponents
            .map((p) => p['nickname'] ?? 'N/A')
            .join(', ');

        if (cId != null && cId.toString().startsWith('-')) {
          _myStatusBaseText =
              'อยู่ในคิวสำรอง: ทีมที่ ${cId.toString().substring(1)}\nคู่กับ: ${myTeammate.isEmpty ? '-' : myTeammate}\nVS: ${oppNames.isEmpty ? '-' : oppNames}';
        } else {
          _myStatusBaseText =
              'ถูกจัดทีมแล้ว รอลงสนาม\nคู่กับ: ${myTeammate.isEmpty ? '-' : myTeammate}\nVS: ${oppNames.isEmpty ? '-' : oppNames}';
        }
        return;
      }
    }

    // 4. ถ้าไม่เจอใน_สนามหรือทีมสำรอง ให้เช็ค waiting pool
    bool isInWaitingPool = waitingPool.any(
      (p) => p['participantId']?.toString() == _myParticipantId.toString(),
    );

    if (isInWaitingPool && _isPaused) {
      _myStatusBaseText = 'หยุดพักการแข่งขัน';
      return;
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _sessionDuration += const Duration(seconds: 1);
        _fabMenuOverlay?.markNeedsBuild(); // รีเฟรชเมนูถ้าเปิดอยู่
        
        // รีเฟรชหน้าจอเพื่อให้เวลาแมตช์เดิน
        if (_isPlayingInMainCourt && _myMatchStartTime != null) {
          setState(() {});
        }
      }
    });
  }

  String _formatSessionDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  Future<void> _togglePause() async {
    if (_isPlayingInMainCourt) return;

    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _myStatusBaseText = 'หยุดพักการแข่งขัน';
      }
    });

    try {
      // เรียก API เพื่อส่ง SignalR ไปให้ผู้จัดรับทราบว่าหยุดพัก
      await ApiProvider().post(
        '/player/gamesessions/${widget.id}/toggle-pause',
        data: {"isPaused": _isPaused},
      );

      if (!_isPaused) {
        _fetchLiveState(); // โหลดสถานะใหม่
      }
      _closeFabMenu();
    } catch (e) {
      setState(() {
        _isPaused = !_isPaused; // ถ้ายิง API ไม่ผ่านให้กลับมาสถานะเดิม
      });
      showDialogMsg(
        context,
        title: 'ผิดพลาด',
        subtitle: e.toString().replaceFirst('Exception: ', ''),
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // --- NEW: ยกเลิกการผูก Observer ---
    _tabController.dispose();
    _sessionTimer?.cancel();
    _fabMenuOverlay?.remove();
    _hubConnection?.stop();
    super.dispose();
  }

  // --- NEW: ดักจับเหตุการณ์เมื่อแอปถูกพับหรือจอเปิดขึ้นมาใหม่ ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("App Resumed: กำลังโหลดกระดานและเชื่อมต่อ SignalR ใหม่...");
      
      _fetchLiveState(); // โหลดข้อมูลกระดานล่าสุดเพื่อป้องกันข้อมูลค้าง (Stale Data)
      
      if (_hubConnection?.state == HubConnectionState.Disconnected) {
         _hubConnection?.start(); // ถ้า SignalR ยอมแพ้และหลุดไปแล้ว ให้บังคับต่อใหม่
      }
    }
  }

  // --- FAB MENU ---
  void _toggleFabMenu() {
    if (_fabMenuOverlay == null)
      _openFabMenu();
    else
      _closeFabMenu();
  }

  void _closeFabMenu() {
    _fabMenuOverlay?.remove();
    setState(() => _fabMenuOverlay = null);
  }

  void _openFabMenu() {
    final fabBox = _fabKey.currentContext!.findRenderObject() as RenderBox;
    final fabPosition = fabBox.localToGlobal(Offset.zero);
    final fabSize = fabBox.size;

    _fabMenuOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: GestureDetector(
          onTap: _closeFabMenu,
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned(
                  bottom:
                      MediaQuery.of(context).size.height -
                      fabPosition.dy -
                      fabSize.height,
                  right:
                      MediaQuery.of(context).size.width -
                      fabPosition.dx -
                      fabSize.width,
                  child: _buildFabMenu(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_fabMenuOverlay!);
  }

  Widget _buildFabMenu() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. เข้าร่วมแล้ว (กดไม่ได้)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  const TextSpan(text: 'เข้าร่วมแล้ว '),
                  TextSpan(
                    text: '$_currentParticipants/$_maxParticipants',
                    style: const TextStyle(color: Colors.black),
                  ),
                  const TextSpan(text: ' คน'),
                ],
              ),
            ),
          ),
          // 2. เวลา (กดไม่ได้)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'เวลา ${_formatSessionDuration(_sessionDuration)} น.',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          // 3. ดูค่าใช้จ่าย
          InkWell(
            onTap: () {
              if (_isPlayingInMainCourt) {
                _closeFabMenu();
                showDialogMsg(
                  context,
                  title: 'แจ้งเตือน',
                  subtitle: 'คุณกำลังแข่งขันอยู่ในสนาม\nไม่สามารถชำระเงินเพื่อเช็คเอาท์ได้ในขณะนี้',
                  btnLeft: 'ตกลง',
                  onConfirm: () {},
                );
                return;
              }
              _closeFabMenu();
              context.push('/payment-now/${widget.id}');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
              child: Text(
                'ดูค่าใช้จ่าย',
                style: TextStyle(
                  fontSize: 16, color: _isPlayingInMainCourt ? Colors.grey : Colors.green, fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // 4. หยุดการแข่งขัน
          InkWell(
            onTap: _isPlayingInMainCourt ? null : _togglePause,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 24.0,
              ),
              child: Text(
                _isPaused ? 'กลับสู่การแข่งขัน' : 'หยุดการแข่งขัน',
                style: TextStyle(
                  fontSize: 16,
                  color: _isPlayingInMainCourt ? Colors.grey : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBarSubMain(title: 'กำลังโหลด...'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.grey[100],
      appBar: AppBarSubMain(title: 'ก๊วน: $_groupName'),
      body: Column(
        children: [
          // --- Tab Bar ---
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'สถานะของฉัน'),
                Tab(text: 'ดูสนามทั้งหมด'),
              ],
            ),
          ),
          // --- Tab Content ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Stack(
                  children: [
                    _buildMyStatusTab(),
                  ],
                ),
                _buildAllCourtsTab()
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Builder(
        key: _fabKey,
        builder: (context) => FloatingActionButton(
          onPressed: _toggleFabMenu,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.menu, color: Colors.white),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: สถานะของฉัน
  // ==========================================
  Widget _buildMyStatusTab() {
    String statusDisplay = _myStatusBaseText;
    if (_isPlayingInMainCourt && _myMatchStartTime != null) {
      final diff = DateTime.now().difference(_myMatchStartTime!);
      String mins = diff.inMinutes.toString().padLeft(2, '0');
      String secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
      statusDisplay += '\nเวลาที่เล่น: $mins:$secs นาที';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // การ์ดบอกสถานะปัจจุบัน
        Card(
          color: _isPaused ? Colors.red[50] : Colors.teal[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'สถานะปัจจุบัน',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  statusDisplay,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _isPaused ? Colors.red : Colors.teal[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'เกมส์ทั้งหมดที่เล่นแล้ว',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'เวลาเล่นรวม: ${_formatTotalMinutes(_totalMinutesPlayed)}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_myMatchHistory.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('คุณยังไม่ได้เล่นเกมใดๆ'),
            ),
          )
        else
          // แสดงเกมล่าสุดไว้ด้านบนสุด
          ..._myMatchHistory.reversed.toList().asMap().entries.map((entry) {
            return PlayerMatchCard(
              match: entry.value,
              index: _myMatchHistory.length - entry.key,
            );
          }).toList(),
      ],
    );
  }

  // ==========================================
  // TAB 2: ดูสนามทั้งหมด (Read Only)
  // ==========================================
  Widget _buildAllCourtsTab() {
    final courts = _liveState['courts'] as List? ?? [];
    final stagedMatches = _liveState['stagedMatches'] as List? ?? [];
    final waitingPool = _liveState['waitingPool'] as List? ?? [];

    // กรองเฉพาะทีมสำรอง (Identifier เริ่มด้วย - หรือเป็น null)
    final reserveTeams = stagedMatches.where((m) {
      final cId = m['courtIdentifier']?.toString();
      return cId == null || cId.startsWith('-');
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'สนามทั้งหมด',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: courts.length,
            itemBuilder: (context, index) {
              final court = courts[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 210,
                  child: _buildReadOnlyCourtCard(court),
                ),
              );
            },
          ),
        ),
        if (reserveTeams.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'ทีมสำรอง',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: reserveTeams.length,
              itemBuilder: (context, index) {
                final reserve = reserveTeams[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 210,
                    child: _buildReadOnlyCourtCard(reserve, isReserve: true, index: index),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'ผู้เล่นที่รอ (${waitingPool.length} คน)',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: waitingPool.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'ไม่มีผู้เล่นที่รอคิว',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.start,
                  children: waitingPool
                      .map(
                        (p) => _buildReadOnlyPlayerAvatar(
                          _getFullParticipant(p),
                          isDarkBackground: false,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  // FIX: ทำให้ Function นี้ Robust ขึ้นโดยการเช็คทั้ง userId และ participantId
  dynamic _getFullParticipant(dynamic player) {
    if (player == null) {
      return null;
    }
    
    final participantId = player['participantId']?.toString();
    final userId = player['userId']?.toString();
    final walkinId = player['walkinId']?.toString();

    if (participantId == null && userId == null && walkinId == null) {
      return player;
    }

    final fullParticipant = _allParticipants.firstWhere(
        (p) {
          final pId = p['participantId']?.toString();
          final uId = p['userId']?.toString();
          final wId = p['walkinId']?.toString();
          
          // เนื่องจาก API มีการส่ง participantId กลับมาในฟิลด์ userId 
          if (participantId != null && (pId == participantId || uId == participantId)) return true;
          if (userId != null && (pId == userId || uId == userId)) return true;
          if (walkinId != null && (wId == walkinId || pId == walkinId)) return true;
          
          return false;
        },
        orElse: () => null);
        
    if (fullParticipant != null) {
      final merged = Map<String, dynamic>.from(player as Map);
      merged.addAll(Map<String, dynamic>.from(fullParticipant as Map));
      merged['profilePhotoUrl'] = fullParticipant['profilePhotoUrl'] ?? player['profilePhotoUrl'];
      return merged;
    }
    return player;
  }

  Widget _buildReadOnlyCourtCard(dynamic data, {bool isReserve = false, int index = 0}) {
    final match = isReserve ? data : data['currentMatch'];
    final isPlaying = !isReserve && match != null && match['startTime'] != null;

    List<dynamic> teamA = match != null ? match['teamA'] : [];
    List<dynamic> teamB = match != null ? match['teamB'] : [];

    String titleText;
    if (isReserve) {
      final cId = data['courtIdentifier']?.toString();
      if (cId != null && cId.startsWith('-')) {
        titleText = 'ทีมสำรอง ${cId.substring(1)}';
      } else {
        titleText = 'ทีมสำรอง ${index + 1}';
      }
    } else {
      titleText = 'สนาม ${data['courtIdentifier'] ?? data['courtNumber'] ?? '-'}';
    }

    final Color topColor = isReserve ? Colors.blueGrey[800]! : const Color(0xFF2E9A8A);
    final Color bottomColor = isReserve ? Colors.blueGrey[700]! : const Color(0xFF2A3A8A);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ครึ่งบน
          Expanded(
            child: Container(
              color: topColor,
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildReadOnlyPlayerSlot(
                      _getFullParticipant(teamA.isNotEmpty ? teamA[0] : null)),
                  _buildReadOnlyPlayerSlot(
                      _getFullParticipant(teamA.length > 1 ? teamA[1] : null)),
                ],
              ),
            ),
          ),
          // ครึ่งล่าง
          Expanded(
            child: Container(
              color: bottomColor,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildReadOnlyPlayerSlot(_getFullParticipant(
                            teamB.isNotEmpty ? teamB[0] : null)),
                        _buildReadOnlyPlayerSlot(_getFullParticipant(
                            teamB.length > 1 ? teamB[1] : null)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      isReserve
                          ? const Text(
                              'รอลงสนาม',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            )
                          : (isPlaying && match['startTime'] != null)
                              ? ReadOnlyCourtTimerWidget(
                                  startTime: DateTime.parse(match['startTime']).toLocal(),
                                )
                              : const Text(
                                  'รอกดเริ่ม',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                      Text(
                        titleText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyPlayerSlot(dynamic player) {
    if (player == null) {
      return Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }
    return _buildReadOnlyPlayerAvatar(
      player,
      isSmall: true,
      isDarkBackground: true,
    );
  }

  Widget _buildReadOnlyPlayerAvatar(
    dynamic player, {
    bool isSmall = false,
    bool isDarkBackground = false,
  }) {
    final String name = player['nickname'] ?? '-';
    final String? img = player['profilePhotoUrl'];
    final String level = player['skillLevelName'] ?? '-';

    final textColor = isDarkBackground ? Colors.white : Colors.black87;
    final subTextColor = isDarkBackground ? Colors.white70 : Colors.grey[600];

    return SizedBox(
      width: isSmall ? 60 : 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: isSmall ? 20 : 30,
            backgroundColor: isDarkBackground
                ? Colors.black26
                : Colors.grey[200],
            backgroundImage: img != null && img.isNotEmpty
                ? NetworkImage(img)
                : null,
            child: img == null || img.isEmpty
                ? Icon(
                    Icons.person,
                    color: isDarkBackground ? Colors.white70 : Colors.grey[600],
                  )
                : null,
          ),

          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isSmall ? 10 : 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          if (!isSmall)
            Text(level, style: TextStyle(fontSize: 10, color: subTextColor)),
        ],
      ),
    );
  }
}

// --- NEW: Widget สำหรับนับเวลาในสนามแบบ Read-Only ---
class ReadOnlyCourtTimerWidget extends StatefulWidget {
  final DateTime startTime;
  const ReadOnlyCourtTimerWidget({super.key, required this.startTime});

  @override
  State<ReadOnlyCourtTimerWidget> createState() => _ReadOnlyCourtTimerWidgetState();
}

class _ReadOnlyCourtTimerWidgetState extends State<ReadOnlyCourtTimerWidget> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.startTime);
        if (_elapsed.isNegative) _elapsed = Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'กำลังเล่น (${_formatDuration(_elapsed)})',
      style: const TextStyle(
        color: Colors.greenAccent,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
