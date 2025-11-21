// ในไฟล์ models.dart หรือไฟล์ที่คุณเก็บ Model
class GameHistory {
  final int gameNumber;
  final String courtInfo;
  final String partner;
  final List<String> opponents;

  GameHistory({
    required this.gameNumber,
    required this.courtInfo,
    required this.partner,
    required this.opponents,
  });
}

class Player {
  final String id;
  final String name; // nickname
  final String? fullName;
  final String? imageUrl;
  final int? level;
  final String? skillLevelName;
  final int? skillLevelId;
  final String? skillLevelColor;
  final int? gamesPlayed;
  final int? shuttlesUsed;
  final Duration? waitingTime;
  final Duration? totalPlayTime;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final List<GameHistory>? gameHistory;

  Player({
    required this.id,
    required this.name,
    this.fullName,
    this.imageUrl,
    this.level,
    this.skillLevelName,
    this.skillLevelId,
    this.skillLevelColor,
    this.gamesPlayed = 0,
    this.shuttlesUsed = 0,
    this.waitingTime = Duration.zero,
    this.totalPlayTime = Duration.zero,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.gameHistory,
  });
}

// สร้างคลาสนี้ในไฟล์ models.dart ของคุณก็ได้
class RosterPlayer {
  final int no;
  final String nickname;
  final String fullName;
  final String gender;
  int skillLevel; // ใช้ int เพื่อให้เปลี่ยนค่าใน Dropdown ได้
  final String? skillLevelName;
  bool isChecked;
  final int participantId;
  final String participantType;

  RosterPlayer({
    required this.no,
    required this.nickname,
    required this.fullName,
    required this.gender,
    required this.skillLevel,
    this.skillLevelName,
    this.isChecked = false,
    required this.participantId,
    required this.participantType,
  });

  // --- NEW: เพิ่ม factory constructor fromJson ---
  factory RosterPlayer.fromJson(Map<String, dynamic> json, int index) {
    return RosterPlayer(
      no: index,
      nickname: json['nickname'],
      fullName: json['fullName'] ?? json['nickname'],
      gender: json['genderName'] ?? 'N/A',
      skillLevel: json['skillLevelId'],
      skillLevelName: json['skillLevelName'],
      isChecked: json['isCheckedIn'] ?? false,
      participantId: json['participantId'],
      participantType: json['participantType'],
    );
  }
}
