import 'package:badminton/model/player.dart';

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
      gamesPlayed: json['totalGamesPlayed'],
      totalPlayTime: json['checkedInTime'] != null
          ? DateTime.now().difference(DateTime.parse(json['checkedInTime']))
          : Duration.zero,
      emergencyContactName: json['emergencyContactName'],
      emergencyContactPhone: json['emergencyContactPhone'],
    );
  }
}

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
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  PlayerInMatchDto({
    required this.participantId,
    required this.participantType,
    required this.nickname,
    this.profilePhotoUrl,
    this.genderName,
    this.skillLevelId,
    this.skillLevelName,
    this.skillLevelColor,
    this.emergencyContactName,
    this.emergencyContactPhone,
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
      emergencyContactName: json['emergencyContactName'],
      emergencyContactPhone: json['emergencyContactPhone'],
    );
  }
}

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
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
    };
  }
}

class StagedMatchDto {
  final int stagedMatchId;
  final List<PlayerInMatchDto> teamA;
  final List<PlayerInMatchDto> teamB;
  final String? courtIdentifier;

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

class RosterPlayer {
  final int no;
  final String nickname;
  final String fullName;
  final String gender;
  int skillLevel;
  bool isChecked;
  final int participantId;
  final String participantType;
  final int status;

  RosterPlayer({
    required this.no,
    required this.nickname,
    required this.fullName,
    required this.gender,
    required this.skillLevel,
    this.isChecked = false,
    required this.participantId,
    required this.participantType,
    required this.status,
  });

  factory RosterPlayer.fromJson(Map<String, dynamic> json, int index) {
    return RosterPlayer(
      no: index,
      nickname: json['nickname'] ?? 'N/A',
      fullName: json['fullName'] ?? json['nickname'],
      gender: json['gender'] ?? 'N/A',
      skillLevel: json['skillLevelId'] ?? 1,
      isChecked: json['isCheckedIn'] ?? false,
      participantId: json['participantId'],
      participantType: json['participantType'],
      status: json['status'] ?? 1,
    );
  }
}

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
      courtNumber: (json['courtNumber'] ?? 0).toString(),
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

class HistoryPlayer {
  final String nickname;

  HistoryPlayer({required this.nickname});

  factory HistoryPlayer.fromJson(Map<String, dynamic> json) {
    return HistoryPlayer(nickname: json['nickname'] ?? 'N/A');
  }
}