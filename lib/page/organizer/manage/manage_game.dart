import 'dart:async';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/auto_match_settings_sheet.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/add_guest_dialog.dart';
import 'package:badminton/component/court_timer_widget.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/expense_panel.dart';
import 'package:badminton/component/manage_game_models.dart';
import 'package:badminton/component/player_profile_panel.dart';
import 'package:badminton/component/report_panel.dart';
import 'package:badminton/component/roster_management_panel.dart';
import 'package:badminton/model/auto_match_scoring_weights.dart';
import 'package:badminton/model/player.dart';
import 'package:badminton/component/player_avatar.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/share_deep_link.dart';
import 'package:badminton/widget/expense_panel.dart';
import 'package:flutter/material.dart';
import 'package:signalr_netcore/signalr_client.dart'; // 1. Import SignalR
import 'dart:convert'; // สำหรับ json decoding (ถ้าจำเป็น)
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badminton/component/qr_payment_dialog.dart'; // Import ไฟล์กลาง

class ManageGamePage extends StatefulWidget {
  final String id;
  const ManageGamePage({super.key, required this.id});

  @override
  State<ManageGamePage> createState() => _ManageGamePage();
}

class _ManageGamePage extends State<ManageGamePage> with WidgetsBindingObserver {
  // --- 1. STATE MANAGEMENT: ข้อมูลทั้งหมดของหน้าจอ ---
  bool _isLoading = true;
  String _groupName = '';
  List<dynamic> _skillLevels = []; // NEW: เก็บข้อมูลระดับมือทั้งหมด
  List<PlayingCourt> playingCourts = []; // สนามที่กำลังเล่นอยู่
  List<ReadyTeam> reserveTeams = []; // NEW: ทีมสำรองที่จัดไว้ล่วงหน้า
  List<ReadyTeam> readyTeams = [];
  List<Player> waitingPlayers = [];
  List<Player> selectedPlayers = [];
  final Map<int, Timer> _timers = {};
  final GlobalKey _fabKey = GlobalKey(); // Key สำหรับหาตำแหน่งของ FAB
  OverlayEntry? _fabMenuOverlay; // ตัวแปรสำหรับเก็บเมนู Overlay ของเรา
  bool _isRosterPanelVisible = false;
  bool _isReportPanelVisible = false; // NEW: ตัวแปรควบคุมการแสดงผลหน้าดูรายงาน
  // --- REMOVED: Timer? _liveStateTimer; ---
  // --- NEW: SignalR Hub Connection ---
  HubConnection? _hubConnection;

  Player? _viewingPlayer;
  // --- NEW: Debouncer for API calls ---
  // REMOVED: final Map<int, Timer> _teamDebounceTimers = {};

