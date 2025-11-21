import 'dart:async';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/model/player.dart';
import 'package:badminton/component/player_avatar.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/widget/expense_panel.dart';
import 'package:flutter/material.dart';
import 'package:signalr_netcore/signalr_client.dart'; // 1. Import SignalR
import 'dart:convert'; // สำหรับ json decoding (ถ้าจำเป็น)
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum CourtStatus { waiting, playing, paused }

class PlayingCourt {
  final int courtNumber;
  int? matchId; // NEW: สำหรับเก็บ ID ของแมตช์ที่กำลังเล่น
  List<Player?> players = List.filled(4, null);
  CourtStatus status = CourtStatus.waiting;
  Duration elapsedTime = Duration.zero;
  bool isLocked = false;
  int gamesPlayedCount = 0; // FIX: เพิ่มตัวนับเกมในสนาม
  String identifier; // FIX: เพิ่มฟิลด์สำหรับเก็บชื่อสนามจริงๆ

  PlayingCourt({required this.courtNumber, required this.identifier});
}

class ReadyTeam {
  final int id;
  List<Player?> players = List.filled(4, null); // ผู้เล่น 4 คน
  int? stagedMatchId; // NEW: เก็บ ID ของแมตช์ที่จัดเตรียมไว้
  bool isLocked = false;

  ReadyTeam({required this.id});
}

extension PlayerFromJson on Player {
  static Player fromJson(Map<String, dynamic> json) {
    final participantId = json['participantId'];
    final participantType = json['participantType'];
    return Player(
      id: '${participantType}_$participantId', // สร้าง ID เฉพาะ เช่น "Member_123"
      name: json['nickname'] ?? 'N/A',
      imageUrl: json['profilePhotoUrl'] ?? '',
      level: null, // level (int) ไม่ได้ใช้แล้ว แต่ใส่ไว้เพื่อไม่ให้ error
      skillLevelName: json['skillLevelName'], // FIX: ดึงชื่อระดับจาก API
      skillLevelColor: json['skillLevelColor'], // FIX: ดึงสีจาก API
      skillLevelId: json['skillLevelId'], // NEW: ดึง skillLevelId มาด้วย
    );
  }
}
// จบส่วนของไฟล์ models.dart

class ManageGamePage extends StatefulWidget {
  final String id;
  const ManageGamePage({super.key, required this.id});

  @override
  State<ManageGamePage> createState() => _ManageGamePage();
}

class _ManageGamePage extends State<ManageGamePage> {
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
  // --- REMOVED: Timer? _liveStateTimer; ---
  // --- NEW: SignalR Hub Connection ---
  HubConnection? _hubConnection;

  Player? _viewingPlayer;
  // --- NEW: Debouncer for API calls ---
  final Map<int, Timer> _teamDebounceTimers = {}; // Key: team.id, Value: Timer

  Player? _playerForExpenses;
  bool _isStartGame = false;

  @override
  void initState() {
    super.initState();
    _fetchLiveState(); // 2. เรียกข้อมูลครั้งแรกเพื่อแสดงผลทันที
    _fetchSkillLevels(); // NEW: ดึงข้อมูลระดับมือเมื่อเข้าหน้า
    _initSignalR(); // 3. เริ่มการเชื่อมต่อ SignalR
  }

