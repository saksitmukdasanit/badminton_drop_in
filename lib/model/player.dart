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
  int? gamesPlayed;
  final int? shuttlesUsed;
  final Duration? waitingTime;
  Duration? totalPlayTime;
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