  Player? _playerForExpenses;
  bool _isStartGame = false;
  int _currentParticipants = 0;
  int _maxParticipants = 0;
  double _courtFee = 0.0;
  double _shuttleFee = 0.0;
  bool _isBuffet = false; // NEW: ตัวแปรเก็บรูปแบบการคิดเงิน
  Timer? _sessionTimer;
  Duration _sessionDuration = Duration.zero;
  bool _isQueueMode =
      true; // NEW: ตัวแปรเก็บสถานะโหมดการจัดทีม (Default: จัดตามคิว)
  bool _isSortBySkill = false; // NEW: ตัวแปรเก็บสถานะการเรียงลำดับ
  bool _isMixedMode =
      true; // NEW: ตัวแปรเก็บสถานะโหมดจับคู่ (Default: จัดแบบผสม)
  String? _sessionPublicId; // ลิงก์แชร์ก๊วน (SessionPublicId จาก API)
  AutoMatchScoringWeights _autoMatchWeights =
      AutoMatchScoringWeights.defaults(); // NEW: น้ำหนักสำหรับ Auto Match
  final Map<String, Map<String, dynamic>> _playerExtraData =
      {}; // NEW: เก็บข้อมูลเพิ่มเติม (Games, Time)
  final Set<String> _pausedPlayerIds = {}; // NEW: เก็บ ID ผู้เล่นที่ถูกหยุดเกม
  final Set<String> _endedPlayerIds = {}; // NEW: เก็บ ID ผู้เล่นที่จบเกมแล้ว
  Timer? _waitingTimeRefreshTimer; // NEW: Timer สำหรับอัปเดตเวลาที่รอ
  bool _isProcessing = false; // NEW: ตัวแปรป้องกันการกดปุ่มซ้ำ (Debounce/Lock)
  final Map<String, int> _participantStatusMap = {}; // NEW: เก็บสถานะผู้เล่น (1=Main, 2=Reserve)
  int _reportRefreshKey = 0; // NEW: Key สำหรับบังคับรีเฟรชหน้ารายงาน

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // --- NEW: ผูก Observer เพื่อดักจับสถานะหน้าจอ ---
    _fetchLiveState(); // 2. เรียกข้อมูลครั้งแรกเพื่อแสดงผลทันที
    _fetchSkillLevels(); // NEW: ดึงข้อมูลระดับมือเมื่อเข้าหน้า
    _fetchSessionDetails();
    _loadPreferences(); // NEW: โหลดค่าที่บันทึกไว้
    _initSignalR(); // 3. เริ่มการเชื่อมต่อ SignalR
    _startWaitingTimeTimer(); // NEW: เริ่ม Timer อัปเดตเวลาที่รอ
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // --- NEW: ยกเลิกการผูก Observer ---
    _fabMenuOverlay?.remove(); // ป้องกัน Overlay ค้างเมื่อกด Back ออกจากหน้า
    _timers.forEach((key, timer) => timer.cancel());
    _sessionTimer?.cancel();
    _waitingTimeRefreshTimer?.cancel(); // NEW: ยกเลิก Timer
    // --- REFACTORED: Leave group before stopping the connection ---
    if (_hubConnection != null) {
      // 5. ปิดการเชื่อมต่อ SignalR
      _hubConnection!.stop();
    }
    // REMOVED: _teamDebounceTimers.cancel
    super.dispose();
  }

  // --- NEW: ดักจับเหตุการณ์เมื่อแอปถูกพับหรือจอเปิดขึ้นมาใหม่ ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("App Resumed: กำลังโหลดข้อมูลกระดานใหม่และตรวจสอบ SignalR (Organizer)...");
      _fetchLiveState(showLoading: false); // โหลดข้อมูลกระดานใหม่แบบเงียบๆ
      if (_hubConnection?.state == HubConnectionState.Disconnected) {
        _hubConnection?.start(); // สั่งเชื่อมต่อ SignalR ใหม่
      }
    }
  }

  // NEW: ฟังก์ชันสำหรับเริ่ม Timer อัปเดตเวลาที่รอ
  void _startWaitingTimeTimer() {
    _waitingTimeRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          for (var player in waitingPlayers) {
            final waitingSince = _playerExtraData[player.id]?['waitingSince'] as DateTime?;
            if (waitingSince != null) {
              player.totalPlayTime = DateTime.now().difference(waitingSince);
            }
          }
        });
      }
    });
  }

  // --- NEW: โหลดและบันทึกค่า Preference ---
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // NEW: ใช้ cache prefs ก่อน แล้วค่อย refresh จาก server เบื้องหลัง
    final weights = await AutoMatchScoringWeights.loadFromPrefs();
    if (!mounted) return;
    setState(() {
      _isQueueMode = prefs.getBool('isQueueMode') ?? true;
      _isMixedMode = prefs.getBool('isMixedMode') ?? true;
      _autoMatchWeights = weights;

      final pausedList =
          prefs.getStringList('pausedPlayers_${widget.id}') ?? [];
      _pausedPlayerIds.addAll(pausedList);

      final endedList = prefs.getStringList('endedPlayers_${widget.id}') ?? [];
      _endedPlayerIds.addAll(endedList);

      // NEW: ถ้ายังไม่มี Timestamp ให้สร้างไว้ (สำหรับข้อมูลเก่าหรือเริ่มใหม่)
      if (prefs.getInt('pausedPlayers_timestamp_${widget.id}') == null) {
        prefs.setInt(
          'pausedPlayers_timestamp_${widget.id}',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    });

    // NEW: refresh preset จาก server (sync ข้ามเครื่อง) — ไม่บล็อก UI
    final serverWeights = await AutoMatchScoringWeights.loadFromServer();
    if (!mounted) return;
    if (serverWeights != _autoMatchWeights) {
      setState(() => _autoMatchWeights = serverWeights);
    }
  }

  Future<void> _saveQueueModePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isQueueMode', value);
  }

  Future<void> _saveMixedModePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isMixedMode', value);
  }

  // NEW: เปิด Bottom Sheet ปรับน้ำหนัก Auto Match
  Future<void> _openAutoMatchSettings() async {
    final updated = await AutoMatchSettingsSheet.show(
      context,
      initial: _autoMatchWeights,
    );
    if (updated != null && mounted) {
      setState(() => _autoMatchWeights = updated);
      // sync ขึ้น server (พร้อม cache) — ถ้า offline จะเก็บ prefs ไว้ก่อน
      final saved = updated.isDefault
          ? await AutoMatchScoringWeights.resetOnServer()
          : await updated.saveToServer();
      if (mounted) setState(() => _autoMatchWeights = saved);
    }
  }

  Future<void> _savePausedPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'pausedPlayers_${widget.id}',
      _pausedPlayerIds.toList(),
    );
    // NEW: บันทึกเวลาล่าสุดที่มีการใช้งาน เพื่อใช้ตรวจสอบตอนล้างข้อมูล
    await prefs.setInt(
      'pausedPlayers_timestamp_${widget.id}',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // NEW: บันทึกสถานะจบเกม
  Future<void> _saveEndedPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'endedPlayers_${widget.id}',
      _endedPlayerIds.toList(),
    );
    await prefs.setInt(
      'pausedPlayers_timestamp_${widget.id}',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // NEW: ฟังก์ชันสำหรับดึงข้อมูลระดับมือทั้งหมด
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
      // ไม่ต้องแสดง error ก็ได้ เพราะหน้านี้ยังทำงานต่อได้
    }
  }

  Future<void> _shareSessionInviteLink() async {
    final pid = _sessionPublicId;
    if (pid == null || pid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยังโหลดลิงก์แชร์ไม่ได้ ลองรีเฟรชหน้า')),
        );
      }
      return;
    }
    final link = buildSessionShareLink(pid);
    final name = _groupName.isNotEmpty ? _groupName : 'ก๊วนแบด';
    await SharePlus.instance.share(
      ShareParams(text: 'ชวนมาตีแบด: $name\n$link'),
    );
  }

  Future<void> _fetchSessionDetails() async {
    try {
      final response = await ApiProvider().get('/GameSessions/${widget.id}');
      if (mounted && response['data'] != null) {
        final data = response['data'];
        
        // --- NEW: เก็บสถานะผู้เล่นลง Map ---
        final participants = data['participants'] as List? ?? [];
        _participantStatusMap.clear();
        for (var p in participants) {
           final pid = '${p['participantType']}_${p['participantId']}';
           _participantStatusMap[pid] = p['status'] ?? 1;

           // FIX: อัปเดตจำนวนเกมล่าสุดจาก API Session Details ลงใน Local Data
           // เพื่อให้มั่นใจว่ามีข้อมูลล่าสุดแม้ Live State จะยังไม่อัปเดต
           int serverGames = p['totalGamesPlayed'] ?? 0;
           if (_playerExtraData.containsKey(pid)) {
             final localData = _playerExtraData[pid]!;
             final localGames = localData['games'] as int? ?? 0;
             // ถ้า Server มีค่ามากกว่า (เช่น Refresh หน้าจอมา) ให้ใช้ค่าจาก Server
             if (serverGames > localGames) {
               localData['games'] = serverGames;
             }
           } else {
             // ถ้ายังไม่มีข้อมูลในเครื่อง ให้ใช้ข้อมูลจาก Server เลย
             _playerExtraData[pid] = {
               'games': serverGames,
               'checkinTime': p['checkedInTime'] != null ? DateTime.parse(p['checkedInTime']) : DateTime.now(),
               'waitingSince': p['checkedInTime'] != null ? DateTime.parse(p['checkedInTime']) : DateTime.now(),
             };
           }
        }

        // --- FIX: นับจำนวนผู้เข้าร่วมจากรายชื่อ (นับเฉพาะคนที่สถานะ = 1 คือ Joined) ---
        // final participants = data['participants'] as List? ?? [];
        // final joinedCount = participants.where((p) => p['status'] == 1).length;

        double parseFee(dynamic value) {
          if (value is String) {
            return double.tryParse(value) ?? 0.0;
          } else if (value is num) {
            return value.toDouble();
          }
          return 0.0;
        }

        setState(() {
          _sessionPublicId = data['sessionPublicId']?.toString();
          // _currentParticipants = joinedCount; // ไม่ใช้ค่า Booking แล้ว ใช้ค่า Check-in จาก Live State แทน
          _maxParticipants = data['maxParticipants'] ?? 0;
          _courtFee = parseFee(data['courtFeePerPerson']);
          _shuttleFee = parseFee(data['shuttlecockFeePerPerson']);
          _isBuffet = data['costingMethod'] == 2;

          // FIX: อัปเดตจำนวนเกมของผู้เล่นในหน้าจอทันทีที่มีข้อมูลใหม่จาก API (แก้ปัญหา G: ไม่ตรง)
          void updatePlayerGames(Player? player) {
            if (player != null && _playerExtraData.containsKey(player.id)) {
              final games = _playerExtraData[player.id]!['games'] as int?;
              if (games != null) {
                player.gamesPlayed = games;
              }
            }
          }
          for (var p in waitingPlayers) updatePlayerGames(p);
          for (var c in playingCourts) for (var p in c.players) updatePlayerGames(p);
          for (var t in reserveTeams) for (var p in t.players) updatePlayerGames(p);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  // --- NEW: ฟังก์ชันสำหรับเชื่อมต่อและจัดการ SignalR ---
  Future<void> _initSignalR() async {
    // --- REFACTORED: เรียกใช้ฟังก์ชันกลางจาก ApiProvider ---
    // 1. สร้าง HubConnection จาก ApiProvider
    _hubConnection = ApiProvider().createHubConnection('/managementGameHub');

    // 5. ดักฟัง Event ที่ Server จะส่งมา
    // ชื่อ Event "ReceiveLiveStateUpdate" ต้องตรงกับที่ฝั่ง Server กำหนด
    _hubConnection!.on("ReceiveLiveStateUpdate", (arguments) {
      print("SignalR: Received live state data!");
      if (arguments != null && arguments.isNotEmpty && arguments[0] is Map) {
        // --- REFACTORED: นำข้อมูลที่ Server ส่งมาไปประมวลผลโดยตรง ---
        final liveStateData = Map<String, dynamic>.from(arguments[0] as Map);
        _processLiveStateData(liveStateData);
      }
    });

    // --- NEW: ดักฟัง Event เมื่อผู้เล่นกดหยุด/เริ่มเกมจากแอปตัวเอง ---
    _hubConnection!.on("PlayerPauseStateChanged", (arguments) {
      if (arguments != null && arguments.isNotEmpty && arguments[0] is Map) {
        final data = Map<String, dynamic>.from(arguments[0] as Map);
        final String? playerId = data['playerId']?.toString();
        final bool? isPaused = data['isPaused'] as bool?;

        if (playerId != null && isPaused != null && mounted) {
          setState(() {
            if (isPaused) {
              // 1. ถ้ากำลังอยู่ในสนามหลัก ให้เพิกเฉย ไม่ให้พัก
              bool inMainCourt = playingCourts.any((c) => c.players.any((p) => p?.id == playerId));
              if (inMainCourt) return;

              // 2. ถ้าอยู่ในทีมสำรอง ให้เด้งออกกลับไป Waiting List
              for (var team in reserveTeams) {
                final playerIndex = team.players.indexWhere((p) => p?.id == playerId);
                if (playerIndex != -1) {
                  _removePlayerFromCourt(team, playerIndex);
                  break;
                }
              }

              _pausedPlayerIds.add(playerId);
              selectedPlayers.removeWhere((p) => p.id == playerId);
            } else {
              _pausedPlayerIds.remove(playerId);
            }
          });
          _savePausedPlayers();
        }
      }
    });

    // (Optional) จัดการสถานะการเชื่อมต่อ
    _hubConnection!.onclose(({error}) {
      print("SignalR: Connection Closed: $error");
    });
    _hubConnection!.onreconnecting(({error}) {
      print("SignalR: Reconnecting... $error");
    });
    _hubConnection!.onreconnected(({connectionId}) {
      print("SignalR: Reconnected! ID: $connectionId");
    });

    // 6. เริ่มการเชื่อมต่อ
    try {
      await _hubConnection!.start();
      print("SignalR: Connection started.");
      // 7. หลังจากเชื่อมต่อสำเร็จ ให้บอก Server ว่าเราจะ "ติดตาม" ข้อมูลของก๊วนนี้
      await _hubConnection!.invoke("JoinSessionGroup", args: [widget.id]);
    } catch (e) {
      print("SignalR: Connection failed: $e");
    }
  }

  Future<void> _fetchLiveState({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);
    try {
      final response = await ApiProvider().get(
        '/gamesessions/${widget.id}/live-state',
      );
      if (response['data'] != null) {
        // --- REFACTORED: เรียกใช้ฟังก์ชันประมวลผลกลาง ---
        _processLiveStateData(response['data']);
      }
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'Error',
          subtitle: 'Error fetching live state: ${e.toString().replaceFirst('Exception: ', '')}',
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } finally {
      if (showLoading && mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW: ฟังก์ชันกลางสำหรับประมวลผลข้อมูล Live State ---
  void _processLiveStateData(Map<String, dynamic> liveState) {
    if (!mounted) return;

    // --- NEW: อัปเดตข้อมูลสถานะผู้เล่น (Status) ให้เป็นปัจจุบันเสมอ ---
    // เรียก API นี้ทุกครั้งที่มีการอัปเดต Live State เพื่อให้มั่นใจว่า _participantStatusMap ถูกต้อง
    _fetchSessionDetails();

    // --- FIX: หยุด Timer เก่าทั้งหมดก่อนที่จะสร้างใหม่ ---
    _timers.forEach((_, timer) => timer.cancel());

    // 1. แปลงข้อมูล WaitingPool
    final List<Player> newWaitingPlayers = [];
    final Map<String, Player> playerMap =
        {}; // NEW: Map เพื่อ lookup ข้อมูลผู้เล่นที่ถูกต้อง (ชื่อไม่เพี้ยน)

    // --- MERGED LOOP: รวมการวนลูปเพื่อประสิทธิภาพและจัดการเวลา ---
    for (var p in (liveState['waitingPool'] as List)) {
      final player = PlayerFromJson.fromJson(p);
      final pid = player.id;

      // คำนวณเวลาเริ่มรอ (Waiting Since)
      final apiCheckin = p['checkedInTime'] != null
          ? DateTime.parse(p['checkedInTime'])
          : DateTime.now();
      DateTime waitingSince = apiCheckin;
      int gamesPlayed = p['totalGamesPlayed'] ?? 0;


      // อัปเดตข้อมูล Extra Data
      _playerExtraData[pid] = {
        'games': gamesPlayed,
        'checkinTime': apiCheckin,
        'waitingSince': waitingSince, // ใช้ค่าที่ถูกต้องที่สุด
      };

      // อัปเดตเวลาที่แสดงผลใน Object Player ทันที
      player.totalPlayTime = DateTime.now().difference(waitingSince);
      player.gamesPlayed = gamesPlayed; // FIX: อัปเดตค่าลงใน Object Player

      newWaitingPlayers.add(player);
      playerMap[player.id] = player; // เก็บลง Map
    }

    // --- FIX: สร้าง Set ของ ID ผู้เล่นที่รออยู่แล้ว เพื่อป้องกันการเพิ่มซ้ำ ---
    final Set<String> waitingPlayerIds = newWaitingPlayers
        .map((p) => p.id)
        .toSet();

    // --- NEW: อ่านข้อมูล StagedMatches จาก API ---
    final List<dynamic> stagedMatchesFromApi = liveState['stagedMatches'] ?? [];
    final List<StagedMatchDto> stagedMatches = stagedMatchesFromApi
        .map((m) => StagedMatchDto.fromJson(m))
        .toList();

    // 2. แปลงข้อมูล Courts
    final List<CourtStatusDto> courtStatuses = (liveState['courts'] as List)
        .map((c) {
          return CourtStatusDto.fromJson(c);
        })
        .toList();

    // 3. สร้าง playingCourts และ readyTeams ใหม่
    List<PlayingCourt> newPlayingCourts = [];
    List<ReadyTeam> newReadyTeams = [];
    List<ReadyTeam> newReserveTeams = []; // NEW: สร้างทีมสำรองไปพร้อมกัน
    Set<String> playersOnCourts =
        {}; // NEW: เก็บ ID ผู้เล่นที่ลงสนามแล้ว เพื่อป้องกันการเบิ้ล

    // --- FIX: เก็บสถานะทีมสำรองเก่าไว้ก่อน เพื่อรักษาทีมที่ยังจัดไม่เสร็จ ---
    final List<ReadyTeam> oldReserveTeams = List.from(reserveTeams);

    for (var courtStatus in courtStatuses) {
      final court = PlayingCourt(
        courtNumber: int.tryParse(courtStatus.courtIdentifier) ?? 0,
        identifier: courtStatus.courtIdentifier, // FIX: เก็บชื่อสนาม
      );

      // --- FIX: ดึงจำนวนเกมส์ที่เล่นแล้วจาก state เดิมมาใส่ เพื่อไม่ให้รีเซ็ตเป็น 0 ---
      int oldCourtIndex = playingCourts.indexWhere((c) => c.identifier == courtStatus.courtIdentifier);
      if (oldCourtIndex != -1) {
        court.gamesPlayedCount = playingCourts[oldCourtIndex].gamesPlayedCount;
      }

      // --- FIX: สร้าง ReadyTeam ที่คู่กันก่อน แล้วค่อยกำหนดค่า ---
      final newTeam = ReadyTeam(id: newReadyTeams.length + 1);
      newReadyTeams.add(newTeam);

      if (courtStatus.currentMatch != null) {
        final match = courtStatus.currentMatch!;
        court.matchId = match.matchId;

        newTeam.stagedMatchId = match.matchId;

        // --- FIX: ตรวจสอบ startTime เพื่อกำหนดสถานะของสนาม ---
        if (match.startTime != null) {
          // ถ้าเกมเริ่มแล้ว (มี startTime)
          court.status = CourtStatus.playing;
          court.isLocked = true;
          court.elapsedTime = DateTime.now().difference(match.startTime!);

          // เริ่ม Timer ใหม่สำหรับสนามที่กำลังเล่นอยู่
          _timers[court.courtNumber] = Timer.periodic(
            const Duration(seconds: 1),
            (timer) {
              if (mounted) {
                // อัปเดตข้อมูล Model โดยไม่ต้อง setState ทั้งหน้า
                playingCourts
                    .firstWhere((c) => c.courtNumber == court.courtNumber)
                    .elapsedTime += const Duration(
                  seconds: 1,
                );
              }
            },
          );
        } else {
          // ถ้าเกมยังไม่เริ่ม (แค่จัดทีมไว้)
          court.status = CourtStatus.waiting;
          court.isLocked = false; // ยังไม่เริ่มเกม สามารถแก้ไขได้
          court.elapsedTime = Duration.zero;
        }

        // หา Player object จาก newWaitingPlayers หรือสร้างใหม่ถ้าไม่เจอ
        List<Player?> matchPlayers = List.filled(4, null);
        final allTeams = [match.teamA, match.teamB];
        int playerIndex = 0;

        for (var team in allTeams) {
          for (var pInMatch in team) {
            if (playerIndex < 4) {
              final playerId =
                  '${pInMatch.participantType}_${pInMatch.participantId}';

              // FIX: ใช้ข้อมูลจาก playerMap ถ้ามี เพื่อให้ชื่อตรงกันและไม่มี (1)
              Player player;
              if (playerMap.containsKey(playerId)) {
                player = playerMap[playerId]!;
              } else {
                // ใช้ชื่อจาก Backend โดยตรง (รวมถึง (1), (2) ถ้ามี)
                String cleanName = pInMatch.nickname;
                player = Player(
                  id: playerId,
                  name: cleanName, // ใช้ชื่อที่ตัด (1) ออกแล้ว
                  imageUrl: pInMatch.profilePhotoUrl,
                  skillLevelName: pInMatch.skillLevelName,
                  skillLevelColor: pInMatch.skillLevelColor,
                  skillLevelId: pInMatch.skillLevelId,
                  emergencyContactName: pInMatch.emergencyContactName,
                  emergencyContactPhone: pInMatch.emergencyContactPhone,
                );
                playerMap[playerId] = player; // เพิ่มลง Map เผื่อใช้ที่อื่น

                // --- FIX: กู้คืนเวลาที่รอจากข้อมูล Local (ถ้ามี) ---
                if (_playerExtraData.containsKey(playerId)) {
                  final localData = _playerExtraData[playerId]!;
                  final waitingSince = localData['waitingSince'] as DateTime?;
                  if (waitingSince != null) {
                    player.totalPlayTime = DateTime.now().difference(waitingSince);
                  }
                  // FIX: กู้คืนจำนวนเกมที่เล่นจาก Local Data
                  final localGames = localData['games'] as int?;
                  if (localGames != null) {
                    player.gamesPlayed = localGames;
                  }
                }
              }

              matchPlayers[playerIndex] = player;

              if (!waitingPlayerIds.contains(playerId)) {
                // ถ้ายังไม่มีใน Waiting List ให้เพิ่มเข้าไป (ใช้ player ที่ถูกต้องแล้ว)
                newWaitingPlayers.add(player);
                waitingPlayerIds.add(playerId);
              }
              playerIndex++;
            }
          }
        }
        // NEW: เก็บ ID ผู้เล่นในสนามลง Set
        for (var p in matchPlayers) {
          if (p != null) playersOnCourts.add(p.id);
        }
        court.players = matchPlayers;
        // --- FIX: Sync players to the corresponding ReadyTeam as well ---
        // Since we add a newTeam for every court, the index will always match.
        if (newPlayingCourts.length < newReadyTeams.length) {
          newReadyTeams[newPlayingCourts.length].players = List.from(
            matchPlayers,
          );
        }
      }
      newPlayingCourts.add(court);

      // --- FIX: สร้างทีมสำรองใหม่โดยดึงข้อมูลจาก StagedMatches ที่ไม่มี courtIdentifier ---
      final newReserveTeam = ReadyTeam(id: newReserveTeams.length + 1);
      newReserveTeams.add(newReserveTeam);
    }

    // --- FIX: แยกการวนลูป StagedMatches เป็น 2 รอบ เพื่อจัดการลำดับความสำคัญ ---
    // รอบที่ 1: จัดการสนามหลักก่อน (Courts)
    for (var stagedMatch in stagedMatches) {
      final teamPlayers = [...stagedMatch.teamA, ...stagedMatch.teamB];
      final courtId = stagedMatch.courtIdentifier;

      if (courtId != null && !courtId.startsWith('-')) {
        final courtIndex = newPlayingCourts.indexWhere(
          (c) => c.identifier == courtId,
        );
        if (courtIndex != -1) {
          final targetReadyTeam = newReadyTeams[courtIndex];
          targetReadyTeam.stagedMatchId = stagedMatch.stagedMatchId;
          for (int i = 0; i < teamPlayers.length; i++) {
            if (i < targetReadyTeam.players.length) {
              final pDto = teamPlayers[i];
              final playerId = '${pDto.participantType}_${pDto.participantId}';

              // FIX: ใช้ข้อมูลจาก playerMap
              Player player;
              if (playerMap.containsKey(playerId)) {
                player = playerMap[playerId]!;
              } else {
                // NEW: ตัด (1) ออกจากชื่อ
                var pJson = pDto.toPlayerJson();
                player = PlayerFromJson.fromJson(pJson);
                playerMap[playerId] = player;

              }

              targetReadyTeam.players[i] = player;
              newPlayingCourts[courtIndex].players[i] =
                  player; // อัปเดต UI สนามด้วย
              if (!waitingPlayerIds.contains(player.id)) {
                newWaitingPlayers.add(player);
                waitingPlayerIds.add(player.id);
              }
              // NEW: เก็บ ID ผู้เล่นที่รอลงสนาม
              playersOnCourts.add(player.id);
            }
          }
        }
      }
    }

    // รอบที่ 2: จัดการทีมสำรอง (Reserves) - FIX: ปรับปรุง Logic รองรับ Auto Match (null ID)
    final Set<int> filledReserveIndices = {}; // เก็บ Index ที่ถูกใช้งานแล้ว

    // 2.1: ลงทีมที่มี Identifier ชัดเจนก่อน (เช่น -1, -2)
    for (var stagedMatch in stagedMatches) {
      final teamPlayers = [...stagedMatch.teamA, ...stagedMatch.teamB];
      final courtId = stagedMatch.courtIdentifier;

      if (courtId != null && courtId.startsWith('-')) {
        bool isDuplicate = false;
        for (var p in teamPlayers) {
          if (playersOnCourts.contains(
            '${p.participantType}_${p.participantId}',
          )) {
            isDuplicate = true;
            break;
          }
        }
        if (isDuplicate) continue; // ข้ามถ้านักกีฬาลงสนามไปแล้ว

        // FIX: ถ้าไม่มีผู้เล่นในทีมเลย (Ghost Match) ให้ข้ามไป เพื่อไม่ให้กันที่ Auto Match
        if (teamPlayers.isEmpty) continue;

        final reserveIndex = int.tryParse(courtId.substring(1)) ?? 0;

        // FIX: ขยายขนาดทีมสำรองให้เพียงพอสำหรับ index ที่ส่งมา (กรณี Auto Match ลง index ไกลๆ)
        while (newReserveTeams.length < reserveIndex) {
          newReserveTeams.add(ReadyTeam(id: newReserveTeams.length + 1));
        }

        if (reserveIndex > 0 && reserveIndex <= newReserveTeams.length) {
          filledReserveIndices.add(reserveIndex - 1);
          final targetReserveTeam = newReserveTeams[reserveIndex - 1];
          targetReserveTeam.stagedMatchId = stagedMatch.stagedMatchId;
          for (int j = 0; j < teamPlayers.length; j++) {
            if (j < targetReserveTeam.players.length) {
              final pDto = teamPlayers[j];
              final playerId = '${pDto.participantType}_${pDto.participantId}';

              // FIX: ใช้ข้อมูลจาก playerMap
              Player player;
              if (playerMap.containsKey(playerId)) {
                player = playerMap[playerId]!;
              } else {
                // NEW: ตัด (1) ออกจากชื่อ
                var pJson = pDto.toPlayerJson();
                if (pJson['nickname'] is String) {
                  pJson['nickname'] = (pJson['nickname'] as String).replaceAll(
                    RegExp(r'\s\(\d+\)$'),
                    '',
                  );
                }
                player = PlayerFromJson.fromJson(pJson);
                playerMap[playerId] = player;

              }

              targetReserveTeam.players[j] = player;
              if (!waitingPlayerIds.contains(player.id)) {
                newWaitingPlayers.add(player);
                waitingPlayerIds.add(player.id);
              }
            }
          }
        }
      }
    }

    // 2.2: ลงทีมที่ไม่มี Identifier (Auto Match) ในช่องว่างที่เหลือ
    for (var stagedMatch in stagedMatches) {
      final teamPlayers = [...stagedMatch.teamA, ...stagedMatch.teamB];
      if (stagedMatch.courtIdentifier == null) {
        // ตรวจสอบซ้ำ
        bool isDuplicate = false;
        for (var p in teamPlayers) {
          if (playersOnCourts.contains('${p.participantType}_${p.participantId}')) {
            isDuplicate = true;
            break;
          }
        }
        if (isDuplicate) continue;

        // หาช่องว่างในทีมสำรอง
        int? targetIndex;
        for (int i = 0; i < newReserveTeams.length; i++) {
          if (!filledReserveIndices.contains(i)) {
            targetIndex = i;
            break;
          }
        }

        if (targetIndex != null) {
          filledReserveIndices.add(targetIndex);
          final targetReserveTeam = newReserveTeams[targetIndex];
          targetReserveTeam.stagedMatchId = stagedMatch.stagedMatchId;
          
          // Populate Players (Logic เดียวกับด้านบน)
          for (int j = 0; j < teamPlayers.length; j++) {
            if (j < targetReserveTeam.players.length) {
              final pDto = teamPlayers[j];
              final playerId = '${pDto.participantType}_${pDto.participantId}';
              Player player;
              if (playerMap.containsKey(playerId)) {
                player = playerMap[playerId]!;
              } else {
                var pJson = pDto.toPlayerJson();
                player = PlayerFromJson.fromJson(pJson);
                playerMap[playerId] = player;
                if (_playerExtraData.containsKey(playerId)) {
                  final localData = _playerExtraData[playerId]!;
                  player.gamesPlayed = localData['games'] as int?;
                }
              }
              targetReserveTeam.players[j] = player;
              if (!waitingPlayerIds.contains(player.id)) {
                newWaitingPlayers.add(player);
                waitingPlayerIds.add(player.id);
              }
            }
          }
        }
      }
    }

    // --- FIX: นำผู้เล่นจากทีมสำรองเก่าที่ยังจัดไม่เสร็จกลับมาใส่ ---
    for (
      int i = 0;
      i < oldReserveTeams.length && i < newReserveTeams.length;
      i++
    ) {
      // ถ้่าทีมใหม่ยังว่าง และทีมเก่ามีผู้เล่นอยู่ (แต่ไม่ครบ 4)
      if (newReserveTeams[i].players.every((p) => p == null) &&
          oldReserveTeams[i].players.any((p) => p != null) &&
          oldReserveTeams[i].stagedMatchId == null) {
        // FIX: กู้คืนเฉพาะข้อมูลที่ยังไม่เคย Save ลง Server (Draft)
        newReserveTeams[i].players = List.from(oldReserveTeams[i].players);
      }
    }

    setState(() {
      waitingPlayers = newWaitingPlayers;
      playingCourts = newPlayingCourts;
      reserveTeams = newReserveTeams; // NEW: อัปเดตทีมสำรอง
      readyTeams = newReadyTeams; // อัปเดต readyTeams ให้ตรงกับ playingCourts
      _groupName = liveState['groupName']; // หากมีข้อมูลชื่อก๊วนใน API

      // --- FIX: อัปเดตข้อมูลผู้เล่นที่กำลังเปิดดู Profile อยู่ (ถ้ามี) ---
      // เพื่อให้กาดและ Dropdown ระดับมือเปลี่ยนตามข้อมูลใหม่ทันที
      if (_viewingPlayer != null) {
        Player? updatedPlayer;
        // 1. ลองหาใน Waiting List
        try {
           updatedPlayer = newWaitingPlayers.firstWhere((p) => p.id == _viewingPlayer!.id);
        } catch (_) {}
        
        // 2. ถ้าไม่เจอ ลองหาในสนาม (Playing Courts)
        if (updatedPlayer == null) {
           for (var court in newPlayingCourts) {
             for (var p in court.players) {
               if (p != null && p.id == _viewingPlayer!.id) {
                 updatedPlayer = p;
                 break;
               }
             }
             if (updatedPlayer != null) break;
           }
        }
        
        // 3. ถ้าไม่เจอ ลองหาในทีมสำรอง (Reserve Teams)
        if (updatedPlayer == null) {
           for (var team in newReserveTeams) {
             for (var p in team.players) {
               if (p != null && p.id == _viewingPlayer!.id) {
                 updatedPlayer = p;
                 break;
               }
             }
             if (updatedPlayer != null) break;
           }
        }

        // ถ้าเจอข้อมูลใหม่ ให้อัปเดตตัวแปร _viewingPlayer
        if (updatedPlayer != null) {
          _viewingPlayer = updatedPlayer;
        }
      }

      // --- FIX: อัปเดตจำนวนผู้เข้าร่วมจากข้อมูลจริงที่มีอยู่ ---
      // _currentParticipants = waitingPlayers.length; // เอาออก: ไม่ควรเอาจำนวนคนรอมาทับจำนวนคนทั้งหมด
      if (liveState['maxParticipants'] != null) {
        _maxParticipants = liveState['maxParticipants'];
      }
      // --- FIX: เคลียร์ผู้เล่นที่เลือกไว้เพื่อป้องกันข้อมูลเก่าค้าง (Stale References) ---
      selectedPlayers.clear();

      // --- NEW: ตรวจสอบสถานะและเวลาเริ่มการแข่งขันจาก Server ---
      if (liveState['competitionStartTime'] != null) {
        _isStartGame = true;
        final startTime = DateTime.parse(liveState['competitionStartTime']);
        final now = DateTime.now();
        // คำนวณเวลาที่ผ่านไปจริงจากเวลาเริ่มบน Server
        final diff = now.difference(startTime);
        _sessionDuration = diff.isNegative ? Duration.zero : diff;

        // เริ่ม Timer เพื่อนับเวลาต่อ (ถ้ายังไม่เริ่ม)
        if (_sessionTimer == null || !_sessionTimer!.isActive) {
          _startSessionTimer();
        }
      } else {
        _isStartGame = false;
        _sessionDuration = Duration.zero;
        _sessionTimer?.cancel();
        _sessionTimer = null;
      }
    });
  }

  // --- NEW: ฟังก์ชันสำหรับจัดคู่อัตโนมัติผ่าน API ---
  Future<void> _autoMatchAPI() async {
    if (!_isStartGame) {
      showDialogMsg(
        context,
        title: 'แจ้งเตือน',
        subtitle: 'กรุณากด "เริ่มการแข่งขัน" ในเมนูก่อน',
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      // รวม ID ของคนที่ถูกหยุดเกมและจบเกม เพื่อส่งไปให้ Backend กรองออก
      final excludedIds = [..._pausedPlayerIds, ..._endedPlayerIds];

      // ส่ง scoringWeights เฉพาะตอนผู้จัดปรับเอง — ค่า default ปล่อย backend ใช้ค่าเดิม
      final body = <String, dynamic>{
        "isMixedMode": _isMixedMode,
        "excludedPlayerIds": excludedIds,
      };
      if (!_autoMatchWeights.isDefault) {
        body['scoringWeights'] = _autoMatchWeights.toJson();
      }

      await ApiProvider().post(
        '/GameSessions/${widget.id}/auto-match',
        data: body,
      );
      // ไม่ต้องทำอะไรต่อ เพราะ SignalR จะส่งข้อมูล Live State ใหม่มาให้เอง
    } catch (e) {
      showDialogMsg(
        context,
        title: 'จัดคู่ไม่สำเร็จ',
        subtitle: e.toString().replaceFirst('Exception: ', ''),
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- NEW: ฟังก์ชันสำหรับสร้าง Staged Match ---
  // --- REFACTORED: to handle both full and partial teams ---
  Future<void> _createStagedMatch(
    ReadyTeam team, {
    bool isReserve = false,
  }) async {
    // if (team.players.every((p) => p == null))
    //   return; // ถ้าทีมว่างเปล่า ไม่ต้องทำอะไร
    try {
      // --- FIX: ค้นหา Team ตัวจริงจาก List ล่าสุด เพื่อป้องกันปัญหา Stale Object (เด้งไปสำรอง) ---
      ReadyTeam? currentTeam;
      String? courtIdentifier;

      // --- FIX: ใช้ isReserve เพื่อแยกแยะว่าจะหาใน list ไหน (เพราะ ID อาจซ้ำกันได้) ---
      if (!isReserve) {
        // 1. ลองหาใน readyTeams (สนามจริง)
        int index = readyTeams.indexWhere((t) => t.id == team.id);
        if (index != -1) {
          currentTeam = readyTeams[index];
          if (index < playingCourts.length) {
            courtIdentifier = playingCourts[index].identifier;
          }
        }
      } else {
        // 2. ลองหาใน reserveTeams (ทีมสำรอง)
        int index = reserveTeams.indexWhere((t) => t.id == team.id);
        if (index != -1) {
          currentTeam = reserveTeams[index];
          courtIdentifier = '-${currentTeam.id}';
        }
      }

      if (currentTeam == null) return; // ไม่เจอทีม (อาจถูกลบไปแล้ว)

      // --- REFACTORED: Send all 4 player slots, including nulls for empty slots ---
      // FIX: ส่ง List ว่าง [] แทน [null, null] เพื่อให้ Server เข้าใจว่าต้องลบ
      List<Map<String, dynamic>> teamAPlayers = [];
      for (var p in currentTeam.players.sublist(0, 2)) {
        if (p != null) {
          final parts = p.id.split('_');
          teamAPlayers.add({"type": parts[0], "id": int.parse(parts[1])});
        }
      }

      List<Map<String, dynamic>> teamBPlayers = [];
      for (var p in currentTeam.players.sublist(2, 4)) {
        if (p != null) {
          final parts = p.id.split('_');
          teamBPlayers.add({"type": parts[0], "id": int.parse(parts[1])});
        }
      }

      // --- FIX: เพิ่ม courtIdentifier เข้าไปใน DTO ---
      final Map<String, dynamic> dto = {
        "teamA": teamAPlayers,
        "teamB": teamBPlayers,
        "courtIdentifier": courtIdentifier, // ใช้ค่าที่หามาได้ใหม่
      };

      final response = await ApiProvider().post(
        '/gamesessions/${widget.id}/staged-matches',
        data: dto,
      );

      setState(() {
        currentTeam!.stagedMatchId = response['data']['matchId'];
      });
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error creating staged match: $e')),
        // );
      }
    }
  }

  // --- 2. TIMER LOGIC: ฟังก์ชันสำหรับจัดการเวลา ---
  Future<void> _startTimer(PlayingCourt court) async {
    // --- NEW: ตรวจสอบว่าเริ่มการแข่งขันหรือยัง ---
    if (!_isStartGame) {
      showDialogMsg(
        context,
        title: 'ยังไม่เริ่มการแข่งขัน',
        subtitle: 'กรุณากด "เริ่มการแข่งขัน" ในเมนูมุมขวาล่างก่อน',
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
      return;
    }

    // --- FIX: ถ้าเป็นการ Resume (สถานะ Paused) ให้เริ่มจับเวลาต่อเลย ไม่ต้องยิง API ---
    if (court.status == CourtStatus.paused) {
      _timers[court.courtNumber]?.cancel();
      setState(() {
        court.status = CourtStatus.playing;
        // court.isLocked = true; // ปกติ Locked อยู่แล้วตอน Pause แต่กันเหนียว
      });
      
      _timers[court.courtNumber] = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (mounted) {
            // อัปเดตข้อมูล Model โดยไม่ต้อง setState ทั้งหน้า
            court.elapsedTime += const Duration(seconds: 1);
          }
        },
      );
      return; // จบการทำงาน ไม่ยิง API เพราะแมตช์ยังรันอยู่ที่ Backend
    }

    // --- NEW: Force Sync ข้อมูลล่าสุดขึ้น Server ก่อนเริ่มเกม ---
    // ป้องกันกรณีกดเริ่มเกมทันทีหลังจากลากผู้เล่นวาง (ก่อน Debounce ทำงาน)
    int teamIndex = playingCourts.indexOf(court);
    if (teamIndex != -1) {
      final team = readyTeams[teamIndex];
      // บังคับส่งข้อมูลทันที
      await _createStagedMatch(team);
    }

    // --- FIX: ค้นหา court และ teamIndex ใหม่หลังจาก await ---
    // เพราะข้อมูล playingCourts อาจถูกอัปเดตใหม่จาก SignalR ระหว่างรอ API
    teamIndex = playingCourts.indexWhere(
      (c) => c.identifier == court.identifier,
    );
    if (teamIndex == -1) return; // ไม่พบสนามแล้ว (อาจถูกลบหรือรีเซ็ต)

    final currentCourt = playingCourts[teamIndex];
    final currentTeam = readyTeams[teamIndex];

    // --- FIX: ตรวจสอบว่ามี stagedMatchId หรือยัง ---
    if (currentTeam.stagedMatchId == null) {
      showDialogMsg(
        context,
        title: 'แจ้งเตือน',
        subtitle: 'ยังไม่ได้จัดทีมบนเซิร์ฟเวอร์ โปรดลองลากผู้เล่นออกแล้วใส่ใหม่',
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
      return;
    }

    // --- OPTIMISTIC UI: อัปเดตหน้าจอทันที ไม่ต้องรอ API ---
    _timers[currentCourt.courtNumber]?.cancel();
    setState(() {
      currentCourt.status = CourtStatus.playing;
      currentCourt.isLocked = true; // <<< NEW: ล็อกสนามเมื่อเกมเริ่ม
    });

    // เริ่มเดินเวลาทันที
    _timers[currentCourt.courtNumber] = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (mounted) {
          // อัปเดตข้อมูล Model โดยไม่ต้อง setState ทั้งหน้า
          currentCourt.elapsedTime += const Duration(seconds: 1);
        }
      },
    );

    // --- ยิง API เบื้องหลัง ---
    try {
      await _callStartMatchAPI(currentCourt); 
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      // ถ้าเป็นการ Timeout (The request took longer than...)
      if (errorStr.contains('took longer than') || errorStr.contains('timeout')) {
        // ไม่ต้อง Rollback ทันที เพราะเซิร์ฟเวอร์อาจจะเริ่มเกมไปแล้ว
        // ให้ทำการดึงข้อมูลล่าสุดเพื่อ Sync หน้าจอแทนแบบเงียบๆ
        if (mounted) {
          _fetchLiveState(showLoading: false);
        }
      } else {
        // --- ROLLBACK: ถ้า API Error ทั่วไป ให้ยกเลิกทุกอย่าง ---
        _timers[currentCourt.courtNumber]?.cancel();
        if (mounted) {
          setState(() {
            currentCourt.status = CourtStatus.waiting;
            currentCourt.isLocked = false;
            currentCourt.elapsedTime = Duration.zero;
            currentCourt.matchId = null;
          });
          showDialogMsg(
            context,
            title: 'เริ่มเกมไม่สำเร็จ',
            subtitle: e.toString().replaceFirst('Exception: ', ''),
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
        }
      }
    }
  }

  void _pauseTimer(PlayingCourt court) {
    _timers[court.courtNumber]?.cancel();
    if (mounted) {
      setState(() {
        court.status = CourtStatus.paused;
        // court.isLocked = false; // FIX: ไม่ต้องปลดล็อกสนามเมื่อหยุดชั่วคราว
      });
    }
  }

  Future<void> _callStartMatchAPI(PlayingCourt court) async {
    // หา ReadyTeam ที่อยู่ใต้สนามนี้
    // FIX: ใช้ indexWhere เพื่อค้นหาจาก identifier ป้องกันปัญหา Object เก่า (Stale Reference)
    final teamIndex = playingCourts.indexWhere(
      (c) => c.identifier == court.identifier,
    );
    if (teamIndex == -1) return;

    final stagedTeam = readyTeams[teamIndex];

    if (stagedTeam.stagedMatchId == null)
      return; // ถ้าไม่มี staged match id ก็ไม่ต้องทำอะไร

    try {
      final dto = {"courtNumber": court.identifier};
      final response = await ApiProvider().post(
        '/staged-matches/${stagedTeam.stagedMatchId}/start',
        data: dto,
      );
      if (mounted) {
        setState(() {
          court.matchId = response['data']['matchId'];
          stagedTeam.stagedMatchId =
              null; // เคลียร์ stagedMatchId หลังจากเริ่มเกมแล้ว
        });
      }
    } catch (e) {
      // --- FIX: Rethrow error เพื่อให้ _startTimer จัดการ Rollback ---
      rethrow;
    }
  }

  // --- NEW: ฟังก์ชันสำหรับย้ายทีมสำรองลงสนามที่ว่าง ---
  Future<void> _autoAssignReserveTeamToCourt(PlayingCourt court) async {
    // --- REFACTORED: เรียก API แทนการคำนวณเอง ---
    try {
      await ApiProvider().post(
        '/GameSessions/${widget.id}/assign-reserve',
        data: {
          "targetCourtIdentifier": court.identifier,
          "isQueueMode": _isQueueMode
        },
      );
      // ไม่ต้องทำอะไรต่อ SignalR จะอัปเดตหน้าจอเอง
    } catch (e) {
      // ถ้าไม่มีทีมสำรอง หรือ Error อื่นๆ ก็ปล่อยผ่าน (อาจจะแค่ไม่มีทีมพร้อม)
      // print('Auto assign failed: $e');
    }
  }

  Future<void> _endGame(PlayingCourt court) async {
    _timers[court.courtNumber]?.cancel();
    final String courtIdentifier =
        court.identifier; // FIX: เก็บ identifier ไว้ค้นหา object ใหม่

    // --- OPTIMISTIC UI: เคลียร์หน้าจอทันที ---
    if (mounted) {
      // --- FIX: ค้นหา object สนามปัจจุบันจาก identifier เพราะ playingCourts อาจถูกรีเฟรชจาก SignalR แล้ว ---
      final currentCourtIndex = playingCourts.indexWhere(
        (c) => c.identifier == courtIdentifier,
      );
      if (currentCourtIndex == -1) return; // ถ้าไม่เจอสนามแล้ว ให้จบการทำงาน
      final currentCourt = playingCourts[currentCourtIndex];

      setState(() {
        // --- ส่วนที่เพิ่มเข้ามา ---
        // 1. วนลูปเพื่อย้ายผู้เล่นทุกคนในสนามกลับไปที่ waitingPlayers list
        for (var player in currentCourt.players) {
          // FIX: ใช้ currentCourt แทน court เดิม
          if (player != null) {
            // คืนผู้เล่นกลับไปที่ List ผู้เล่นที่รอ
            // --- FIX: ใช้ ID ในการตรวจสอบเพื่อป้องกันการเพิ่มซ้ำ ---
            final bool isAlreadyInWaitingList = waitingPlayers.any(
              (p) => p.id == player.id,
            );
            if (!isAlreadyInWaitingList) {
              waitingPlayers.add(player);
            }
            
            // --- NEW: รีเซ็ตเวลาที่รอ ให้เริ่มนับใหม่ ณ ตอนนี้ ---
            _playerExtraData[player.id] = {
              'games': (player.gamesPlayed ?? 0) + 1,
              'checkinTime': DateTime.now(), // ค่า Placeholder
              'waitingSince': DateTime.now(), // เริ่มนับเวลาใหม่
            };
            player.totalPlayTime = Duration.zero; // รีเซ็ตการแสดงผล
            player.gamesPlayed = (player.gamesPlayed ?? 0) + 1; // FIX: อัปเดตจำนวนเกมทันทีเพื่อให้ UI ตรงกัน

            // ถ้าผู้เล่นคนนี้เคยถูกเลือกไว้ ให้เอาออกจาก selected list ด้วย
            selectedPlayers.remove(player);
          }
        }

        // --- ส่วนโค้ดเดิมที่ปรับปรุง ---
        // 2. รีเซ็ตสถานะทั้งหมดของสนาม
        currentCourt.status = CourtStatus.waiting;
        currentCourt.isLocked = false;
        currentCourt.gamesPlayedCount +=
            1; // FIX: เพิ่มจำนวนเกมที่เล่นในสนามนี้
        currentCourt.elapsedTime = Duration.zero;

        // 3. เคลียร์ผู้เล่นทั้งหมดออกจากสนาม
        currentCourt.players = List.filled(4, null);

        // --- FIX: เคลียร์ผู้เล่นออกจาก ReadyTeam ที่คู่กันด้วย ---
        // ใช้ currentCourtIndex ที่หามาได้เลย
        if (currentCourtIndex != -1) {
          readyTeams[currentCourtIndex].players = List.filled(4, null);
          readyTeams[currentCourtIndex].stagedMatchId =
              null; // เคลียร์ ID ของ Staged Match ด้วย
        }
      });

      // NEW: ลองจัดทีมสำรองลงสนามที่ว่างทันที (เรียกนอก setState)
      // --- FIX: เรียก API Assign Reserve ---
      await _autoAssignReserveTeamToCourt(currentCourt);
    }

    // --- ยิง API เบื้องหลัง ---
    if (court.matchId != null) {
      try {
        await ApiProvider().put('/matches/${court.matchId}/end');
      } catch (e) {
        // --- ROLLBACK STRATEGY: ถ้าจบเกมไม่สำเร็จ ให้โหลดข้อมูลใหม่จาก Server ---
        // เพราะการกู้คืนสถานะผู้เล่นที่ถูกย้ายไปแล้วนั้นซับซ้อน การโหลดใหม่ชัวร์กว่า
        if (mounted) {
          final errStr = e.toString();
          if (!errStr.contains('401')) {
             if (!errStr.toLowerCase().contains('took longer than') && !errStr.toLowerCase().contains('timeout')) {
               showDialogMsg(
                 context,
                 title: 'จบเกมไม่สำเร็จ',
                 subtitle: 'ระบบจะโหลดข้อมูลล่าสุด: ${e.toString().replaceFirst('Exception: ', '')}',
                 btnLeft: 'ตกลง',
                 onConfirm: () {},
               );
             }
             _fetchLiveState(showLoading: false); // โหลดข้อมูลใหม่เงียบๆ
          }
        }
      }
    }
  }

  Future<void> _showPauseOrEndGameDialog(PlayingCourt court) async {
    return showDialogMsg(
      context,
      title: 'หยุดเกม',
      subtitle: 'คุณต้องการหยุดชั่วคราว หรือ จบเกมนี้?',
      isWarning: true,
      btnLeft: 'จบเกม',
      btnLeftBackColor: Color(0xFFFFFFFF),
      btnLeftForeColor: Color(0xFF0E9D7A),
      btnRight: 'หยุดชั่วคราว',
      onConfirm: () {
        _endGame(court);
      },
      onConfirmRight: () {
        _pauseTimer(court);
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatSessionDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitHours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // อัปเดตข้อมูล Model โดยไม่ต้อง setState ทั้งหน้า
        _sessionDuration += const Duration(seconds: 1);
        // --- NEW: สั่งให้ Overlay (เมนู) รีเฟรชตัวเองเพื่ออัปเดตเวลา ---
        _fabMenuOverlay?.markNeedsBuild();
      }
    });
  }

  // ... ใน _ManageGamePageState
  Future<void> _placeSelectedPlayers(dynamic courtOrTeam) async {
    if (selectedPlayers.isEmpty) return;

    // 1. เตรียมข้อมูลผู้เล่นที่จะย้าย
    final playersToMove = List<Player>.from(selectedPlayers);

    setState(() {
      selectedPlayers.clear(); // เคลียร์ตัวเลือกทันที
    });

    // 2. เรียก API ย้ายผู้เล่น (ทำนอก setState เพราะเป็น async)
    await _movePlayersToTeam(playersToMove, courtOrTeam);
  }

  // --- REFACTORED: ใช้ API Move Players แทน Logic หน้าบ้าน ---
  Future<void> _movePlayersToTeam(
    List<Player> playersToMove,
    dynamic targetCourtOrTeam,
  ) async {
    String? targetIdentifier;

    if (targetCourtOrTeam is PlayingCourt) {
      targetIdentifier = targetCourtOrTeam.identifier;
    } else if (targetCourtOrTeam is ReadyTeam) {
      // ถ้าเป็น ReadyTeam (ทีมสำรอง) ให้ใช้ ID ติดลบ
      targetIdentifier = '-${targetCourtOrTeam.id}';
    }

    if (targetIdentifier == null) return;

    try {
      // เตรียมข้อมูลผู้เล่นที่จะย้าย
      List<Map<String, dynamic>> playersDto = [];
      for (var p in playersToMove) {
        final parts = p.id.split('_');
        playersDto.add({
          "type": parts[0],
          "id": int.parse(parts[1])
        });
      }

      // เรียก API
      await ApiProvider().post(
        '/GameSessions/${widget.id}/move-players',
        data: {
          "players": playersDto,
          "targetCourtIdentifier": targetIdentifier
        },
      );
      // ไม่ต้องทำอะไรต่อ SignalR จะอัปเดตหน้าจอเอง
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'ย้ายผู้เล่นไม่สำเร็จ',
          subtitle: e.toString().replaceFirst('Exception: ', ''),
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    }
  }

  // --- NEW: Centralized function to remove a player from their current spot ---
  void _removePlayerFromCurrentSlot(
    Player playerToRemove, {
    bool addToWaitingList = false,
    Set<ReadyTeam>? affectedTeamsCollector, // NEW: รับ Set เพื่อเก็บทีมที่ต้องอัปเดต (Batch Update)
  }) {
    bool removed = false;

    // 1. Check playing courts and their corresponding ready teams
    for (int i = 0; i < playingCourts.length; i++) {
      final court = playingCourts[i];
      final readyTeam = readyTeams[i];
      final index = court.players.indexOf(playerToRemove);
      if (index != -1) {
        court.players[index] = null;
        if (readyTeam.players.length > index) {
          readyTeam.players[index] = null;
        }
        
        // --- FIX: ถ้ามีการเก็บ Collector ให้ใส่ลงไปแทนการยิง API ทันที ---
        if (affectedTeamsCollector != null) {
          affectedTeamsCollector.add(readyTeam);
        } else {
          // ถ้าไม่มี Collector ให้ยิง API ทันทีเหมือนเดิม
          if (readyTeams.contains(readyTeam)) {
            _createStagedMatch(readyTeam); 
          } else if (reserveTeams.contains(readyTeam)) {
            _createStagedMatch(readyTeam, isReserve: true); 
          }
        }

        removed = true;
        break; // Player found and removed, exit loop
      }
    }

    // 2. Check reserve teams
    if (!removed) {
      for (var reserveTeam in reserveTeams) {
        final index = reserveTeam.players.indexOf(playerToRemove);
        if (index != -1) {
          reserveTeam.players[index] = null;
          
          if (affectedTeamsCollector != null) {
            affectedTeamsCollector.add(reserveTeam);
          } else {
            _createStagedMatch(reserveTeam, isReserve: true);
          }
          
          removed = true;
          break; // Player found and removed, exit loop
        }
      }
    }

    // 3. If not found in any team, remove from the main waiting list
    if (!removed) {
      waitingPlayers.remove(playerToRemove);
    }

    if (addToWaitingList) {
      _addPlayerToWaitingList(playerToRemove);
    }
  }

  // --- NEW: Helper to add player to waiting list without duplicates (แก้ไขการเพิ่ม) ---
  void _addPlayerToWaitingList(Player player) {
    final bool isAlreadyInWaitingList = waitingPlayers.any(
      (p) => p.id == player.id,
    );
    if (!isAlreadyInWaitingList) {
      // Add to the END of the list
      // --- FIX: เปลี่ยนเป็น .add() เพื่อเพิ่มท้ายลิสต์ ---
      waitingPlayers.add(player);
    }
  }

  void _onPlayerTap(Player player) {
    setState(() {
      // --- REVISED LOGIC: Combine multi-select and swap ---
      final isSelected = selectedPlayers.contains(player);
      if (isSelected) {
        // ถ้าผู้เล่นที่แตะถูกเลือกอยู่แล้ว
        if (selectedPlayers.length == 2) {
          // และมีผู้เล่นที่ถูกเลือกอยู่ 2 คนพอดี -> นี่คือการ "สลับ"
          final player1 = selectedPlayers[0];
          final player2 = selectedPlayers[1];
          _swapPlayers(player1, player2);
          selectedPlayers.clear(); // ล้างตัวเลือกหลังสลับ
        } else {
          // ถ้ามีผู้เล่นที่เลือกน้อยกว่าหรือมากกว่า 2 คน -> ให้ "ยกเลิกการเลือก" ตามปกติ
          selectedPlayers.remove(player);
        }
      } else {
        // ถ้าผู้เล่นที่แตะยังไม่ได้ถูกเลือก -> ให้ "เพิ่มเข้ากลุ่มที่เลือก"
        if (selectedPlayers.length < 4) {
          selectedPlayers.add(player);
        } else {
          // ถ้าเลือกครบ 4 คนแล้ว ให้แสดงข้อความเตือน
          showDialogMsg(
            context,
            title: 'แจ้งเตือน',
            subtitle: 'เลือกผู้เล่นได้สูงสุด 4 คน',
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
        }
      }
    });
  }

  // --- NEW: ฟังก์ชันสำหรับสลับตำแหน่งผู้เล่น 2 คน ---
  Future<void> _swapPlayers(Player player1, Player player2) async {
    // --- REFACTORED: เรียก API Swap ---
    try {
      final p1Parts = player1.id.split('_');
      final p2Parts = player2.id.split('_');

      await ApiProvider().post(
        '/GameSessions/${widget.id}/swap-players',
        data: {
          "player1": {"type": p1Parts[0], "id": int.parse(p1Parts[1])},
          "player2": {"type": p2Parts[0], "id": int.parse(p2Parts[1])}
        },
      );
      // SignalR จะอัปเดตหน้าจอเอง
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'สลับตัวไม่สำเร็จ',
          subtitle: e.toString().replaceFirst('Exception: ', ''),
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    }
  }

  // --- NEW: Helper function to sync ReadyTeam data to PlayingCourt UI ---
  void _syncReadyTeamToPlayingCourt(ReadyTeam team) {
    final courtIndex = readyTeams.indexOf(team);
    if (courtIndex != -1) {
      playingCourts[courtIndex].players = List.from(team.players);
    }
  }

  // --- UPDATED: เพิ่ม affectedTeamsCollector เพื่อรองรับ Batch Update ---
  void _removePlayerFromCourt(
    dynamic courtOrTeam, 
    int slotIndex, 
    {Set<ReadyTeam>? affectedTeamsCollector}) {
    setState(() {
      // --- FIX: ค้นหา object ล่าสุดจาก List เสมอ ---
      dynamic currentCourtOrTeam = courtOrTeam;
      bool isReserve = false;

      if (courtOrTeam is PlayingCourt) {
        final index = playingCourts.indexWhere(
          (c) => c.identifier == courtOrTeam.identifier,
        );
        if (index != -1)
          currentCourtOrTeam = playingCourts[index];
        else
          return; // ไม่พบสนาม
      } else if (courtOrTeam is ReadyTeam) {
        final index = reserveTeams.indexWhere((t) => t.id == courtOrTeam.id);
        if (index != -1) {
          currentCourtOrTeam = reserveTeams[index];
          isReserve = true;
        } else
          return; // ไม่พบทีมสำรอง
      }

      Player? playerToRemove = currentCourtOrTeam.players[slotIndex];

      if (playerToRemove != null) {
        // นำผู้เล่นออกจากสนาม
        currentCourtOrTeam.players[slotIndex] = null;

        // --- FIX: ตรวจสอบและนำผู้เล่นออกจาก ReadyTeam ที่คู่กันด้วย ---
        if (!isReserve && currentCourtOrTeam is PlayingCourt) {
          final courtIndex = playingCourts.indexOf(currentCourtOrTeam);
          if (courtIndex != -1 &&
              readyTeams[courtIndex].players.length > slotIndex) {
            readyTeams[courtIndex].players[slotIndex] = null;
          }
        }

        // คืนผู้เล่นกลับไปที่ List ผู้เล่นที่รอ
        if (!waitingPlayers.contains(playerToRemove)) {
          waitingPlayers.add(playerToRemove);
        }
        // ถ้าผู้เล่นคนนี้ถูกเลือกอยู่ ให้เอาออกจาก List ที่เลือกด้วย
        selectedPlayers.remove(playerToRemove);

        // --- FIX: ถ้าเป็นการนำผู้เล่นออกจากทีมสำรอง ให้เรียก API อัปเดต ---
        if (isReserve) {
          // การเรียก API ที่นี่จะทำให้เซิร์ฟเวอร์รู้ว่าทีมนี้ไม่ครบแล้ว
          // และจะถูกลบออกจาก stagedMatches ในการเรียก live-state ครั้งถัดไป
          
          if (affectedTeamsCollector != null) {
            affectedTeamsCollector.add(currentCourtOrTeam);
          } else {
            _createStagedMatch(currentCourtOrTeam, isReserve: true); // FIX: บันทึกทันที
          }
        }
      }
    });
  }

  // --- NEW: ฟังก์ชันสำหรับลบผู้เล่นออกจากทีมโดยใช้ object ของ Player ---
  void _removePlayerFromCourtByPlayer(dynamic courtOrTeam, Player player, {Set<ReadyTeam>? affectedTeamsCollector}) {
    // หา index ของผู้เล่นในทีม
    final index = courtOrTeam.players.indexOf(player);
    if (index != -1) {
      // ถ้าเจอ ให้เรียกฟังก์ชันเดิมที่ลบจาก index
      _removePlayerFromCourt(courtOrTeam, index, affectedTeamsCollector: affectedTeamsCollector);
    }
  }

  // --- NEW: ฟังก์ชันสำหรับหยุด/เริ่มเกมผู้เล่น ---
  Future<void> _togglePlayerPause(Player player) async {
    // --- UX IMPROVEMENT: ไม่ต้องใช้ _isProcessing หรือ Loading เพราะเป็นการทำงาน Local (Optimistic UI) ---
    // ทำงานทันทีเพื่อให้ผู้ใช้รู้สึกว่าแอปเร็ว
    bool isPaused = _pausedPlayerIds.contains(player.id);
    if (isPaused) {
      // Unpause: กลับสู่เกม
      setState(() {
        _pausedPlayerIds.remove(player.id);
      });
      _savePausedPlayers();
    } else {
      // Pause: หยุดเกม
      // 1. ตรวจสอบว่าอยู่ในสนามหลักหรือไม่
      bool inMainCourt = playingCourts.any(
        (c) => c.players.any((p) => p?.id == player.id),
      );
      if (inMainCourt) {
        showDialogMsg(
          context,
          title: 'แจ้งเตือน',
          subtitle: 'ผู้เล่นอยู่ในสนามหลัก ไม่สามารถหยุดได้',
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
        return;
      }

      // 2. ตรวจสอบว่าอยู่ในทีมสำรองหรือไม่ (ถ้าอยู่ให้เด้งออก)
      bool inReserve = reserveTeams.any(
        (t) => t.players.any((p) => p?.id == player.id),
      );
      if (inReserve) {
        // นำออกจากทีมสำรองและคืนค่ากลับ Waiting List
        _removePlayerFromCurrentSlot(player, addToWaitingList: true);
      }

      // 3. เพิ่มเข้ารายการหยุดเกม
      setState(() {
        _pausedPlayerIds.add(player.id);
        // ถ้าผู้เล่นถูกเลือกอยู่ ให้เอาออกจากการเลือกด้วย
        selectedPlayers.remove(player);
      });
      _savePausedPlayers();
    }
  }

  // --- NEW: ฟังก์ชันสำหรับ จบเกม/กลับสู่เกม ผู้เล่น ---
  void _togglePlayerEndGame(Player player) {
    bool isEnded = _endedPlayerIds.contains(player.id);

    if (isEnded) {
      // กรณี: กลับสู่เกม (Resume)
      setState(() {
        _endedPlayerIds.remove(player.id);
      });
      _saveEndedPlayers();
    } else {
      // กรณี: จบเกม (End Game)
      // แสดง Popup ยืนยัน
      showDialogMsg(
        context,
        title: 'คุณต้องการจบเกมผู้เล่น',
        subtitle: player.name,
        subtitleColor: const Color(0xFF0E9D7A),
        btnLeft: 'จบเกม',
        btnLeftForeColor: const Color(0xFF0E9D7A),
        btnLeftBackColor: const Color(0xFFFFFFFF),
        btnRight: 'ยกเลิก',
        btnRightBackColor: const Color(0xFF0E9D7A),
        btnRightForeColor: const Color(0xFFFFFFFF),
        isWarning:true,
        onConfirm: () => _confirmEndPlayerGame(player),
      );
    }
  }

  Future<void> _confirmEndPlayerGame(Player player) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
    // 1. นำออกจากสนามหรือทีมสำรองถ้ามี
    // --- FIX: addToWaitingList = false เพราะเป็นการ Checkout ออกจากระบบ ไม่ใช่แค่จบเกม ---
    _removePlayerFromCurrentSlot(player, addToWaitingList: false);

    // --- OPTIMISTIC UI: อัปเดตหน้าจอไปก่อน ---
    setState(() {
      _endedPlayerIds.add(player.id);
      _pausedPlayerIds.remove(player.id); // ถ้าหยุดอยู่ ให้เอาออกจากหยุดด้วย
      selectedPlayers.remove(player);
    });
    _saveEndedPlayers();
    _savePausedPlayers();

    // --- NEW: ยิง API เพื่อบันทึกเวลาจบเกม (Checkout) ---
    // ย้ายมาทำหลังจากอัปเดต UI และจัดการ Error อย่างถูกต้อง
    final parts = player.id.split('_');
    if (parts.length == 2) {
      final pType = parts[0].toLowerCase();
      final pId = parts[1];
      
      try {
        await ApiProvider().post('/participants/$pType/$pId/checkout');
        
        if (mounted) {
          showDialogMsg(
            context,
            title: 'จบเกมส์ผู้เล่นเรียบร้อย',
            subtitle: player.name,
            subtitleColor: Colors.green,
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
        }
      } catch (e) {
        // --- FIX: ถ้า API Error ให้แจ้งเตือนและโหลดข้อมูลใหม่ (Rollback) ---
        if (mounted) {
          showDialogMsg(
            context,
            title: 'เกิดข้อผิดพลาด',
            subtitle: 'ในการบันทึก: ${e.toString().replaceFirst('Exception: ', '')}',
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
          // โหลดข้อมูลล่าสุดจาก Server เพื่อดึงผู้เล่นกลับมา (ถ้า Checkout ไม่สำเร็จ)
          _fetchLiveState(showLoading: false);
        }
      }
    }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- 3. MAIN BUILD METHOD: โครงสร้างหลักของหน้าจอ ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBarSubMain(title: 'กำลังโหลด...'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // --- FIX: สร้าง List ของผู้เล่นที่รออยู่จริงๆ ---
    // โดยการกรองผู้เล่นที่อยู่ในสนาม หรืออยู่ในทีมสำรองออกไป
    final Set<String> playersInUseIds = {};
    for (var court in playingCourts) {
      for (var player in court.players) {
        if (player != null) playersInUseIds.add(player.id);
      }
    }
    for (var team in reserveTeams) {
      for (var player in team.players) {
        if (player != null) playersInUseIds.add(player.id);
      }
    }
    final List<Player> trulyWaitingPlayers = waitingPlayers
        .where((p) => !playersInUseIds.contains(p.id))
        .toList();
    
    // --- NEW: กรองเฉพาะผู้เล่นตัวจริง (Status 1) ให้แสดงในหน้าหลัก ---
    // ผู้เล่นสำรอง (Status 2) จะไม่แสดงใน Waiting Grid (แต่ไปจัดการใน Roster หรือ Reserve Teams แทน)
    final List<Player> mainWaitingPlayers = trulyWaitingPlayers
        .where((p) => (_participantStatusMap[p.id] ?? 1) == 1).toList();

    // --- NEW: Logic การเรียงลำดับ ---
    mainWaitingPlayers.sort((a, b) {
      // 0. เรียงผู้เล่นที่จบเกมไว้ท้ายสุด (หลัง Paused)
      final isEndedA = _endedPlayerIds.contains(a.id);
      final isEndedB = _endedPlayerIds.contains(b.id);
      if (isEndedA && !isEndedB) return 1;
      if (!isEndedA && isEndedB) return -1;

      // 1. เรียงผู้เล่นที่ถูกหยุดเกมไปไว้ด้านหลังสุด
      final isPausedA = _pausedPlayerIds.contains(a.id);
      final isPausedB = _pausedPlayerIds.contains(b.id);
      if (isPausedA && !isPausedB) return 1;
      if (!isPausedA && isPausedB) return -1;

      // ดึงเวลา Check-in
      // ใช้ waitingSince ในการเรียงลำดับด้วย
      final timeA =
          _playerExtraData[a.id]?['waitingSince'] as DateTime? ?? DateTime.now();
      final timeB =
          _playerExtraData[b.id]?['waitingSince'] as DateTime? ?? DateTime.now();

      if (_isSortBySkill) {
        // เรียงตาม Skill (มากไปน้อย หรือ น้อยไปมาก ตามต้องการ)
        // สมมติ: SkillId น้อย = เก่ง หรือ กลุ่มเดียวกัน
        int skillCompare = (a.skillLevelId ?? 0).compareTo(b.skillLevelId ?? 0);
        if (skillCompare != 0) return skillCompare;

        // ถ้า Skill เท่ากัน ให้เรียงตามเวลา (รอนานสุดขึ้นก่อน)
        return timeA.compareTo(timeB);
      } else {
        // เรียงตามเวลา (รอนานสุดขึ้นก่อน = เวลา Check-in น้อยกว่า)
        return timeA.compareTo(timeB);
      }
    });

    return Scaffold(
      appBar: AppBarSubMain(
        title: 'จัดการก๊วน - $_groupName',
        trailingActions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFFFFFFFF)),
            tooltip: 'แชร์ลิงก์ก๊วน',
            onPressed: _shareSessionInviteLink,
          ),
        ],
      ),
      // --- NEW: เพิ่มปุ่มจัดคู่อัตโนมัติที่มุมขวาบน ---
      // หมายเหตุ: หาก AppBarSubMain ไม่รองรับ actions ให้ลองตรวจสอบไฟล์ component/app_bar.dart
      // หรือใช้ Stack ซ้อนทับใน body แทน
      // actions: [
      //   IconButton(
      //     icon: const Icon(Icons.auto_awesome, color: Colors.white),
      //     onPressed: _suggestMatchByWaitTime,
      //     tooltip: 'จัดคู่อัตโนมัติ',
      //   ),
      // ],
      body: Stack(
        children: [
          SafeArea(
            // RESPONSIVE: บนแท็บเล็บ (>=900) แบ่ง 2 คอลัมน์ — สนาม | ผู้เล่นที่รอ
            // บนมือถือ (<900) ใช้ ListView เดิม
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWideTablet = constraints.maxWidth >= 900;
                if (isWideTablet) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: ListView(
                          padding: const EdgeInsets.all(16.0),
                          children: [
                            _buildCourtsToolbar(),
                            const SizedBox(height: 8),
                            _buildSyncedCourtsList(),
                            _buildReserveTeamsList(),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 2,
                        child: ListView(
                          padding: const EdgeInsets.all(16.0),
                          children: [
                            _buildWaitingHeader(),
                            const SizedBox(height: 8),
                            _buildWaitingPlayersGrid(mainWaitingPlayers),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildCourtsToolbar(),
                    const SizedBox(height: 8),
                    _buildSyncedCourtsList(),
                    _buildReserveTeamsList(),
                    const SizedBox(height: 24),
                    _buildWaitingHeader(),
                    const SizedBox(height: 8),
                    _buildWaitingPlayersGrid(mainWaitingPlayers),
                  ],
                );
              },
            ),
          ),

          // Report Panel (NEW: หน้าดูรายงาน)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _isReportPanelVisible ? 0 : -420, // ซ่อนไปทางขวา
            child: ReportPanel(
              key: ValueKey(_reportRefreshKey), // FIX: ใช้ Key เพื่อบังคับสร้างใหม่เมื่อค่าเปลี่ยน
              sessionId: widget.id,
              onClose: () {
                setState(() {
                  _isReportPanelVisible = false;
                });
              },
            ),
          ),

          // Roster Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _isRosterPanelVisible ? 0 : -365, // -460 คือซ่อนไปทางขวา
            child: RosterManagementPanel(
              sessionId: widget.id,
              players:
                  waitingPlayers, // FIX: ส่งข้อมูลผู้เล่นที่รอคิวไปให้ Panel
              courtFee: _courtFee,
              shuttleFee: _shuttleFee,
              maxParticipants: _maxParticipants, // NEW: ส่งจำนวนรับสูงสุดไป
              // ส่ง callback ไปให้ Panel เพื่อให้มันสั่งปิดตัวเองได้
              onClose: () {
                setState(() {
                  _isRosterPanelVisible = false;
                  // ไม่ต้องปิด Report Panel ที่นี่ เพราะมันอยู่คนละ Layer กัน แต่ถ้าอยากให้สลับกันก็ทำได้
                });
              },
              onPlayerAdded: () {
                 _fetchSessionDetails(); // โหลดสถานะใหม่
                 _fetchLiveState(showLoading: false);
              },
            ),
          ),

          // Player Profile Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top:
                MediaQuery.of(context).size.height *
                (MediaQuery.of(context).size.width > 820 ? 0.2 : 0.5),
            bottom: 0,
            // จะแสดง Panel ก็ต่อเมื่อ _viewingPlayer ไม่ใช่ null
            right: _viewingPlayer != null ? 0 : -365,
            child: PlayerProfilePanel(
              // ส่งข้อมูลผู้เล่นที่กำลังดูเข้าไป
              skillLevels:
                  _skillLevels, // NEW: ส่งข้อมูลระดับมือทั้งหมดไปให้ Panel
              sessionId: widget.id, // FIX: ส่ง sessionId ไปด้วย
              isPaused: _viewingPlayer != null
                  ? _pausedPlayerIds.contains(_viewingPlayer!.id)
                  : false, // NEW
              onTogglePause: _viewingPlayer != null
                  ? () => _togglePlayerPause(_viewingPlayer!)
                  : null, // NEW
              isEnded: _viewingPlayer != null
                  ? _endedPlayerIds.contains(_viewingPlayer!.id)
                  : false, // NEW
              onToggleEndGame: _viewingPlayer != null
                  ? () => _togglePlayerEndGame(_viewingPlayer!)
                  : null, // NEW
              player: _viewingPlayer,
              onClose: () {
                setState(() {
                  _viewingPlayer = null; // สั่งปิดโดยการเคลียร์ข้อมูล
                });
              },
              onShowExpenses: (player) {
                setState(() {
                  _viewingPlayer = null; // สั่งปิด Profile Panel
                  _playerForExpenses = player; // สั่งเปิด Expense Panel
                });
              },
            ),
          ),

          // Expense Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _playerForExpenses != null
                ? 0
                : -460, // ควบคุมด้วย State ใหม่
            child: ExpensePanel(
              player: _playerForExpenses,
              sessionId: widget.id, // ส่ง sessionId ไปด้วย
              skillLevels: _skillLevels, // ส่งข้อมูลระดับมือไปด้วย
              courtFee: _courtFee, // NEW: ส่งค่าสนามไปด้วย
              shuttleFee: _shuttleFee, // NEW: ส่งราคาลูกแบดไปด้วย
              isPaused: _playerForExpenses != null
                  ? _pausedPlayerIds.contains(_playerForExpenses!.id)
                  : false, // NEW
              onTogglePause: _playerForExpenses != null
                  ? () => _togglePlayerPause(_playerForExpenses!)
                  : null, // NEW
              isEnded: _playerForExpenses != null
                  ? _endedPlayerIds.contains(_playerForExpenses!.id)
                  : false, // NEW
              onToggleEndGame: _playerForExpenses != null
                  ? () => _togglePlayerEndGame(_playerForExpenses!)
                  : null, // NEW
              isBuffet: _isBuffet, // NEW: ส่งสถานะเหมาจ่ายไป
              onClose: () {
                setState(() {
                  _playerForExpenses = null; // สั่งปิด Expense Panel
                });
              },
              // --- NEW: เมื่อจ่ายเงินสำเร็จ ให้ลบผู้เล่นออกจากหน้าจอ ---
              onPaymentSuccess: () {
                if (_playerForExpenses != null) {
                  setState(() {
                    _removePlayerFromCurrentSlot(_playerForExpenses!, addToWaitingList: false);
                  });
                }
                _fetchLiveState(showLoading: false); // โหลดข้อมูลล่าสุดเพื่อความชัวร์
              },
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: 20,
            right: _isRosterPanelVisible
                ? 375 
                : _isReportPanelVisible ? 410 // ขยับปุ่มเมื่อเปิด Report Panel
                : _viewingPlayer != null
                ? 430
                : _playerForExpenses != null
                ? 460
                : 20,
            child: Builder(
              key: _fabKey, // ผูก Key เข้ากับปุ่ม
              builder: (context) {
                return FloatingActionButton(
                  onPressed: _toggleFabMenu, // เรียกใช้ฟังก์ชันเปิด/ปิดเมนู
                  backgroundColor: Colors.indigo, // เปลี่ยนสีให้ตรงตามดีไซน์
                  child: const Icon(Icons.menu, color: Colors.white),
                );
              },
            ),
          ),

          // --- NEW: Loading Overlay (แสดงเฉพาะตอนทำงานหนักจริงๆ) ---
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.3), // พื้นหลังสีดำจางๆ
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),

      // floatingActionButton: Builder(
      //   // ใช้ Builder เพื่อให้มี context ของตัวเอง
      //   key: _fabKey, // ผูก Key เข้ากับปุ่ม
      //   builder: (context) {
      //     return FloatingActionButton(
      //       onPressed: _toggleFabMenu, // เรียกใช้ฟังก์ชันเปิด/ปิดเมนู
      //       backgroundColor: Colors.indigo, // เปลี่ยนสีให้ตรงตามดีไซน์
      //       child: const Icon(Icons.menu, color: Colors.white),
      //     );
      //   },
      // ),
    );
  }

  // --- 4. UI BUILDERS: ฟังก์ชันสำหรับสร้างส่วนต่างๆ ของ UI ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: getResponsiveFontSize(context, fontSize: 18),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // --- NEW: Toolbar ส่วนสนาม (extract มาจาก build เพื่อ reuse ใน LayoutBuilder) ---
  Widget _buildCourtsToolbar() {
    final buttons = <Widget>[
      ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _isQueueMode = !_isQueueMode;
            _saveQueueModePreference(_isQueueMode);
          });
        },
        icon: Icon(
          _isQueueMode ? Icons.format_list_numbered : Icons.grid_view,
          size: 16,
        ),
        label: Text(_isQueueMode ? 'จัดตามคิว' : 'จัดตามคอร์ท'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isQueueMode ? Colors.orange : Colors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 32),
        ),
      ),
      ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _isMixedMode = !_isMixedMode;
            _saveMixedModePreference(_isMixedMode);
          });
        },
        icon: Icon(
          _isMixedMode ? Icons.shuffle : Icons.equalizer,
          size: 16,
        ),
        label: Text('โหมด: ${_isMixedMode ? 'ผสม' : 'มือ'}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isMixedMode ? Colors.purple : Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 32),
        ),
      ),
      ElevatedButton.icon(
        onPressed: _autoMatchAPI,
        icon: const Icon(Icons.auto_awesome, size: 16),
        label: const Text('จับคู่ออโต้'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 32),
        ),
      ),
      Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: 'ตั้งค่าน้ำหนักการจัดคู่',
            onPressed: _openAutoMatchSettings,
            icon: const Icon(Icons.tune),
            color: Colors.indigo,
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
          if (!_autoMatchWeights.isDefault)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildSectionTitle('สนาม'),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: buttons,
          ),
        ),
      ],
    );
  }

  // --- NEW: Header ของส่วนผู้เล่นที่รอ ---
  Widget _buildWaitingHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle('ผู้เล่นที่รอ'),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _isSortBySkill = !_isSortBySkill;
            });
          },
          icon: Icon(
            _isSortBySkill ? Icons.bar_chart : Icons.access_time,
            size: 18,
            color: Colors.indigo,
          ),
          label: Text(
            _isSortBySkill ? 'เรียงตามมือ' : 'เรียงตามเวลา',
            style: const TextStyle(
              color: Colors.indigo,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncedCourtsList() {
    // --- FIX: ปรับความสูงให้พอดีกับ Card สนามอย่างเดียว ---
    const double cardHeight = 230;
    const double cardWidth = 210; // เพิ่มความกว้าง

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: playingCourts.length + 1,
        itemBuilder: (context, index) {
          if (index == playingCourts.length) {
            return _buildAddCourtButton(height: cardHeight, width: cardWidth);
          }
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: cardWidth,
              child: _buildCourtCard(
                playingCourts[index],
              ), // แสดงเฉพาะ Card สนามจริง
            ),
          );
        },
      ),
    );
  }

  // --- NEW: ฟังก์ชันสำหรับอัปเดตสนามผ่าน API ---
  Future<void> _updateSessionCourtsAPI() async {
    try {
      final courtIdentifiers = playingCourts.map((c) => c.identifier).toList();
      await ApiProvider().put(
        '/gamesessions/${widget.id}/courts',
        data: {"courtIdentifiers": courtIdentifiers},
      );
    } catch (e) {
      // Handle error silently
    }
  }

  // --- NEW: ฟังก์ชันสำหรับแสดง Dialog เพิ่มสนาม ---
  Future<void> _showAddCourtDialog() async {
    final TextEditingController courtNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เพิ่มสนามใหม่'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: courtNameController,
              autofocus: true,
              decoration: const InputDecoration(hintText: "กรุณาใส่ชื่อสนาม"),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณาใส่ชื่อสนาม';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('เพิ่ม'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _addCourt(courtNameController.text.trim());
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- NEW: ฟังก์ชันสำหรับเพิ่มสนามและเรียก API ---
  void _addCourt(String courtName) {
    setState(() {
      playingCourts.add(
        PlayingCourt(
          courtNumber: playingCourts.length + 1, // UI index
          identifier: courtName, // User-defined name
        ),
      );
      // NEW: เพิ่มทีมสำรองเมื่อมีการเพิ่มสนามหลัก
      reserveTeams.add(ReadyTeam(id: reserveTeams.length + 1));
      // ไม่ต้องเพิ่ม readyTeams ที่ผูกกับสนามอีกต่อไป
    });
    _updateSessionCourtsAPI(); // Sync with backend
  }

  // --- NEW: ฟังก์ชันสำหรับลบสนาม ---
  void _deleteCourt(PlayingCourt court) {
    int index = playingCourts.indexOf(court);
    if (index != -1) {
      setState(() {
        // ดึงคนที่ค้างอยู่ในสนามและทีมเตรียมพร้อม (ถ้ามี) กลับไปที่ Waiting List
        for (var p in court.players) {
          if (p != null && !waitingPlayers.any((wp) => wp.id == p.id)) {
            waitingPlayers.add(p);
            selectedPlayers.remove(p);
          }
        }
        
        // ลบสนาม และ ลบทีมจัดคู่ที่สอดคล้องกับสนามนี้ออกเพื่อไม่ให้ index เหลื่อมกัน
        playingCourts.removeAt(index);
        readyTeams.removeAt(index);
      });
      
      // อัปเดตข้อมูลไปที่ Server
      _updateSessionCourtsAPI(); 
    }
  }

  // --- NEW: ฟังก์ชันสำหรับเคลียร์ทีมสำรอง (เสมือนการลบ) ---
  Future<void> _clearReserveTeam(ReadyTeam team) async {
    final Set<ReadyTeam> affectedTeams = {};
    setState(() {
      // ลบผู้เล่นทุกคนออกจากทีม
      for (int i = 0; i < 4; i++) {
        _removePlayerFromCourt(team, i, affectedTeamsCollector: affectedTeams);
      }
    });

    // บันทึกการเปลี่ยนแปลงลง Server (ทีมที่ว่างเปล่าจะถูกลบอัตโนมัติโดย Logic ของ Server/Client ในรอบถัดไป)
    for (var t in affectedTeams) {
      if (reserveTeams.contains(t)) {
        _createStagedMatch(t, isReserve: true);
      }
    }
  }

  Widget _buildAddCourtButton({required double height, required double width}) {
    return InkWell(
      onTap: _showAddCourtDialog, // --- FIX: เรียก Dialog เมื่อกดปุ่ม ---
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.grey[350],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 40),
      ),
    );
  }

  // --- NEW: Widget สำหรับแสดงรายการทีมสำรอง ---
  Widget _buildReserveTeamsList() {
    const double cardHeight = 230; // FIX: ปรับความสูงของ Card ทีมสำรอง
    const double cardWidth = 210; // ความกว้างของ Card ทีมสำรอง

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionTitle('ทีมสำรอง'),
        const SizedBox(height: 8),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: reserveTeams.length + 1, // +1 สำหรับปุ่มเพิ่มทีมสำรอง
            itemBuilder: (context, index) {
              if (index == reserveTeams.length) {
                return _buildAddReserveTeamButton(
                  height: cardHeight,
                  width: cardWidth,
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: _buildReadyTeamCard(
                    reserveTeams[index],
                    isReserve: true,
                    title: 'ทีมสำรอง ${index + 1}',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- NEW: ปุ่มสำหรับเพิ่มทีมสำรอง ---
  Widget _buildAddReserveTeamButton({
    required double height,
    required double width,
  }) {
    return InkWell(
      // FIX: เปลี่ยนจากการเพิ่มทีมสำรองอย่างเดียวเป็นการเรียก Dialog เพิ่มสนาม
      onTap: _showAddCourtDialog,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.grey[350],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildCourtCard(PlayingCourt court, {ReadyTeam? reserveTeam}) {
    final bool isReserveTeam = reserveTeam != null;
    // กำหนดสีเพื่อการจัดการที่ง่าย
    final Color topColor = isReserveTeam
        ? Colors.blueGrey[800]!
        : const Color(0xFF2E9A8A);
    final Color bottomColor = isReserveTeam
        ? Colors.blueGrey[700]!
        : const Color(0xFF2A3A8A);
    final dynamic courtOrTeam = isReserveTeam ? reserveTeam! : court;
    final bool isFull = court.players.every((p) => p != null);
    final bool isEmpty = court.players.every((p) => p == null); // NEW: เช็คว่าสนามว่างหรือไม่

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: _buildTopHalf(
                  courtOrTeam,
                  topColor,
                  isReserveTeam: isReserveTeam,
                ),
              ),
              Expanded(
                child: _buildBottomHalf(
                  courtOrTeam,
                  bottomColor,
                  isReserveTeam: isReserveTeam,
                  courtIdentifier: court.identifier,
                ),
              ),
            ],
          ),
          // --- NEW: ปุ่มลบสนาม (แสดงเฉพาะตอนที่ไม่ได้เล่นเกม และ สนามต้องว่างเปล่า) ---
          if (court.status != CourtStatus.playing && isEmpty)
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: () {
                  showDialogMsg(
                    context,
                    title: 'ลบสนาม',
                    subtitle: 'คุณต้องการลบสนาม ${court.identifier} หรือไม่?',
                    isWarning: true,
                    btnLeft: 'ลบ',
                    btnLeftBackColor: Colors.red,
                    btnLeftForeColor: Colors.white,
                    btnRight: 'ยกเลิก',
                    onConfirm: () => _deleteCourt(court),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          if (!isReserveTeam) _buildCenterPauseButton(court, isFull: isFull),
          if (court.status == CourtStatus.playing)
            Positioned.fill(
              child: InkWell(
                onTap: () {
                  if (court.status == CourtStatus.playing) {
                    _showPauseOrEndGameDialog(court);
                  } else if (isFull) {
                    // --- NEW: ตรวจสอบก่อนเริ่มเกม ---
                    if (!_isStartGame) {
                      showDialogMsg(
                        context,
                        title: 'แจ้งเตือน',
                        subtitle: 'กรุณากด "เริ่มการแข่งขัน" ก่อน',
                        btnLeft: 'ตกลง',
                        onConfirm: () {},
                      );
                      return;
                    }
                    _startTimer(court);
                  } else {
                    showDialogMsg(
                      context,
                      title: 'แจ้งเตือน',
                      subtitle: 'ต้องมีผู้เล่นครบ 4 คนจึงจะเริ่มเกมได้',
                      btnLeft: 'ตกลง',
                      onConfirm: () {},
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  // --- NEW: สร้าง Helper Widget เพื่อให้โค้ดสะอาดขึ้น ---

  // Widget สำหรับสร้างครึ่งบน (สีเขียว)
  Widget _buildTopHalf(
    dynamic courtOrTeam,
    Color backgroundColor, {
    required bool isReserveTeam,
  }) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // --- Spacer ดันให้รูปผู้เล่นอยู่ตรงกลาง ---
          const SizedBox(height: 30),
          // --- ช่องผู้เล่น ---
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPlayerSlot(courtOrTeam, 0),
                _buildPlayerSlot(courtOrTeam, 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget สำหรับสร้างครึ่งล่าง (สีน้ำเงิน)
  Widget _buildBottomHalf(
    dynamic courtOrTeam,
    Color backgroundColor, {
    required bool isReserveTeam,
    required String courtIdentifier,
  }) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // --- ช่องผู้เล่น ---
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPlayerSlot(courtOrTeam, 2),
                _buildPlayerSlot(courtOrTeam, 3),
              ],
            ),
          ),
          // --- แถวข้อมูลด้านล่างสุด ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isReserveTeam && courtOrTeam is PlayingCourt)
                CourtTimerWidget(
                  court: courtOrTeam,
                ) // ใช้ Widget แยกเพื่อลดการ Rebuild
              else
                const SizedBox(), // Spacer for reserve teams
              Text(
                isReserveTeam
                    ? courtIdentifier // Use the passed identifier for reserve teams
                    : 'สนาม ${courtIdentifier}', // FIX: แสดงชื่อสนามที่ถูกต้อง
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget สำหรับสร้างปุ่ม Pause ตรงกลาง
  Widget _buildCenterPauseButton(PlayingCourt court, {required bool isFull}) {
    // ตรวจสอบว่ากำลังเล่นอยู่หรือไม่
    bool isPlaying = court.status == CourtStatus.playing;

    return InkWell(
      onTap: () {
        if (isPlaying) {
          // ถ้ากำลังเล่นอยู่ กดหยุดได้เสมอ
          _showPauseOrEndGameDialog(court);
        } else if (isFull) {
          // ถ้ายังไม่เริ่ม จะเริ่มได้ก็ต่อเมื่อผู้เล่นเต็ม
          _startTimer(court);
        } else {
          // ถ้าผู้เล่นไม่เต็ม ให้แสดงข้อความ
          showDialogMsg(
            context,
            title: 'แจ้งเตือน',
            subtitle: 'ต้องมีผู้เล่นครบ 4 คนจึงจะเริ่มเกมได้',
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      // FIX: ขยาย tap target เป็น 48×48 ตาม Material guideline
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: isPlaying
              ? Colors.blueAccent
              : (isFull ? Colors.green : Colors.grey),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildReadyTeamCard(
    ReadyTeam team, {
    bool isReserve = false,
    String? title,
  }) {
    return Card(
      // --- FIX: ย้าย margin ไปที่ Card ---
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // ทำให้ child ถูกตัดตามขอบมนของ Card
      elevation: 4, // This is correct
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: isReserve ? Colors.blueGrey[700] : const Color(0xFF64646D),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- แถวผู้เล่นด้านบน ---
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPlayerSlot(team, 0), // ตำแหน่ง A
                      _buildPlayerSlot(team, 1), // ตำแหน่ง B
                    ],
                  ),
                ),

                // --- เส้นคั่นกลางพร้อมหมายเลขและไอคอนล็อก ---
                if (!isReserve)
                  _buildDividerWithNumber(team)
                else if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // --- แถวผู้เล่นด้านล่าง (สำหรับทีมสำรองอาจจะไม่มี) ---
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPlayerSlot(team, 2), // ตำแหน่ง C
                      _buildPlayerSlot(team, 3), // ตำแหน่ง D
                    ],
                  ),
                ),
              ],
            ),
          ),
          // --- NEW: ปุ่มลบสนามสำรอง (เคลียร์ผู้เล่น) ---
          // Positioned(
          //   top: 4,
          //   right: 4,
          //   child: InkWell(
          //     onTap: () {
          //       showDialogMsg(
          //         context,
          //         title: 'ลบทีมสำรอง',
          //         subtitle: 'คุณต้องการลบทีมสำรองนี้หรือไม่?',
          //         isWarning: true,
          //         btnLeft: 'ลบ',
          //         btnLeftBackColor: Colors.red,
          //         btnLeftForeColor: Colors.white,
          //         onConfirm: () => _clearReserveTeam(team),
          //       );
          //     },
          //     child: Container(
          //       padding: const EdgeInsets.all(4),
          //       decoration: BoxDecoration(
          //         color: Colors.black.withValues(alpha: 0.3),
          //         shape: BoxShape.circle,
          //       ),
          //       child: const Icon(Icons.close, color: Colors.white, size: 16),
          //     ),
          //   ),
          // ),
          // if (!isReserve) _buildDividerWithNumber(team), // ทีมสำรองไม่แสดงตัวเลขสนาม
          if (team.isLocked)
            Positioned.fill(
              child: InkWell(
                onTap: () {
                  showDialogMsg(
                    context,
                    title: 'ปลดล็อค',
                    subtitle: 'คุณต้องการปลดล็อคหรือไม่?',
                    isWarning: true,
                    btnLeft: 'ปลดล็อค',
                    btnLeftForeColor: const Color(0xFFFFFFFF),
                    btnLeftBackColor: const Color(0xFF0E9D7A),
                    // btnRight: 'หยุดชั่วคราว',
                    onConfirm: () {
                      setState(() => team.isLocked = !team.isLocked);
                    },
                    // onConfirmRight: () {
                    //   _pauseTimer(court);
                    // },
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.4,
                    ), // Overlay สีดำโปร่งแสง
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- NEW: ฟังก์ชันใหม่สำหรับสร้างเส้นคั่นกลาง ---
  Widget _buildDividerWithNumber(ReadyTeam team) {
    bool isFull = team.players.every((p) => p != null);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12.0,
      ), // FIX: เพิ่ม padding
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.white, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isFull)
                  InkWell(
                    onTap: () => setState(() => team.isLocked = !team.isLocked),
                    child: Icon(
                      team.isLocked ? Icons.lock : Icons.lock_open,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
          const Expanded(child: Divider(color: Colors.white, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildWaitingPlayersGrid(List<Player> playersToShow) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 12.0,
      children: playersToShow.map((player) {
        final isSelected = selectedPlayers.contains(player);
        final selectionOrder = isSelected
            ? selectedPlayers.indexOf(player) + 1
            : 0;
        final dynamic dragData = isSelected ? selectedPlayers : player;
        final isPaused = _pausedPlayerIds.contains(player.id);
        final isEnded = _endedPlayerIds.contains(player.id);

        // --- NEW: ถ้าผู้เล่นถูกหยุดเกม ให้แสดงผลแบบกดไม่ได้ (แต่กดค้างดู Profile ได้) ---
        if (isPaused || isEnded) {
          return GestureDetector(
            onTap: () {
              showDialogMsg(
                context,
                title: 'แจ้งเตือน',
                subtitle: 'ผู้เล่น ${player.name} ถูกหยุดเกมอยู่',
                btnLeft: 'ตกลง',
                onConfirm: () {},
              );
            },
            onLongPress: () {
              setState(() {
                _viewingPlayer = player;
              });
            },
            child: _buildPlayerAvatar(player),
          );
        }

        return RepaintBoundary(
          child: Draggable<Object>(
            key: ValueKey('waiting_${player.id}'),
            data: dragData,
            feedback: isSelected
                ? _buildGroupDragFeedback(selectedPlayers)
                : _buildPlayerAvatar(player, isDragging: true),
            childWhenDragging: Opacity(
              opacity: 0.5,
              child: _buildPlayerAvatar(player),
            ),
            onDragEnd: (details) {},
            child: GestureDetector(
              onTap: () => _onPlayerTap(player),
              onLongPress: () {
                setState(() {
                  _viewingPlayer = player;
                });
              },
              child: _buildPlayerAvatar(
                player,
                isSelected: isSelected,
                selectionOrder: selectionOrder,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGroupDragFeedback(List<Player> players) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(
          players.length > 3 ? 3 : players.length, // แสดงสูงสุด 3 คน
          (index) => Positioned(
            top: (index * 15).toDouble(),
            left: (index * 15).toDouble(),
            child: _buildPlayerAvatar(players[index], isDragging: true),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar(
    Player player, {
    bool isDragging = false,
    bool isSelected = false,
    int selectionOrder = 0,
    bool isPlaying = false, // NEW: รับค่า isPlaying
  }) {
    final isPaused = _pausedPlayerIds.contains(player.id); // NEW
    final isEnded = _endedPlayerIds.contains(player.id); // NEW

    Widget avatarContent = SizedBox(
      width: isPlaying ? 75 : 90,   // หดความกว้างลงเมื่ออยู่ในสนาม
      height: isPlaying ? 95 : 150, // ลดความสูงลงฮวบฮาบเพื่อรักษาพื้นที่รูปภาพ
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ใช้ PlayerAvatar ตัวเดียวจบ เพราะข้อมูลไปอยู่ข้างในแล้ว
          PlayerAvatar(player: player, isPlaying: isPlaying), // NEW: ส่งค่า isPlaying ไป

          // --- Layer 3: Overlay เมื่อถูกเลือก ---
          if (isSelected && !isDragging)
            Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.75),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  '$selectionOrder',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // --- NEW: ถ้าถูกหยุดเกม ให้แสดงเป็นสีเทา ---
    if (isPaused) {
      return Stack(
        children: [
          Opacity(
            opacity: 0.4, // จางลง
            child: avatarContent,
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pause, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      );
    }

    // --- NEW: ถ้าจบเกม ให้แสดงเป็นสีเทาเข้มและไอคอน ---
    if (isEnded) {
      return Stack(
        children: [
          Opacity(
            opacity: 0.3, // จางกว่า Pause
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.grey,
                BlendMode.saturation,
              ),
              child: avatarContent,
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      );
    }

    return avatarContent;
  }

  Widget _buildPlayerSlot(dynamic courtOrTeam, int slotIndex) {
    bool isLocked =
        (courtOrTeam is ReadyTeam && courtOrTeam.isLocked) ||
        (courtOrTeam is PlayingCourt && courtOrTeam.isLocked);
    Player? player = courtOrTeam.players[slotIndex];

    // ให้ถือว่าการอยู่ใน Slot (ทั้งสนามและสำรอง) ต้องย่อขนาดการ์ดเสมอ เพื่อไม่ให้รูปภาพโดนบีบหายไป
    bool isPlaying = true;

    return DragTarget<Object>(
      builder: (context, candidateData, rejectedData) {
        if (player != null) {
          final isSelected = selectedPlayers.contains(player);
          // --- REQUIREMENT 1: คำนวณลำดับ ---
          final selectionOrder = isSelected
              ? selectedPlayers.indexOf(player) + 1
              : 0;

          if (isLocked) return _buildPlayerAvatar(player, isPlaying: isPlaying); // NEW: ส่ง isPlaying
          return GestureDetector(
            onTap: () {
              if (isLocked) return; // ถ้าล็อกอยู่จะกดเลือกไม่ได้
              _onPlayerTap(player);
            },
            onLongPress: () {
              if (!isLocked) {
                setState(() {
                  _viewingPlayer = player;
                });
              }
            },
            child: RepaintBoundary(
              child: Draggable<Object>(
                key: ValueKey('slot_${player.id}'),
                data: isSelected ? selectedPlayers : player,
                maxSimultaneousDrags: isLocked ? 0 : 1,
                onDragEnd: (details) {
                  if (!details.wasAccepted) {
                    // --- FIX: ถ้าลากไปทิ้ง ให้คืนผู้เล่นกลับไปที่ Waiting List ---

                    setState(() {
                      if (isSelected) {
                        // กรณีลากเป็นกลุ่ม
                        final playersToReturn = List<Player>.from(
                          selectedPlayers,
                        );
                        
                        // --- FIX: ใช้ Collector เพื่อรวบรวมทีมที่ได้รับผลกระทบ ---
                        final Set<ReadyTeam> affectedTeams = {};
                        for (var p in playersToReturn) {
                          _removePlayerFromCurrentSlot(
                            p,
                            addToWaitingList: true,
                            affectedTeamsCollector: affectedTeams, // ส่ง Collector ไป
                          ); 
                        }
                        selectedPlayers.clear(); // เคลียร์ตัวเลือก
                        
                        // --- FIX: ยิง API อัปเดตทีเดียวต่อทีม ---
                        for (var team in affectedTeams) {
                           if (readyTeams.contains(team)) _createStagedMatch(team);
                           else if (reserveTeams.contains(team)) _createStagedMatch(team, isReserve: true);
                        }
                        
                      } else {
                        // กรณีลากคนเดียว (เหมือนเดิม)
                        // --- FIX: Use the centralized function for consistency ---
                        setState(() {
                          _removePlayerFromCurrentSlot(
                            player,
                            addToWaitingList: true,
                          );
                        });
                      }
                    });
                  }
                },
                feedback: isSelected
                    ? _buildGroupDragFeedback(selectedPlayers)
                    : _buildPlayerAvatar(player, isDragging: true, isPlaying: isPlaying), // NEW
                childWhenDragging: isSelected
                    ? _buildPlayerAvatar(player, isPlaying: isPlaying) // NEW
                    : _buildEmptySlot(),
                child: _buildPlayerAvatar(
                  player,
                  isSelected: isSelected,
                  selectionOrder: selectionOrder,
                  isPlaying: isPlaying, // NEW
                ),
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () {
            if (isLocked) return; // ถ้าล็อกอยู่ จะกดวางไม่ได้
            _placeSelectedPlayers(courtOrTeam);
          },
          child: _buildEmptySlot(
            isHighlighted: !isLocked && candidateData.isNotEmpty,
          ),
        );
      },
      onAcceptWithDetails: (details) {
        if (isLocked) return;
        // --- ตรวจสอบ Type ของข้อมูลที่ลากมา ---
        final data = details.data;
        setState(() {
          List<Player> playersToMove = [];
          if (data is Player) {
            playersToMove.add(data);
          } else if (data is List<Player>) {
            playersToMove.addAll(data);
          }
          // เรียกฟังก์ชันย้าย (ซึ่งตอนนี้เป็น Async API Call)
          _movePlayersToTeam(playersToMove, courtOrTeam);
          selectedPlayers.clear();
        });
      },
    );
  }

  Widget _buildEmptySlot({bool isHighlighted = false}) {
    return Container(
      width: 45,
      height: 45, // FIX: กำหนดความสูง
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.green.withValues(alpha: 0.5)
            : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'A', // อาจจะเปลี่ยนเป็น B, C, D ตามตำแหน่ง
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ฟังก์ชันสำหรับสลับการเปิด/ปิดเมนู
  void _toggleFabMenu() {
    if (_fabMenuOverlay == null) {
      _openFabMenu();
    } else {
      _closeFabMenu();
    }
  }

  // ฟังก์ชันสำหรับปิดเมนู
  void _closeFabMenu() {
    _fabMenuOverlay?.remove();
    setState(() {
      _fabMenuOverlay = null;
    });
  }

  // ฟังก์ชันสำหรับเปิดเมนู
  void _openFabMenu() {
    // หาตำแหน่งและขนาดของปุ่ม FAB
    final fabRenderBox =
        _fabKey.currentContext!.findRenderObject() as RenderBox;
    final fabPosition = fabRenderBox.localToGlobal(Offset.zero);
    final fabSize = fabRenderBox.size;

    _fabMenuOverlay = OverlayEntry(
      builder: (context) {
        // สร้าง Layer โปร่งแสงเต็มจอ เมื่อกดที่ Layer นี้จะปิดเมนู
        return Positioned.fill(
          child: GestureDetector(
            onTap: _closeFabMenu,
            child: Container(
              color: Colors.transparent,
              child: Stack(
                children: [
                  // วางตำแหน่งของเมนู
                  Positioned(
                    // จัดตำแหน่งให้อยู่เหนือปุ่ม FAB
                    bottom:
                        MediaQuery.of(context).size.height -
                        fabPosition.dy -
                        fabSize.height,
                    right:
                        MediaQuery.of(context).size.width -
                        fabPosition.dx -
                        fabSize.width,
                    child: _buildFabMenu(), // เรียกใช้ Widget เมนู
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // แสดง Overlay และอัปเดต State
    Overlay.of(context).insert(_fabMenuOverlay!);
    setState(() {});
  }

  // --- NEW: ฟังก์ชันสำหรับสร้าง UI ของเมนู ---
  Widget _buildFabMenu() {
    // สร้าง Widget ที่เป็นรายการเมนู
    Widget menuItem(String text, {VoidCallback? onTap, bool isEnabled = true}) {
      return InkWell(
        onTap: isEnabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              color: text == "จบการแข่งขัน"
                  ? Color(0xFFDB2C2C)
                  : isEnabled
                  ? Color(0xFF243F94)
                  : Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  const TextSpan(text: 'เข้าร่วมแล้ว '),
                  TextSpan(
                    text: '$_currentParticipants/$_maxParticipants',
                    style: const TextStyle(color: Colors.green),
                  ),
                  const TextSpan(text: ' คน'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'เวลา ${_formatSessionDuration(_sessionDuration)} น.',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const Divider(height: 1),
          menuItem(
            'สแกนเข้าร่วมเกม',
            onTap: () {
              _closeFabMenu(); // ปิดเมนู FAB ก่อน
              _showQrScannerDialog(); // แล้วค่อยเปิดหน้าต่างสแกน
            },
          ),
          const Divider(height: 1),
          menuItem(
            'จัดการรายชื่อ',
            onTap: () {
              _closeFabMenu();
              setState(() {
                _isRosterPanelVisible = !_isRosterPanelVisible;
              });
            },
          ),
          const Divider(height: 1),
          menuItem(
            'ดูผลรายงาน',
            isEnabled: true,
            onTap: () {
              _closeFabMenu();
              setState(() {
                _isReportPanelVisible = true;
                _isRosterPanelVisible = false; // ปิด Panel อื่น
                _viewingPlayer = null;
                _playerForExpenses = null;
                _reportRefreshKey++; // FIX: เพิ่มค่า Key เพื่อให้ ReportPanel โหลดข้อมูลใหม่
              });
            },
          ),
          const Divider(height: 1),
          !_isStartGame
              ? menuItem(
                  'เริ่มการแข่งขัน',
                  onTap: () {
                    showDialogMsg(
                      context,
                      title: 'ยืนยันการเริ่มเกม',
                      subtitle: 'เริ่มเกม ก๊วนแมวเหมียว',
                      btnLeftBackColor: Color(0xFF0E9D7A),
                      btnLeftForeColor: Color(0xFFFFFFFF),
                      btnRight: 'ยกเลิก',
                      btnRightBackColor: Color(0xFFFFFFFF),
                      btnRightForeColor: Color(0xFF0E9D7A),
                      onConfirm: () async {
                        _closeFabMenu();
                        // --- NEW: เรียก API เพื่อบันทึกเวลาเริ่มการแข่งขัน ---
                        try {
                          await ApiProvider().post(
                            '/gamesessions/${widget.id}/start-competition',
                          );
                          _fetchLiveState(); // โหลดข้อมูลใหม่ทันที
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
                  },
                )
              : menuItem(
                  'จบการแข่งขัน',
                  onTap: () {
                    _closeFabMenu();
                    showDialogMsg(
                      context,
                      title: 'ยืนยันการจบเกม',
                      subtitle: 'คุณต้องการจบเกม ก๊วนแมวเหมียว',
                      isWarning: true,
                      isSlideAction: true,
                      onConfirm: () {
                        showDialogMsg(
                          context,
                          title: 'ยืนยันการจบเกม',
                          subtitle: 'คุณได้จบเกม ก๊วนแมวเหมียว',
                          btnLeftBackColor: Color(0xFF0E9D7A),
                          btnLeftForeColor: Color(0xFFFFFFFF),
                          onConfirm: () async {
                            _closeFabMenu();
                            // --- NEW: เรียก API เพื่อจบการแข่งขัน ---
                            try {
                              await ApiProvider().post(
                                '/gamesessions/${widget.id}/end-competition',
                              );
                              if (mounted) context.pop(true);
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
                      },
                    );
                  },
                ),
        ],
      ),
    );
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
                                  '/gamesessions/${widget.id}/checkin',
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
                                  _fetchLiveState(); // Refresh data
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
}
