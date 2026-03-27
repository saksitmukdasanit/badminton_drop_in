import 'dart:async';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/player_match_card.dart';
import 'package:badminton/component/dropdown.dart';
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

class GamePlayerPageState extends State<GamePlayerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // --- SignalR & State ---
  HubConnection? _hubConnection;
  bool _isLoading = true;
  int? _myUserId;
  int? _myParticipantId;
  
  // --- ข้อมูล Live State ---
  Map<String, dynamic> _liveState = {};
  String _groupName = '';
  int _currentParticipants = 0;
  int _maxParticipants = 0;
  bool _isStartGame = false;
  Duration _sessionDuration = Duration.zero;
  Timer? _sessionTimer;
  
  // --- ข้อมูลส่วนตัวของผู้เล่น ---
  String _myCurrentStatus = 'รอโหลดข้อมูล...';
  bool _isPlayingInMainCourt = false;
  bool _isPaused = false;
  List<dynamic> _myMatchHistory = [];
  Map<String, dynamic>? _myBillData;

  // FAB Menu
  final GlobalKey _fabKey = GlobalKey();
  OverlayEntry? _fabMenuOverlay;

  @override
  void initState() {
    super.initState();
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
        if (myParticipantData != null) {
          setState(() {
            _myParticipantId = myParticipantData['participantId'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching participant ID: $e');
    }
  }

  Future<void> _fetchSessionDetails() async {
    try {
      final res = await ApiProvider().get('/GameSessions/${widget.id}');
      if (mounted && res['data'] != null) {
        setState(() {
          _maxParticipants = res['data']['maxParticipants'] ?? 0;
        });
      }
    } catch (e) {}
  }

  Future<void> _fetchMyMatchHistory() async {
    if (_myUserId == null) return;
    try {
      // ดึงสถิติของตัวเอง
      final res = await ApiProvider().get('/player/gamesessions/${widget.id}/my-stats');
      if (mounted && res['data'] != null) {
        setState(() {
          _myMatchHistory = res['data']['matchHistory'] ?? [];
        });
      }
    } catch (e) {}
  }

  Future<void> _fetchMyBill() async {
    if (_myUserId == null) return;
    try {
      final res = await ApiProvider().get('/player/gamesessions/${widget.id}/my-bill');
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

    try {
      await _hubConnection!.start();
      await _hubConnection!.invoke("JoinSessionGroup", args: [widget.id]);
    } catch (e) {
      debugPrint("SignalR Error: $e");
    }
  }

  Future<void> _fetchLiveState() async {
    try {
      final response = await ApiProvider().get('/player/gamesessions/${widget.id}/live-state');
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
        if (_sessionTimer == null || !_sessionTimer!.isActive) _startSessionTimer();
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
    _myCurrentStatus = 'รอจัดลงสนาม';
    _isPlayingInMainCourt = false; // Reset this flag

    // คำนวณจำนวนผู้เข้าร่วมทั้งหมดจากทุกส่วน
    final courts = data['courts'] as List? ?? [];
    final stagedMatches = data['stagedMatches'] as List? ?? [];
    final waitingPool = data['waitingPool'] as List? ?? [];
    final allPlayerIds = <String>{};
    courts.forEach((c) => (c['currentMatch']?['teamA'] as List? ?? []).forEach((p) => allPlayerIds.add("p_${p['userId'] ?? p['walkinId']}")));
    courts.forEach((c) => (c['currentMatch']?['teamB'] as List? ?? []).forEach((p) => allPlayerIds.add("p_${p['userId'] ?? p['walkinId']}")));
    stagedMatches.forEach((m) => (m['teamA'] as List? ?? []).forEach((p) => allPlayerIds.add("p_${p['userId'] ?? p['walkinId']}")));
    stagedMatches.forEach((m) => (m['teamB'] as List? ?? []).forEach((p) => allPlayerIds.add("p_${p['userId'] ?? p['walkinId']}")));
    waitingPool.forEach((p) => allPlayerIds.add("w_${p['participantId']}"));
    _currentParticipants = allPlayerIds.length;

    for (var court in courts) {
      final match = court['currentMatch'];
      if (match != null) {
        final teamA = match['teamA'] as List? ?? [];
        final teamB = match['teamB'] as List? ?? [];
        
        bool inTeamA = teamA.any((p) => p['userId']?.toString() == _myParticipantId.toString());
        bool inTeamB = teamB.any((p) => p['userId']?.toString() == _myParticipantId.toString());

        if (inTeamA || inTeamB) {
           final courtId = court['courtIdentifier'] ?? court['courtNumber'] ?? '-';
           List<dynamic> myTeam = inTeamA ? teamA : teamB;
           List<dynamic> opponents = inTeamA ? teamB : teamA;

           String myTeammate = myTeam.where((p) => p['userId']?.toString() != _myParticipantId.toString()).map((p) => p['nickname'] ?? 'N/A').join(', ');
           String oppNames = opponents.map((p) => p['nickname'] ?? 'N/A').join(', ');

           if (match['startTime'] != null) {
              _isPlayingInMainCourt = true;
              _myCurrentStatus = 'กำลังเล่นอยู่: สนาม $courtId\nคู่กับ: ${myTeammate.isEmpty ? '-' : myTeammate}\nVS: ${oppNames.isEmpty ? '-' : oppNames}';
           } else {
              _myCurrentStatus = 'เตรียมลงเล่น: สนาม $courtId\nคู่กับ: ${myTeammate.isEmpty ? '-' : myTeammate}\nVS: ${oppNames.isEmpty ? '-' : oppNames}';
           }
           return;
        }
      }
    }

    for (var match in stagedMatches) {
      final teamA = match['teamA'] as List? ?? [];
      final teamB = match['teamB'] as List? ?? [];

      bool inTeamA = teamA.any((p) => p['userId']?.toString() == _myParticipantId.toString());
      bool inTeamB = teamB.any((p) => p['userId']?.toString() == _myParticipantId.toString());
      
      if (inTeamA || inTeamB) {
          final cId = match['courtIdentifier'] ?? match['courtNumber'];
          List<dynamic> myTeam = inTeamA ? teamA : teamB;
          List<dynamic> opponents = inTeamA ? teamB : teamA;

          String myTeammate = myTeam.where((p) => p['userId']?.toString() != _myParticipantId.toString()).map((p) => p['nickname'] ?? 'N/A').join(', ');
          String oppNames = opponents.map((p) => p['nickname'] ?? 'N/A').join(', ');

          if (cId != null && cId.toString().startsWith('-')) {
            _myCurrentStatus = 'อยู่ในคิวสำรอง: ทีมที่ ${cId.toString().substring(1)}\nคู่กับ: ${myTeammate.isEmpty ? '-' : myTeammate}\nVS: ${oppNames.isEmpty ? '-' : oppNames}';
          } else {
            _myCurrentStatus = 'ถูกจัดทีมแล้ว รอลงสนาม\nคู่กับ: ${myTeammate.isEmpty ? '-' : myTeammate}\nVS: ${oppNames.isEmpty ? '-' : oppNames}';
          }
          return;
      }
    }

    // 4. ถ้าไม่เจอใน_สนามหรือทีมสำรอง ให้เช็ค waiting pool
    bool isInWaitingPool = waitingPool.any((p) => p['participantId']?.toString() == _myParticipantId.toString());

    if (isInWaitingPool && _isPaused) {
      _myCurrentStatus = 'หยุดพักการแข่งขัน';
      return;
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _sessionDuration += const Duration(seconds: 1);
        _fabMenuOverlay?.markNeedsBuild(); // รีเฟรชเมนูถ้าเปิดอยู่
      }
    });
  }

  String _formatSessionDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  Future<void> _togglePause() async {
    if (_isPlayingInMainCourt) return;
    
    try {
      // สมมติว่ามี API สำหรับขอพัก (หรือเรียกใช้ endpoint ที่มีอยู่)
      // หากไม่มี API นี้ในระบบ ให้ใช้ Local State ไปก่อน
      // await ApiProvider().put('/participants/member/$_myUserId/pause', data: {"isPaused": !_isPaused});
      
      setState(() {
        _isPaused = !_isPaused;
        if (_isPaused) {
           _myCurrentStatus = 'หยุดพักการแข่งขัน';
        } else {
           _fetchLiveState(); // โหลดสถานะใหม่
        }
      });
      _closeFabMenu();
    } catch (e) {
      showDialogMsg(context, title: 'ผิดพลาด', subtitle: e.toString(), btnLeft: 'ตกลง', onConfirm: () {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sessionTimer?.cancel();
    _fabMenuOverlay?.remove();
    _hubConnection?.stop();
    super.dispose();
  }

  // --- FAB MENU ---
  void _toggleFabMenu() {
    if (_fabMenuOverlay == null) _openFabMenu();
    else _closeFabMenu();
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
                  bottom: MediaQuery.of(context).size.height - fabPosition.dy - fabSize.height,
                  right: MediaQuery.of(context).size.width - fabPosition.dx - fabSize.width,
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                children: [
                  const TextSpan(text: 'เข้าร่วมแล้ว '),
                  TextSpan(text: '$_currentParticipants/$_maxParticipants', style: const TextStyle(color: Colors.black)),
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
              style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          // 3. ดูค่าใช้จ่าย
          InkWell(
            onTap: () {
              _closeFabMenu();
              _showExpenseDialog();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
              child: Text('ดูค่าใช้จ่าย', style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ),
          const Divider(height: 1),
          // 4. หยุดการแข่งขัน
          InkWell(
            onTap: _isPlayingInMainCourt ? null : _togglePause,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
              child: Text(
                _isPaused ? 'กลับสู่การแข่งขัน' : 'หยุดการแข่งขัน',
                style: TextStyle(
                  fontSize: 16, 
                  color: _isPlayingInMainCourt ? Colors.grey : Colors.red, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseDialog() {
    // ดึงค่ายอดสุทธิมาแสดง (คำนวณเบื้องต้นจาก _myBillData)
    double totalAmount = 0.0;
    if (_myBillData != null && _myBillData!['lineItems'] != null) {
      for (var item in _myBillData!['lineItems']) {
        totalAmount += (item['amount'] ?? 0).toDouble();
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('รายละเอียดค่าใช้จ่ายของฉัน'),
        content: _myBillData == null
            ? const Text('ไม่พบข้อมูลค่าใช้จ่าย')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...(_myBillData!['lineItems'] as List).map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['description'] ?? '-'),
                          Text('${item['amount']} ฿'),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ยอดรวมทั้งหมด', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('$totalAmount ฿', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  )
                ],
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
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
                _buildMyStatusTab(),
                _buildAllCourtsTab(),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // การ์ดบอกสถานะปัจจุบัน
        Card(
          color: _isPaused ? Colors.red[50] : Colors.teal[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('สถานะปัจจุบัน', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  _myCurrentStatus,
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold, 
                    color: _isPaused ? Colors.red : Colors.teal[800]
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('เกมส์ทั้งหมดที่เล่นแล้ว', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        
        if (_myMatchHistory.isEmpty)
           const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('คุณยังไม่ได้เล่นเกมใดๆ')))
        else
           // แสดงเกมล่าสุดไว้ด้านบนสุด
           ..._myMatchHistory.reversed.toList().asMap().entries.map((entry) {
             return PlayerMatchCard(match: entry.value, index: _myMatchHistory.length - entry.key);
           }).toList(),
      ],
    );
  }


  // ==========================================
  // TAB 2: ดูสนามทั้งหมด (Read Only)
  // ==========================================
  Widget _buildAllCourtsTab() {
    final courts = _liveState['courts'] as List? ?? [];
    final waitingPool = _liveState['waitingPool'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('สนามทั้งหมด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                child: SizedBox(width: 210, child: _buildReadOnlyCourtCard(court)),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text('ผู้เล่นที่รอ (${waitingPool.length} คน)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: waitingPool.map((p) => _buildReadOnlyPlayerAvatar(p)).toList(),
        )
      ],
    );
  }

  Widget _buildReadOnlyCourtCard(dynamic court) {
    final match = court['currentMatch'];
    final isPlaying = match != null && match['startTime'] != null;
    
    List<dynamic> teamA = match != null ? match['teamA'] : [];
    List<dynamic> teamB = match != null ? match['teamB'] : [];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ครึ่งบน
          Expanded(
            child: Container(
              color: const Color(0xFF2E9A8A),
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildReadOnlyPlayerSlot(teamA.isNotEmpty ? teamA[0] : null),
                  _buildReadOnlyPlayerSlot(teamA.length > 1 ? teamA[1] : null),
                ],
              ),
            ),
          ),
          // ครึ่งล่าง
          Expanded(
            child: Container(
              color: const Color(0xFF2A3A8A),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildReadOnlyPlayerSlot(teamB.isNotEmpty ? teamB[0] : null),
                        _buildReadOnlyPlayerSlot(teamB.length > 1 ? teamB[1] : null),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isPlaying ? 'กำลังเล่น' : 'รอกดเริ่ม', style: TextStyle(color: isPlaying ? Colors.greenAccent : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('สนาม ${court['courtIdentifier'] ?? court['courtNumber'] ?? '-'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  )
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
        width: 45, height: 45,
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
      );
    }
    return _buildReadOnlyPlayerAvatar(player, isSmall: true);
  }

  Widget _buildReadOnlyPlayerAvatar(dynamic player, {bool isSmall = false}) {
    final String name = player['nickname'] ?? '-';
    final String? img = player['profilePhotoUrl'];
    final String level = player['skillLevelName'] ?? '-';
    
    return SizedBox(
      width: isSmall ? 60 : 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: isSmall ? 20 : 30,
            backgroundImage: img != null && img.isNotEmpty ? NetworkImage(img) : null,
            child: img == null || img.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(height: 4),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isSmall ? 10 : 12, fontWeight: FontWeight.bold, color: Colors.white)),
          if (!isSmall)
            Text(level, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }
}
