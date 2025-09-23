class GameCardModel {
  final String teamName;
  final String imageUrl;
  final String day;
  final String date;
  final String time;
  final String courtName;
  final String location;
  final String price;
  final String shuttlecockInfo;
  final String gameInfo;
  final int currentPlayers;
  final int maxPlayers;
  final String organizerName;
  final String organizerImageUrl;
  final bool isInitiallyBookmarked;

  GameCardModel({
    required this.teamName,
    required this.imageUrl,
    required this.day,
    required this.date,
    required this.time,
    required this.courtName,
    required this.location,
    required this.price,
    required this.shuttlecockInfo,
    required this.gameInfo,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.organizerName,
    required this.organizerImageUrl,
    this.isInitiallyBookmarked = false,
  });
}