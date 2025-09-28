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
  final String name;
  final String fullName;
  final String imageUrl;
  final int level;
  final int gamesPlayed;
  final int shuttlesUsed;
  final Duration waitingTime;

  final Duration totalPlayTime;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final List<GameHistory> gameHistory;

  Player({
    required this.id,
    required this.name,
    required this.fullName,
    required this.imageUrl,
    required this.level,
    required this.gamesPlayed,
    required this.shuttlesUsed,
    required this.waitingTime,
    required this.totalPlayTime,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.gameHistory,
  });
}

// สร้างคลาสนี้ในไฟล์ models.dart ของคุณก็ได้
class RosterPlayer {
  final int no;
  final String nickname;
  final String fullName;
  final String gender;
  int skillLevel; // ใช้ int เพื่อให้เปลี่ยนค่าใน Dropdown ได้
  bool isChecked;

  RosterPlayer({
    required this.no,
    required this.nickname,
    required this.fullName,
    required this.gender,
    required this.skillLevel,
    this.isChecked = true,
  });
}