  @override
  void dispose() {
    _timers.forEach((key, timer) => timer.cancel());
    // --- REFACTORED: Leave group before stopping the connection ---
    if (_hubConnection != null) {
      // 4. บอก Server ว่าจะออกจากกลุ่มของ Session นี้
      _hubConnection!.invoke("LeaveGameSessionGroup", args: [widget.id]);
      // 5. ปิดการเชื่อมต่อ SignalR
      _hubConnection!.stop();
    }
    _teamDebounceTimers.forEach(
      (_, timer) => timer.cancel(),
    ); // ยกเลิก Debounce Timers
    super.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching live state: $e')),
        );
      }
    } finally {
      if (showLoading && mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW: ฟังก์ชันกลางสำหรับประมวลผลข้อมูล Live State ---
  void _processLiveStateData(Map<String, dynamic> liveState) {
    if (!mounted) return;

    // --- FIX: หยุด Timer เก่าทั้งหมดก่อนที่จะสร้างใหม่ ---
    _timers.forEach((_, timer) => timer.cancel());

    // 1. แปลงข้อมูล WaitingPool
    final List<Player>
      newWaitingPlayers = (liveState['waitingPool'] as List).map((p) {
        return PlayerFromJson.fromJson(p);
        // --- NEW: เพิ่มข้อมูล genderName และ isCheckedIn เข้าไปใน Player object ---
        // final player = PlayerFromJson.fromJson(p);
        // player.genderName = p['genderName'];
        // player.isCheckedIn = p['checkinTime'] != null;
      }).toList();

    // --- FIX: สร้าง Set ของ ID ผู้เล่นที่รออยู่แล้ว เพื่อป้องกันการเพิ่มซ้ำ ---
    final Set<String> waitingPlayerIds =
        newWaitingPlayers.map((p) => p.id).toSet();

    // --- NEW: อ่านข้อมูล StagedMatches จาก API ---
    final List<dynamic> stagedMatchesFromApi =
        liveState['stagedMatches'] ?? [];
    final List<StagedMatchDto> stagedMatches = stagedMatchesFromApi
        .map((m) => StagedMatchDto.fromJson(m))
        .toList();

    // 2. แปลงข้อมูล Courts
    final List<CourtStatusDto> courtStatuses = (liveState['courts'] as List)
        .map((c) {
      return CourtStatusDto.fromJson(c);
    }).toList();

    // 3. สร้าง playingCourts และ readyTeams ใหม่
    List<PlayingCourt> newPlayingCourts = [];
    List<ReadyTeam> newReadyTeams = [];
    List<ReadyTeam> newReserveTeams = []; // NEW: สร้างทีมสำรองไปพร้อมกัน

    // --- FIX: เก็บสถานะทีมสำรองเก่าไว้ก่อน เพื่อรักษาทีมที่ยังจัดไม่เสร็จ ---
    final List<ReadyTeam> oldReserveTeams = List.from(reserveTeams);

    for (var courtStatus in courtStatuses) {
      final court = PlayingCourt(
        courtNumber: int.tryParse(courtStatus.courtIdentifier) ?? 0,
        identifier: courtStatus.courtIdentifier, // FIX: เก็บชื่อสนาม
      );

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
          _timers[court.courtNumber] =
              Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) {
              setState(() {
                // หา court ที่ถูกต้องใน list ปัจจุบันเพื่ออัปเดต
                playingCourts
                    .firstWhere((c) => c.courtNumber == court.courtNumber)
                    .elapsedTime += const Duration(
                  seconds: 1,
                );
              });
            }
          });
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
              final player = Player(
                id: '${pInMatch.participantType}_${pInMatch.participantId}',
                name: pInMatch.nickname,
                imageUrl: pInMatch.profilePhotoUrl,
                skillLevelName: pInMatch.skillLevelName,
                skillLevelColor: pInMatch.skillLevelColor,
                skillLevelId: pInMatch.skillLevelId,
              );
              matchPlayers[playerIndex] = player;

              final playerId =
                  '${pInMatch.participantType}_${pInMatch.participantId}';
              if (!waitingPlayerIds.contains(playerId)) {
                newWaitingPlayers.add(
                  PlayerFromJson.fromJson(pInMatch.toPlayerJson()),
                );
                waitingPlayerIds.add(playerId);
              }
              playerIndex++;
            }
          }
        }
        court.players = matchPlayers;
        // --- FIX: Sync players to the corresponding ReadyTeam as well ---
        // Since we add a newTeam for every court, the index will always match.
        if (newPlayingCourts.length < newReadyTeams.length) {
          newReadyTeams[newPlayingCourts.length].players =
              List.from(matchPlayers);
        }
      }
      newPlayingCourts.add(court);

      // --- FIX: สร้างทีมสำรองใหม่โดยดึงข้อมูลจาก StagedMatches ที่ไม่มี courtIdentifier ---
      final newReserveTeam = ReadyTeam(id: newReserveTeams.length + 1);
      newReserveTeams.add(newReserveTeam);
    }

    // --- FIX: วนลูป StagedMatches ทั้งหมดเพื่อจัดลง ReadyTeam หรือ ReserveTeam ---
    for (var stagedMatch in stagedMatches) {
      final teamPlayers = [...stagedMatch.teamA, ...stagedMatch.teamB];
      final courtId = stagedMatch.courtIdentifier;

      if (courtId != null) {
        // ตรวจสอบว่าเป็นทีมสำรองหรือไม่ (มีเครื่องหมาย '-' นำหน้า)
        if (courtId.startsWith('-')) {
          final reserveIndex = int.tryParse(courtId.substring(1)) ?? 0;
          if (reserveIndex > 0 && reserveIndex <= newReserveTeams.length) {
            final targetReserveTeam = newReserveTeams[reserveIndex - 1];
            targetReserveTeam.stagedMatchId = stagedMatch.stagedMatchId;
            for (int j = 0; j < teamPlayers.length; j++) {
              if (j < targetReserveTeam.players.length) {
                final player = PlayerFromJson.fromJson(
                  teamPlayers[j].toPlayerJson(),
                );
                targetReserveTeam.players[j] = player;
                if (!waitingPlayerIds.contains(player.id)) {
                  newWaitingPlayers.add(player);
                  waitingPlayerIds.add(player.id);
                }
              }
            }
          }
        } else {
          // ถ้าเป็นสนามปกติ (courtIdentifier เป็นค่าบวก)
          final courtIndex = newPlayingCourts.indexWhere(
            (c) => c.identifier == courtId,
          );
          if (courtIndex != -1) {
            final targetReadyTeam = newReadyTeams[courtIndex];
            targetReadyTeam.stagedMatchId = stagedMatch.stagedMatchId;
            for (int i = 0; i < teamPlayers.length; i++) {
              if (i < targetReadyTeam.players.length) {
                final player = PlayerFromJson.fromJson(
                  teamPlayers[i].toPlayerJson(),
                );
                targetReadyTeam.players[i] = player;
                newPlayingCourts[courtIndex].players[i] =
                    player; // อัปเดต UI สนามด้วย
                if (!waitingPlayerIds.contains(player.id)) {
                  newWaitingPlayers.add(player);
                  waitingPlayerIds.add(player.id);
                }
              }
            }
          }
        }
      }
    }
    // --- FIX: นำผู้เล่นจากทีมสำรองเก่าที่ยังจัดไม่เสร็จกลับมาใส่ ---
    for (int i = 0;
        i < oldReserveTeams.length && i < newReserveTeams.length;
        i++) {
      // ถ้่าทีมใหม่ยังว่าง และทีมเก่ามีผู้เล่นอยู่ (แต่ไม่ครบ 4)
      if (newReserveTeams[i].players.every((p) => p == null) &&
          oldReserveTeams[i].players.any((p) => p != null)) {
        newReserveTeams[i].players = List.from(oldReserveTeams[i].players);
      }
    }

    setState(() {
      waitingPlayers = newWaitingPlayers;
      playingCourts = newPlayingCourts;
      reserveTeams = newReserveTeams; // NEW: อัปเดตทีมสำรอง
      readyTeams = newReadyTeams; // อัปเดต readyTeams ให้ตรงกับ playingCourts
      _groupName = liveState['groupName']; // หากมีข้อมูลชื่อก๊วนใน API
    });
  }

  // --- NEW: ฟังก์ชันสำหรับขอคำแนะนำการจัดคู่ ---
  Future<void> _suggestMatchByWaitTime() async {
    try {
      final response = await ApiProvider().get(
        '/gamesessions/${widget.id}/suggest-matches?criteria=ByWaitTime',
      );
      final suggestions = response['data'] as List;

      if (suggestions.isEmpty || !mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีผู้เล่นพอให้จัดคู่')),
        );
        return;
      }

      // แสดง Dialog พร้อมคู่ที่แนะนำ (ใช้คู่แรกที่ได้มา)
      final firstSuggestion = suggestions.first;
      _showSuggestionDialog(firstSuggestion);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ไม่สามารถจัดคู่ได้: $e')));
      }
    }
  }

  // --- NEW: ฟังก์ชันสำหรับแสดง Dialog คู่ที่แนะนำ ---
  void _showSuggestionDialog(Map<String, dynamic> suggestion) {
    final List<Player> teamA = (suggestion['teamA'] as List)
        .map((p) => PlayerFromJson.fromJson(p))
        .toList();
    final List<Player> teamB = (suggestion['teamB'] as List)
        .map((p) => PlayerFromJson.fromJson(p))
        .toList();

    showDialogMsg(
      context,
      title: 'คู่ที่แนะนำ (ตามเวลารอ)',
      subtitle:
          'ทีม A: ${teamA[0].name}, ${teamA[1].name}\nทีม B: ${teamB[0].name}, ${teamB[1].name}',
      btnLeft: 'ยืนยันและเริ่มเกม',
      btnRight: 'ยกเลิก',
      onConfirm: () {
        // หาสนามที่ว่างสนามแรก
        final firstEmptyCourt = playingCourts.firstWhere(
          (c) => c.players.every((p) => p == null),
        );

        // ย้ายผู้เล่นลงสนามและเริ่มเกม
        setState(() {
          firstEmptyCourt.players = [teamA[0], teamA[1], teamB[0], teamB[1]];
          waitingPlayers.removeWhere(
            (p) =>
                teamA.any((ap) => ap.id == p.id) ||
                teamB.any((bp) => bp.id == p.id),
          );
        });
        _startTimer(firstEmptyCourt);
      },
    );
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
      // --- REFACTORED: Send all 4 player slots, including nulls for empty slots ---
      List<Map<String, dynamic>?> teamAPlayers = team.players.sublist(0, 2).map(
        (p) {
          if (p == null) return null; // ส่ง null ถ้าช่องว่าง
          final parts = p!.id.split('_');
          return {"type": parts[0], "id": int.parse(parts[1])};
        },
      ).toList();

      List<Map<String, dynamic>?> teamBPlayers = team.players.sublist(2, 4).map(
        (p) {
          if (p == null) return null; // ส่ง null ถ้าช่องว่าง
          final parts = p!.id.split('_');
          return {"type": parts[0], "id": int.parse(parts[1])};
        },
      ).toList();

      // --- FIX: เพิ่ม courtIdentifier เข้าไปใน DTO ---
      final Map<String, dynamic> dto = {
        "teamA": teamAPlayers,
        "teamB": teamBPlayers,
      };
      if (isReserve) {
        final reserveIndex = reserveTeams.indexOf(team);
        dto['courtIdentifier'] = '-${reserveIndex + 1}';
      } else {
        final teamIndex = readyTeams.indexOf(team);
        if (teamIndex != -1 && teamIndex < playingCourts.length) {
          final courtIdentifier = playingCourts[teamIndex].identifier;
          dto['courtIdentifier'] = courtIdentifier;
        }
      }

      final response = await ApiProvider().post(
        '/gamesessions/${widget.id}/staged-matches',
        data: dto,
      );

      setState(() {
        team.stagedMatchId = response['data']['matchId'];
      });
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error creating staged match: $e')),
        // );
      }
    }
  }

  // --- NEW: Debounced function for creating staged matches ---
  void _debouncedCreateStagedMatch(ReadyTeam team, {bool isReserve = false}) {
    // If there's an existing timer for this team, cancel it.
    if (_teamDebounceTimers[team.id]?.isActive ?? false) {
      _teamDebounceTimers[team.id]!.cancel();
    }

    // Start a new timer. The API call will only be made after the duration has passed
    // without any new calls for the same team.
    _teamDebounceTimers[team.id] = Timer(const Duration(milliseconds: 800), () {
      // The user has stopped making changes for this team, now make the API call.
      if (mounted) {
        _createStagedMatch(team, isReserve: isReserve);
      }
    });
  }

  // --- 2. TIMER LOGIC: ฟังก์ชันสำหรับจัดการเวลา ---
  void _startTimer(PlayingCourt court) {
    // --- FIX: ตรวจสอบว่ามี stagedMatchId หรือยัง ---
    final teamIndex = playingCourts.indexOf(court);
    if (teamIndex == -1 || readyTeams[teamIndex].stagedMatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ยังไม่ได้จัดทีมบนเซิร์ฟเวอร์ โปรดลองลากผู้เล่นออกแล้วใส่ใหม่',
          ),
        ),
      );
      return;
    }
    _timers[court.courtNumber]?.cancel();
    setState(() {
      court.status = CourtStatus.playing;
      court.isLocked = true; // <<< NEW: ล็อกสนามเมื่อเกมเริ่ม
    });
    // --- REFACTORED: เรียก API เพื่อเริ่มเกมจาก Staged Match ---
    _callStartMatchAPI(court);

    _timers[court.courtNumber] = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
      if (mounted) {
        setState(() {
          court.elapsedTime += const Duration(seconds: 1);
        });
      }
    });
  }

  void _pauseTimer(PlayingCourt court) {
    _timers[court.courtNumber]?.cancel();
    if (mounted) {
      setState(() {
        court.status = CourtStatus.paused;
        court.isLocked = false; // ปลดล็อกสนามเพื่อให้เปลี่ยนผู้เล่นได้
      });
    }
  }

  Future<void> _callStartMatchAPI(PlayingCourt court) async {
    // หา ReadyTeam ที่อยู่ใต้สนามนี้
    final teamIndex = playingCourts.indexOf(court);
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting match: $e')));
      }
    }
  }

  // --- NEW: ฟังก์ชันสำหรับย้ายทีมสำรองลงสนามที่ว่าง ---
  void _autoAssignReserveTeamToCourt(PlayingCourt court) {
    ReadyTeam? readyReserveTeam;
    // ค้นหาทีมสำรองทีมแรกที่จัดผู้เล่นครบ 4 คนและไม่ได้ถูกล็อก
    for (var team in reserveTeams) {
      if (team.players.every((p) => p != null) && !team.isLocked) {
        readyReserveTeam = team;
        break;
      }
    }

    if (readyReserveTeam != null) {
      setState(() {
        // 1. หา ReadyTeam ที่ผูกกับสนามหลัก
        final courtIndex = playingCourts.indexOf(court);
        if (courtIndex == -1) return; // หากไม่เจอสนาม ให้หยุดทำงาน
        final mainCourtTeam = readyTeams[courtIndex];

        // 2. ย้ายผู้เล่นจากทีมสำรองไปยังทีมของสนามหลัก และอัปเดต UI
        mainCourtTeam.players = List.from(readyReserveTeam!.players);
        court.players = List.from(readyReserveTeam.players);

        // 3. ล้างข้อมูลทีมสำรองเดิม
        readyReserveTeam.players = List.filled(4, null);
        readyReserveTeam.isLocked = false;

        // 4. ยิง API เพื่ออัปเดตทั้งสองทีม
        // 4.1 สร้าง Staged Match ใหม่สำหรับสนามหลัก
        _debouncedCreateStagedMatch(mainCourtTeam);
        // 4.2 ล้าง Staged Match ของทีมสำรองบนเซิร์ฟเวอร์
        _debouncedCreateStagedMatch(readyReserveTeam, isReserve: true);

        // 5. เริ่มเกมในสนาม (หลังจากที่ API ถูกยิงไปแล้ว)
        _startTimer(court);
      });
    }
  }

  void _endGame(PlayingCourt court) async {
    _timers[court.courtNumber]?.cancel();

    // --- NEW: Call API to end match ---
    if (court.matchId != null) {
      try {
        await ApiProvider().put('/matches/${court.matchId}/end');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error ending match: $e')));
        }
      }
    }

    if (mounted) {
      setState(() {
        // --- ส่วนที่เพิ่มเข้ามา ---
        // 1. วนลูปเพื่อย้ายผู้เล่นทุกคนในสนามกลับไปที่ waitingPlayers list
        for (var player in court.players) {
          if (player != null) {
            // คืนผู้เล่นกลับไปที่ List ผู้เล่นที่รอ
            // --- FIX: ใช้ ID ในการตรวจสอบเพื่อป้องกันการเพิ่มซ้ำ ---
            final bool isAlreadyInWaitingList = waitingPlayers.any(
              (p) => p.id == player.id,
            );
            if (!isAlreadyInWaitingList) {
              waitingPlayers.add(player);
            }
            // ถ้าผู้เล่นคนนี้เคยถูกเลือกไว้ ให้เอาออกจาก selected list ด้วย
            selectedPlayers.remove(player);
          }
        }

        // --- ส่วนโค้ดเดิมที่ปรับปรุง ---
        // 2. รีเซ็ตสถานะทั้งหมดของสนาม
        court.status = CourtStatus.waiting;
        court.isLocked = false;
        court.gamesPlayedCount += 1; // FIX: เพิ่มจำนวนเกมที่เล่นในสนามนี้
        court.elapsedTime = Duration.zero;

        // 3. เคลียร์ผู้เล่นทั้งหมดออกจากสนาม
        court.players = List.filled(4, null);

        // --- FIX: เคลียร์ผู้เล่นออกจาก ReadyTeam ที่คู่กันด้วย ---
        final teamIndex = playingCourts.indexOf(court);
        if (teamIndex != -1) {
          readyTeams[teamIndex].players = List.filled(4, null);
          readyTeams[teamIndex].stagedMatchId =
              null; // เคลียร์ ID ของ Staged Match ด้วย
          // --- NEW: Call API to clear the staged match on the server ---
          _createStagedMatch(readyTeams[teamIndex]);
        }

        // NEW: ลองจัดทีมสำรองลงสนามที่ว่างทันที
        _autoAssignReserveTeamToCourt(court);
      });
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

  // ... ใน _ManageGamePageState
  void _placeSelectedPlayers(dynamic courtOrTeam) {
    setState(() {
      if (selectedPlayers.isEmpty) return;

      // 1. หา Target Team ที่จะวางผู้เล่นลงไป
      ReadyTeam? targetTeam;
      // 2. ย้ายผู้เล่นที่เลือกไว้ (selectedPlayers) ไปยัง targetTeam
      final playersToMove = List<Player>.from(selectedPlayers);
      selectedPlayers.clear(); // เคลียร์ตัวเลือกทันที
      _movePlayersToTeam(playersToMove, courtOrTeam);
    });
  }

  // --- REFACTORED: Centralized logic for moving players (แก้ไขเพื่อความมั่นคง) ---
  void _movePlayersToTeam(
    List<Player> playersToMove,
    dynamic targetCourtOrTeam,
  ) {
    ReadyTeam? targetTeam;
    if (targetCourtOrTeam is PlayingCourt) {
      final teamIndex = playingCourts.indexOf(targetCourtOrTeam);
      if (teamIndex != -1) targetTeam = readyTeams[teamIndex];
    } else if (targetCourtOrTeam is ReadyTeam) {
      targetTeam = targetCourtOrTeam;
    }

    if (targetTeam == null || targetTeam.isLocked) return;

    // *** NEW FIX: หาตำแหน่งว่างทั้งหมดก่อนเริ่มวาง ***
    List<int> emptySlots = [];
    for (int i = 0; i < 4; i++) {
      if (targetTeam!.players[i] == null) {
        emptySlots.add(i);
      }
    }

    // --- Logic to place players and handle overflow ---
    for (var player in playersToMove) {
      // 1. ตรวจสอบว่าผู้เล่นคนนี้อยู่ในทีมเป้าหมายอยู่แล้วหรือไม่
      if (targetTeam.players.any((p) => p != null && p.id == player.id)) {
        continue; // ถ้าอยู่ในทีมอยู่แล้ว ไม่ต้องทำอะไร
      }

      // 2. ถ้ามีช่องว่างเหลือ
      if (emptySlots.isNotEmpty) {
        // 2.1 นำออกจากตำแหน่งเก่า (ไม่ว่าจะเป็นสนามอื่นหรือ Waiting List)
        // ต้องเอาออกจากที่เดิมก่อนเพื่อไม่ให้เกิดการซ้ำซ้อน
        _removePlayerFromCurrentSlot(player, addToWaitingList: false);

        // 2.2 วางผู้เล่นลงใน Slot ว่างตัวแรกที่หาเจอ
        int slotIndexToUse = emptySlots.removeAt(0); // เอา index ตัวแรกออก
        targetTeam.players[slotIndexToUse] = player;
      } else {
        // 3. ทีมเต็ม (4 คน) แล้ว ให้คืนผู้เล่นคนนี้กลับไปที่ Waiting List
        // ผู้เล่นที่ถูกลากมาจากสนามอื่นจะถูก _removePlayerFromCurrentSlot จัดการแล้ว
        // แต่ผู้เล่นที่ถูกเลือกมาจาก Waiting List ต้องถูกจัดการที่นี่
        _addPlayerToWaitingList(player);
      }
    }

    // 4. Sync players from ReadyTeam to PlayingCourt for UI update
    if (targetCourtOrTeam is PlayingCourt) {
      final teamIndex = readyTeams.indexOf(targetTeam);
      if (teamIndex != -1) {
        playingCourts[teamIndex].players = List.from(targetTeam.players);
      }
    }

    // 5. Call API to update the staged match for the destination team
    if (readyTeams.contains(targetTeam)) {
      _debouncedCreateStagedMatch(targetTeam);
    } else if (reserveTeams.contains(targetTeam)) {
      _debouncedCreateStagedMatch(targetTeam, isReserve: true);
    }
  }

  // --- NEW: Centralized function to remove a player from their current spot ---
  void _removePlayerFromCurrentSlot(
    Player playerToRemove, {
    bool addToWaitingList = false,
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
        // If the team was full, it's not anymore, so we need to update the staged match
        // --- REFACTORED: Call API to update the state ---
        if (readyTeams.contains(readyTeam)) {
          _debouncedCreateStagedMatch(readyTeam);
        } else if (reserveTeams.contains(readyTeam)) {
          _debouncedCreateStagedMatch(readyTeam, isReserve: true);
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
          _debouncedCreateStagedMatch(reserveTeam, isReserve: true);
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เลือกผู้เล่นได้สูงสุด 4 คน'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
  }

  // --- NEW: ฟังก์ชันสำหรับสลับตำแหน่งผู้เล่น 2 คน ---
  void _swapPlayers(Player player1, Player player2) {
    ReadyTeam? team1;
    int? slot1;
    ReadyTeam? team2;
    int? slot2;

    // 1. ค้นหาตำแหน่งของผู้เล่นทั้งสองคน
    final allTeams = [...readyTeams, ...reserveTeams];
    for (var team in allTeams) {
      for (int i = 0; i < team.players.length; i++) {
        if (team.players[i] == player1) {
          team1 = team;
          slot1 = i;
        }
        if (team.players[i] == player2) {
          team2 = team;
          slot2 = i;
        }
      }
    }

    // 2. ถ้าเจอตำแหน่งครบทั้งสองคน ให้ทำการสลับ
    if (team1 != null && slot1 != null && team2 != null && slot2 != null) {
      // สลับตำแหน่งใน model
      team1.players[slot1] = player2;
      team2.players[slot2] = player1;

      // 3. อัปเดต UI ของ PlayingCourt ถ้าจำเป็น
      _syncReadyTeamToPlayingCourt(team1);
      if (team1 != team2) {
        _syncReadyTeamToPlayingCourt(team2);
      }

      // 4. ยิง API เพื่ออัปเดตเซิร์ฟเวอร์
      _debouncedCreateStagedMatch(
        team1,
        isReserve: reserveTeams.contains(team1),
      );
      if (team1 != team2) {
        _debouncedCreateStagedMatch(
          team2,
          isReserve: reserveTeams.contains(team2),
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

  void _removePlayerFromCourt(dynamic courtOrTeam, int slotIndex) {
    setState(() {
      Player? playerToRemove = courtOrTeam.players[slotIndex];
      // --- FIX: หา ReadyTeam ที่เกี่ยวข้องก่อนที่จะลบผู้เล่น ---
      final teamIndex = (courtOrTeam is PlayingCourt)
          ? playingCourts.indexOf(courtOrTeam)
          : -1;

      if (playerToRemove != null) {
        // นำผู้เล่นออกจากสนาม
        courtOrTeam.players[slotIndex] = null;

        // --- FIX: ตรวจสอบและนำผู้เล่นออกจาก ReadyTeam ที่คู่กันด้วย ---
        // แก้ไขให้ทำงานได้ถูกต้องแม้ courtOrTeam จะไม่ใช่ PlayingCourt โดยตรง
        if (courtOrTeam is PlayingCourt) {
          final courtIndex = playingCourts.indexOf(courtOrTeam);
          if (courtIndex != -1 &&
              readyTeams[courtIndex].players.length > slotIndex) {
            readyTeams[courtIndex].players[slotIndex] = null;
          }
        }

        // --- FIX: เพิ่มการตรวจสอบและนำออกจาก readyTeams โดยตรง ---
        // กรณีที่ผู้เล่นถูกลากออกจาก ReadyTeam (ซึ่งไม่ควรเกิดขึ้น แต่ป้องกันไว้)
        if (teamIndex != -1 &&
            readyTeams[teamIndex].players.length > slotIndex) {
          readyTeams[teamIndex].players[slotIndex] = null; //
        }

        // คืนผู้เล่นกลับไปที่ List ผู้เล่นที่รอ
        if (!waitingPlayers.contains(playerToRemove)) {
          waitingPlayers.add(playerToRemove);
        }
        // ถ้าผู้เล่นคนนี้ถูกเลือกอยู่ ให้เอาออกจาก List ที่เลือกด้วย
        selectedPlayers.remove(playerToRemove);

        // --- FIX: ถ้าเป็นการนำผู้เล่นออกจากทีมสำรอง ให้เรียก API อัปเดต ---
        if (reserveTeams.contains(courtOrTeam)) {
          // การเรียก API ที่นี่จะทำให้เซิร์ฟเวอร์รู้ว่าทีมนี้ไม่ครบแล้ว
          // และจะถูกลบออกจาก stagedMatches ในการเรียก live-state ครั้งถัดไป
          _createStagedMatch(courtOrTeam, isReserve: true);
        }
      }
    });
  }

  // --- NEW: ฟังก์ชันสำหรับลบผู้เล่นออกจากทีมโดยใช้ object ของ Player ---
  void _removePlayerFromCourtByPlayer(dynamic courtOrTeam, Player player) {
    // หา index ของผู้เล่นในทีม
    final index = courtOrTeam.players.indexOf(player);
    if (index != -1) {
      // ถ้าเจอ ให้เรียกฟังก์ชันเดิมที่ลบจาก index
      _removePlayerFromCourt(courtOrTeam, index);
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

    return Scaffold(
      appBar: AppBarSubMain(title: 'จัดการก๊วน - $_groupName'),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildSectionTitle('สนาม'), // เปลี่ยนชื่อ Section ให้สั้นลง
                const SizedBox(height: 8),
                _buildSyncedCourtsList(), // Widget หลักที่แสดงสนามทั้งหมด
                _buildReserveTeamsList(), // NEW: ส่วนแสดงทีมสำรอง
                const SizedBox(height: 24),
                _buildSectionTitle(
                  'ผู้เล่นที่รอ',
                ), // เปลี่ยนชื่อ Section ให้สั้นลง
                const SizedBox(height: 8),
                _buildWaitingPlayersGrid(
                  trulyWaitingPlayers,
                ), // FIX: ใช้ List ที่กรองแล้ว
              ],
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
              // ส่ง callback ไปให้ Panel เพื่อให้มันสั่งปิดตัวเองได้
              onClose: () {
                setState(() {
                  _isRosterPanelVisible = false;
                });
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
              onClose: () {
                setState(() {
                  _playerForExpenses = null; // สั่งปิด Expense Panel
                });
              },
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: 20,
            right: _isRosterPanelVisible
                ? 375
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
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  child: _buildCourtCard(
                    PlayingCourt(
                      courtNumber: index,
                      identifier: 'ทีมสำรอง ${index + 1}',
                    ), // Pass identifier here
                    reserveTeam: reserveTeams[index],
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
          if (!isReserveTeam) _buildCenterPauseButton(court, isFull: isFull),
          if (court.status == CourtStatus.playing)
            Positioned.fill(
              child: InkWell(
                onTap: () {
                  if (court.status == CourtStatus.playing) {
                    _showPauseOrEndGameDialog(court);
                  } else if (isFull) {
                    _startTimer(court);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ต้องมีผู้เล่นครบ 4 คนจึงจะเริ่มเกมได้'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
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
          // --- แถวควบคุมด้านบนสุด ---
          if (!isReserveTeam && courtOrTeam is PlayingCourt)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.remove_circle_outline, color: Colors.white),
                    SizedBox(width: 3),
                    Icon(
                      Icons.sports_tennis_sharp,
                      color: Colors.white,
                    ), // ใช้ไอคอนเทนนิสแทนลูกแบด
                    SizedBox(width: 3),
                    Icon(Icons.add_circle_outline, color: Colors.white),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.8)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${courtOrTeam.gamesPlayedCount}', // FIX: แสดงจำนวนเกมที่เล่นในสนามนี้
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          else
            const SizedBox(height: 30), // Spacer for reserve teams
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
                Text(
                  _formatDuration(courtOrTeam.elapsedTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ต้องมีผู้เล่นครบ 4 คนจึงจะเริ่มเกมได้'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        // ใช้ Icon แทน Text เพื่อความสวยงาม
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: isPlaying
              ? Colors.blueAccent
              : (isFull ? Colors.green : Colors.grey),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildReadyTeamCard(ReadyTeam team, {bool isReserve = false}) {
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
                if (!isReserve) _buildDividerWithNumber(team),

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
                    color: Colors.white.withOpacity(
                      0.4,
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

        return Draggable<Object>(
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
  }) {
    return SizedBox(
      width: 90,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PlayerAvatar(player: player),

          // --- Layer 3: Overlay เมื่อถูกเลือก ---
          if (isSelected && !isDragging)
            Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.75),
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
                        color: Colors.black.withOpacity(0.4),
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
  }

  Widget _buildPlayerSlot(dynamic courtOrTeam, int slotIndex) {
    bool isLocked =
        (courtOrTeam is ReadyTeam && courtOrTeam.isLocked) ||
        (courtOrTeam is PlayingCourt && courtOrTeam.isLocked);
    Player? player = courtOrTeam.players[slotIndex];

    return DragTarget<Object>(
      builder: (context, candidateData, rejectedData) {
        if (player != null) {
          final isSelected = selectedPlayers.contains(player);
          // --- REQUIREMENT 1: คำนวณลำดับ ---
          final selectionOrder = isSelected
              ? selectedPlayers.indexOf(player) + 1
              : 0;

          if (isLocked) return _buildPlayerAvatar(player);
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
            child: Draggable<Object>(
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
                      for (var p in playersToReturn) {
                        _removePlayerFromCurrentSlot(
                          p,
                          addToWaitingList: true,
                        ); // นำออกจากที่เดิมและเพิ่มกลับไปที่ Waiting List
                      }
                      selectedPlayers.clear(); // เคลียร์ตัวเลือก
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
                  : _buildPlayerAvatar(player, isDragging: true),
              childWhenDragging: isSelected
                  ? _buildPlayerAvatar(player) // แสดงตัวเดิมไว้ถ้าลากกลุ่ม
                  : _buildEmptySlot(),
              child: _buildPlayerAvatar(
                player,
                isSelected: isSelected,
                selectionOrder: selectionOrder,
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
            ? Colors.green.withOpacity(0.5)
            : Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'A', // อาจจะเปลี่ยนเป็น B, C, D ตามตำแหน่ง
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
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
              color: isEnabled ? Color(0xFF243F94) : Colors.grey[400],
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
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: 'เข้าร่วมแล้ว '),
                  TextSpan(
                    text: '62/70',
                    style: TextStyle(color: Colors.green),
                  ),
                  TextSpan(text: ' คน'),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'เวลา 00:00:00 น.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
          menuItem('ดูผลรายงาน', isEnabled: true), // ตัวอย่างปุ่มที่กดไม่ได้
          const Divider(height: 1),
          menuItem('จัดคิวแบบ fix สนาม', onTap: () {}),
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
                      onConfirm: () {
                        _closeFabMenu();
                        setState(() {
                          _isStartGame = true;
                        });
                      },
                    );
                  },
                )
              : menuItem(
                  'จบการแข่งขัน',
                  onTap: () {
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
                          onConfirm: () {
                            _closeFabMenu();
                            context.go('/history-organizer');
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(response['message']),
                                    ),
                                  );
                                  _fetchLiveState(); // Refresh data
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
}

// --- FIX: เพิ่ม Model สำหรับ Roster Player ---
class RosterPlayer {
  final int no;
  final String nickname;
  final String fullName;
  final String gender;
  int skillLevel;
  bool isChecked;
  final int participantId; // ID ของผู้เล่น (user or guest)
  final String participantType; // "user" or "guest"

  RosterPlayer({
    required this.no,
    required this.nickname,
    required this.fullName,
    required this.gender,
    required this.skillLevel,
    this.isChecked = false,
    required this.participantId,
    required this.participantType,
  });

  // --- NEW: เพิ่ม factory constructor fromJson ---
  factory RosterPlayer.fromJson(Map<String, dynamic> json, int index) {
    return RosterPlayer(
      no: index,
      nickname: json['nickname'] ?? 'N/A',
      fullName: json['fullName'] ?? json['nickname'],
      gender: json['gender'] ?? 'N/A',
      skillLevel: json['skillLevelId'] ?? 1, // FIX: ใส่ค่า default ป้องกัน null
      isChecked:
          json['isCheckedIn'] ??
          (json['checkinTime'] !=
              null), // FIX: ตรวจสอบ isCheckedIn ก่อน ถ้าไม่มีให้ดูที่ checkinTime
      participantId: json['participantId'],
      participantType: json['participantType'],
    );
  }
}

// --- NEW: เพิ่ม Model สำหรับข้อมูลจาก API ---
class CourtStatusDto {
  final String courtIdentifier;
  final CurrentlyPlayingMatchDto? currentMatch;

  CourtStatusDto({required this.courtIdentifier, this.currentMatch});

  factory CourtStatusDto.fromJson(Map<String, dynamic> json) {
    return CourtStatusDto(
      courtIdentifier: json['courtIdentifier'],
      currentMatch: json['currentMatch'] != null
          ? CurrentlyPlayingMatchDto.fromJson(json['currentMatch'])
          : null,
    );
  }
}

class CurrentlyPlayingMatchDto {
  final int matchId;
  final String courtNumber;
  final DateTime? startTime;
  final List<PlayerInMatchDto> teamA;
  final List<PlayerInMatchDto> teamB;

  CurrentlyPlayingMatchDto({
    required this.matchId,
    required this.courtNumber,
    this.startTime,
    required this.teamA,
    required this.teamB,
  });

  factory CurrentlyPlayingMatchDto.fromJson(Map<String, dynamic> json) {
    return CurrentlyPlayingMatchDto(
      matchId: json['matchId'],
      courtNumber: json['courtNumber'],
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,
      teamA: (json['teamA'] as List)
          .map((p) => PlayerInMatchDto.fromJson(p))
          .toList(),
      teamB: (json['teamB'] as List)
          .map((p) => PlayerInMatchDto.fromJson(p))
          .toList(),
    );
  }
}

class PlayerInMatchDto {
  final int participantId;
  final String participantType;
  final String nickname;
  final String? profilePhotoUrl;
  final String? genderName;
  final int? skillLevelId;
  final String? skillLevelName;
  final String? skillLevelColor;

  PlayerInMatchDto({
    required this.participantId,
    required this.participantType,
    required this.nickname,
    this.profilePhotoUrl,
    this.genderName,
    this.skillLevelId,
    this.skillLevelName,
    this.skillLevelColor,
  });

  factory PlayerInMatchDto.fromJson(Map<String, dynamic> json) {
    return PlayerInMatchDto(
      participantId: json['userId'] ?? json['walkinId'],
      participantType: json['userId'] != null ? 'Member' : 'Guest',
      nickname: json['nickname'],
      profilePhotoUrl: json['profilePhotoUrl'],
      genderName: json['genderName'],
      skillLevelId: json['skillLevelId'],
      skillLevelName: json['skillLevelName'],
      skillLevelColor: json['skillLevelColor'],
    );
  }
}

// --- NEW: เพิ่ม extension method เพื่อแปลง PlayerInMatchDto กลับเป็น JSON ที่ PlayerFromJson.fromJson ต้องการ ---
extension PlayerInMatchDtoExtension on PlayerInMatchDto {
  Map<String, dynamic> toPlayerJson() {
    return {
      'participantId': participantId,
      'participantType': participantType,
      'nickname': nickname,
      'profilePhotoUrl': profilePhotoUrl,
      'skillLevelName': skillLevelName,
      'skillLevelColor': skillLevelColor,
      'skillLevelId': skillLevelId,
    };
  }
}

// --- NEW: Model สำหรับ StagedMatch ที่ยังไม่ได้เริ่ม ---
class StagedMatchDto {
  final int stagedMatchId;
  final List<PlayerInMatchDto> teamA;
  final List<PlayerInMatchDto> teamB;
  final String? courtIdentifier; // NEW: เพิ่มฟิลด์สำหรับระบุสนาม

  StagedMatchDto({
    required this.stagedMatchId,
    required this.teamA,
    required this.teamB,
    this.courtIdentifier,
  });

  factory StagedMatchDto.fromJson(Map<String, dynamic> json) {
    return StagedMatchDto(
      stagedMatchId:
          json['stagedMatchId'] ?? json['matchId'], // FIX: รองรับทั้งสอง key
      teamA: (json['teamA'] as List)
          .map((p) => PlayerInMatchDto.fromJson(p))
          .toList(),
      teamB: (json['teamB'] as List)
          .map((p) => PlayerInMatchDto.fromJson(p))
          .toList(),
      courtIdentifier: json['courtNumber'],
    );
  }
}

class RosterManagementPanel extends StatefulWidget {
  final String sessionId;
  final List<Player> players; // FIX: รับ List ของ Player
  final VoidCallback onClose; // เพิ่ม Callback สำหรับปุ่มปิด
  const RosterManagementPanel({
    super.key,
    required this.onClose,
    required this.sessionId,
    required this.players,
  });

  @override
  State<RosterManagementPanel> createState() => _RosterManagementPanelState();
}

class _RosterManagementPanelState extends State<RosterManagementPanel> {
  // --- FIX: ข้อมูลตัวอย่าง (เพิ่ม participantId และ participantType) ---
  // TODO: ควรเปลี่ยนเป็นการดึงข้อมูลจาก API live-state ในอนาคต
  late List<RosterPlayer> _rosterPlayers;

  // --- NEW: เพิ่ม State สำหรับเก็บ Skill Levels ---
  List<dynamic> _skillLevels = [];

  @override
  void initState() {
    super.initState();
    _rosterPlayers =
        []; // FIX: กำหนดค่าเริ่มต้นเป็น List ว่าง เพื่อป้องกัน LateInitializationError
    _fetchRosterData(); // จากนั้นจึงเริ่มดึงข้อมูล
    _fetchSkillLevels();
  }

  // --- NEW: ดึงข้อมูลผู้เล่นสำหรับ Roster โดยเฉพาะ ---
  Future<void> _fetchRosterData() async {
    try {
      final response = await ApiProvider().get(
        '/gamesessions/${widget.sessionId}/roster',
      );
      if (mounted && response['data'] is List) {
        setState(() {
          _rosterPlayers = (response['data'] as List)
              .asMap()
              .entries
              .map((e) => RosterPlayer.fromJson(e.value, e.key + 1))
              .toList();
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _updateSkillLevel(RosterPlayer player, int newSkillLevel) async {
    try {
      final dto = {"skillLevelId": newSkillLevel};
      // --- FIX: แก้ไข Endpoint ให้ถูกต้อง ---
      await ApiProvider().put(
        '/GameSessions/${widget.sessionId}/participants/${player.participantType}/${player.participantId}/skill-level',
        data: dto,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัปเดตระดับมือของ ${player.nickname} สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      // --- NEW: อัปเดตค่าใน UI หลังจาก API สำเร็จ ---
      setState(() {
        player.skillLevel = newSkillLevel;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัปเดตระดับมือล้มเหลว: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- NEW: ฟังก์ชันสำหรับ Check-in ผู้เล่น ---
  Future<void> _checkInPlayer(RosterPlayer player) async {
    try {
      // ยิง API เพื่อทำการ check-in
      // --- FIX: แก้ไข Endpoint และเพิ่ม Body ให้ตรงกับ API ---
      await ApiProvider().post(
        '/gamesessions/${widget.sessionId}/checkin',
        data: {
          "participantId": player.participantId,
          "participantType": player.participantType,
          "scannedData": null, // ไม่ได้มาจากการสแกน
        },
      );

      // หากสำเร็จ ให้อัปเดต UI
      if (mounted) {
        setState(() {
          player.isChecked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เช็คอิน ${player.nickname} สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เช็คอินล้มเหลว: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- NEW: ดึงข้อมูล Skill Levels มาเพื่อใช้ใน Dropdown ---
  Future<void> _fetchSkillLevels() async {
    try {
      final response = await ApiProvider().get('/organizer/skill-levels');
      if (mounted && response['data'] is List) {
        setState(() {
          _skillLevels = (response['data'] as List).map((level) {
            return {"id": level['skillLevelId'], "name": level['levelName']};
          }).toList();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          Colors.transparent, // ทำให้พื้นหลังโปร่งใสเพื่อใช้ฉากหลังของ Dialog
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 365, // กำหนดความกว้างของ Side Sheet
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // --- Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'จัดการรายชื่อ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              // --- ตารางข้อมูล ---
              Expanded(
                child: SingleChildScrollView(
                  // ทำให้ตาราง scroll ได้ถ้าข้อมูลยาว
                  child: DataTable(
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: Text('no')),
                      DataColumn(label: Text('ชื่อเล่น')),
                      DataColumn(label: Text('เพศ')),
                      DataColumn(label: Text('ระดับมือ')),
                      DataColumn(label: Text('check')),
                    ],
                    rows: _rosterPlayers.map((player) {
                      // --- FIX: ใช้ข้อมูลจาก RosterPlayer โดยตรง ---
                      return DataRow(
                        cells: [
                          DataCell(Text('${player.no}')),
                          DataCell(Text(player.nickname)),
                          DataCell(Text(player.gender)),
                          DataCell(
                            // --- FIX: Dropdown ที่ใช้ข้อมูล Skill Levels จาก State ---
                            DropdownButton<int>(
                              value: player.skillLevel,
                              underline:
                                  const SizedBox(), // เอาเส้นใต้ของ Dropdown ออก
                              items: _skillLevels.map<DropdownMenuItem<int>>((
                                level,
                              ) {
                                return DropdownMenuItem(
                                  value: level['id'],
                                  child: Text(level['name']),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  _updateSkillLevel(player, newValue);
                                }
                              },
                            ),
                          ),
                          DataCell(
                            // --- Checkbox ---
                            Checkbox(
                              value: player.isChecked, // ค่าของ Checkbox
                              // ถ้า isChecked เป็น true ให้ onChanged เป็น null (กดไม่ได้)
                              // ถ้า isChecked เป็น false ให้เรียกใช้ฟังก์ชัน _checkInPlayer
                              onChanged: player.isChecked
                                  ? null
                                  : (bool? newValue) {
                                      if (newValue == true) {
                                        _checkInPlayer(player);
                                      }
                                    },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),

              // --- Bottom Buttons ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // ไม่จำเป็นต้องใช้ปุ่มนี้แล้ว เพราะอัปเดตทันทีที่เลือก
                        },
                        child: const Text('บันทึกระดับมือ'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                        child: const Text('เพิ่มผู้เล่น Walk In'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerProfilePanel extends StatefulWidget {
  final String sessionId;
  final List<dynamic> skillLevels; // NEW: รับข้อมูลระดับมือ
  final Player? player; // รับ Player ที่อาจเป็น null ได้
  final VoidCallback onClose;
  final Function(Player) onShowExpenses;

  const PlayerProfilePanel({
    super.key,
    required this.skillLevels,
    required this.sessionId,
    this.player,
    required this.onClose,
    required this.onShowExpenses,
  });

  @override
  State<PlayerProfilePanel> createState() => _PlayerProfilePanelState();
}

class _PlayerProfilePanelState extends State<PlayerProfilePanel> {
  // State ภายในของ Panel เอง
  bool _isEmergencyContactVisible = false;
  late int _selectedSkillLevel;
  bool _isStatsLoading = true;
  PlayerStats? _playerStats;

  @override
  void initState() {
    super.initState();
    _selectedSkillLevel = widget.player?.skillLevelId ?? 1;
    if (widget.player != null) {
      _fetchPlayerStats();
    }
  }

  // อัปเดตค่าเมื่อ Widget ถูกสร้างใหม่ (เมื่อเลือกผู้เล่นคนใหม่)
  @override
  void didUpdateWidget(covariant PlayerProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player != oldWidget.player) {
      // FIX: ใช้ setState เพื่อให้ UI อัปเดตทันที
      setState(() {
        _selectedSkillLevel = widget.player?.skillLevelId ?? 1;
        _isEmergencyContactVisible = false;
        _playerStats = null;
        _isStatsLoading = true;
      });
      if (widget.player != null) {
        _fetchPlayerStats();
      }
    }
  }

  // --- NEW: ฟังก์ชันสำหรับดึงข้อมูลสถิติของผู้เล่น ---
  Future<void> _fetchPlayerStats() async {
    if (widget.player == null) return;

    final parts = widget.player!.id.split('_');
    if (parts.length != 2) return;

    final participantType = parts[0];
    final participantId = parts[1];
    print(
      '/gamesessions/${widget.sessionId}/player-stats/$participantType/$participantId',
    );
    try {
      final response = await ApiProvider().get(
        '/gamesessions/${widget.sessionId}/player-stats/$participantType/$participantId',
      );
      if (mounted) {
        setState(() {
          _playerStats = PlayerStats.fromJson(response['data']);
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStatsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถโหลดสถิติผู้เล่นได้: $e')),
        );
      }
    }
  }

  // --- NEW: ฟังก์ชันสำหรับอัปเดตระดับมือ ---
  Future<void> _updateSkillLevel(int newSkillLevelId) async {
    if (widget.player == null) return;

    final parts = widget.player!.id.split('_');
    if (parts.length != 2) return;

    final participantType = parts;
    final participantId = parts;

    try {
      final dto = {"skillLevelId": newSkillLevelId};
      await ApiProvider().put(
        '/participants/$participantType/$participantId/skill',
        data: dto,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('อัปเดตระดับมือสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('อัปเดตระดับมือล้มเหลว: $e'),
          backgroundColor: Colors.red,
        ),
      );
      // คืนค่า level เดิมถ้า error
      setState(() => _selectedSkillLevel = widget.player?.skillLevelId ?? 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ถ้าไม่มีข้อมูลผู้เล่น ให้แสดงเป็น Container ว่างๆ
    if (widget.player == null) {
      return const SizedBox.shrink();
    }

    final player = widget.player!;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 420,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            children: [
              // --- Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FIX: ตรวจสอบ imageUrl ก่อนใช้งาน
                    if (player.imageUrl != null && player.imageUrl!.isNotEmpty)
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(player.imageUrl!),
                      )
                    else
                      const CircleAvatar(radius: 30, child: Icon(Icons.person)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.fullName ??
                                player
                                    .name, // FIX: ใช้ name ถ้า fullName เป็น null
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                'ระดับมือ: ',
                                style: TextStyle(fontSize: 14),
                              ),
                              DropdownButton<String>(
                                value: _selectedSkillLevel.toString(),
                                items: widget.skillLevels
                                    .map<DropdownMenuItem<String>>((skill) {
                                      return DropdownMenuItem<String>(
                                        value: skill['code'],
                                        child: Text(
                                          skill['value'],
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    })
                                    .toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    _updateSkillLevel(int.parse(newValue));
                                  }
                                },
                              ),
                              const Spacer(),
                              // --- ปุ่มรถพยาบาล ---
                              IconButton(
                                icon: const Icon(
                                  Icons.medical_services_outlined,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isEmergencyContactVisible =
                                        !_isEmergencyContactVisible;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),

              // --- Emergency Contact ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isEmergencyContactVisible
                    ? Container(
                        key: const ValueKey('contact_visible'),
                        width: double.infinity,
                        color: Colors.red[100],
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'ผู้ติดต่อฉุกเฉิน: ${player.emergencyContactName ?? ""} ${player.emergencyContactPhone ?? ""}',
                          style: TextStyle(color: Colors.red[800]),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('contact_hidden')),
              ),

              // --- ตารางประวัติ ---
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    const TextSpan(text: 'เล่นไป: '),
                    TextSpan(
                      text: '${_playerStats?.totalGamesPlayed ?? 0} เกม  ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const TextSpan(text: 'เวลาเล่นรวม: '),
                    TextSpan(
                      text: '${_playerStats?.totalMinutesPlayed}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              // ตาราง
              Expanded(
                child: _isStatsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Table(
                            border: TableBorder.all(
                              color: Colors.grey.shade700,
                              width: 1,
                            ),
                            columnWidths: const {
                              0: FlexColumnWidth(1),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1.5),
                              3: FlexColumnWidth(2),
                            },
                            children: [
                              // แถวหัวข้อ
                              buildRow([
                                'เกมที่',
                                'สนาม',
                                'คู่',
                                'คู่แข่ง',
                              ], isHeader: true),
                              // --- NEW: สร้างแถวข้อมูลจาก API ---
                              if (_playerStats?.matchHistory != null)
                                ..._playerStats!.matchHistory
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      int index = entry.key;
                                      MatchHistoryItem history = entry.value;
                                      return buildRow([
                                        (index + 1).toString(),
                                        history.courtNumber.toString(),
                                        history.teammate.nickname,
                                        history.opponents
                                            .map((op) => op.nickname)
                                            .join(', '),
                                      ]);
                                    })
                                    .toList(),
                            ],
                          ),
                        ),
                      ),
              ),

              // --- Bottom Buttons ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'หยุดเกมส์ผู้เล่น',
                        backgroundColor: Color(0xFFFFFFFF),
                        foregroundColor: Color(0xFF0E9D7A),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'จบเกมส์ผู้เล่น',
                        backgroundColor: Color(0xFFFFFFFF),
                        foregroundColor: Color(0xFF0E9D7A),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'ค่าใช้จ่าย',
                        backgroundColor: Color(0xFF243F94),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        icon: Icons.keyboard_arrow_down,
                        onPressed: () {
                          widget.onShowExpenses(widget.player!);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TableRow buildRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            cell,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// --- NEW: Model สำหรับข้อมูลสถิติ ---
class PlayerStats {
  final int totalGamesPlayed;
  final String totalMinutesPlayed;
  final int wins;
  final int losses;
  final List<MatchHistoryItem> matchHistory;

  PlayerStats({
    required this.totalGamesPlayed,
    required this.totalMinutesPlayed,
    required this.wins,
    required this.losses,
    required this.matchHistory,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    return PlayerStats(
      totalGamesPlayed: json['totalGamesPlayed'] ?? 0,
      totalMinutesPlayed: json['totalMinutesPlayed'],
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      matchHistory: (json['matchHistory'] as List? ?? [])
          .map((item) => MatchHistoryItem.fromJson(item))
          .toList(),
    );
  }
}

class MatchHistoryItem {
  final String courtNumber;
  final int durationMinutes;
  final HistoryPlayer teammate;
  final List<HistoryPlayer> opponents;

  MatchHistoryItem({
    required this.courtNumber,
    required this.durationMinutes,
    required this.teammate,
    required this.opponents,
  });

  factory MatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return MatchHistoryItem(
      courtNumber: json['courtNumber'] ?? 0,
      durationMinutes: json['durationMinutes'] ?? 0,
      teammate: json['teammate'] != null
          ? HistoryPlayer.fromJson(json['teammate'])
          : HistoryPlayer(nickname: 'N/A'),
      opponents: (json['opponents'] as List? ?? [])
          .map((op) => HistoryPlayer.fromJson(op))
          .toList(),
    );
  }
}

// --- NEW: Model สำหรับผู้เล่นในประวัติการแข่ง ---
class HistoryPlayer {
  final String nickname;
  // สามารถเพิ่ม userId หรือ walkinId ได้ถ้าต้องการ

  HistoryPlayer({required this.nickname});

  factory HistoryPlayer.fromJson(Map<String, dynamic> json) {
    return HistoryPlayer(nickname: json['nickname'] ?? 'N/A');
  }
}

class ExpensePanel extends StatefulWidget {
  final Player? player;
  final VoidCallback onClose;

  const ExpensePanel({super.key, this.player, required this.onClose});

  @override
  State<ExpensePanel> createState() => _ExpensePanelState();
}

class _ExpensePanelState extends State<ExpensePanel> {
  // State ภายในของ Panel เอง
  bool _isEmergencyContactVisible = false;
  late int _selectedSkillLevel;

  @override
  void initState() {
    super.initState();
    _selectedSkillLevel = widget.player?.level ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.player == null) {
      return const SizedBox.shrink();
    }
    final player = widget.player!;
    final sizedBoxheight = 20.0;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 450,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // --- Header ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FIX: ตรวจสอบ imageUrl ก่อนใช้งาน
                    if (player.imageUrl != null && player.imageUrl!.isNotEmpty)
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(player.imageUrl!),
                      )
                    else
                      const CircleAvatar(radius: 30, child: Icon(Icons.person)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.fullName ??
                                player
                                    .name, // FIX: ใช้ name ถ้า fullName เป็น null
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              const Text('ระดับมือ: '),
                              DropdownButton<int>(
                                value: _selectedSkillLevel,
                                items: [1, 2, 3, 4, 5, 6, 7, 8]
                                    .map(
                                      (l) => DropdownMenuItem(
                                        value: l,
                                        child: Text('LV.$l'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedSkillLevel = val!),
                              ),
                              const Spacer(),
                              // --- ปุ่มรถพยาบาล ---
                              IconButton(
                                icon: const Icon(
                                  Icons.medical_services_outlined,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isEmergencyContactVisible =
                                        !_isEmergencyContactVisible;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                // --- Emergency Contact ---
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isEmergencyContactVisible
                      ? Container(
                          key: const ValueKey('contact_visible'),
                          width: double.infinity,
                          color: Colors.red[100],
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'ผู้ติดต่อฉุกเฉิน: ${player.emergencyContactName} ${player.emergencyContactPhone}',
                            style: TextStyle(color: Colors.red[800]),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('contact_hidden')),
                ),
                SizedBox(height: sizedBoxheight),
                // --- ตารางประวัติ ---
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    children: [
                      const TextSpan(text: 'เล่นไป '),
                      TextSpan(
                        text: '${player.gamesPlayed} เกม  ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      TextSpan(
                        text: '${player.shuttlesUsed} ลูก  ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const TextSpan(text: 'เวลาที่รอ '),
                      TextSpan(
                        text:
                            '${(player.waitingTime ?? Duration.zero).inMinutes}.${(player.waitingTime ?? Duration.zero).inSeconds.remainder(60).toString().padLeft(2, '0')} นาที',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sizedBoxheight),
                // ตาราง
                SizedBox(
                  height: 300,
                  child: SingleChildScrollView(
                    child: Table(
                      border: TableBorder.all(
                        color: Colors.grey.shade700,
                        width: 1,
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(2),
                      },
                      children: [
                        // แถวหัวข้อ
                        buildRow([
                          'เกมที่',
                          '#',
                          'ทีม',
                          'VS',
                          'คู่แข่ง',
                        ], isHeader: true),
                        // แถวข้อมูล
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['1', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['2', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                        buildRow(['3', '1,4', 'เจน', 'VS', 'นุ่น, โบว์']),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: sizedBoxheight),
                // --- Bottom Buttons ---
                Row(
                  children: [
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'หยุดเกมส์ผู้เล่น',
                        backgroundColor: Color(0xFFFFFFFF),
                        foregroundColor: Color(0xFF0E9D7A),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'จบเกมส์ผู้เล่น',
                        backgroundColor: Color(0xFFFFFFFF),
                        foregroundColor: Color(0xFF0E9D7A),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(
                          horizontal: 8,
                          vertical: 16,
                        ),
                        text: 'ค่าใช้จ่าย',
                        backgroundColor: Color(0xFF243F94),
                        side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        icon: Icons.keyboard_arrow_up,
                        enabled: true,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                SizedBox(height: sizedBoxheight),

                ExpensePanelWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TableRow buildRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            cell,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
        );
      }).toList(),
    );
  }
}
