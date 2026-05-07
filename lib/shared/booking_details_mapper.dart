import 'package:badminton/page/user/booking_confirm.dart';
import 'package:badminton/shared/function.dart';

int? _sessionIdFromJson(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Maps [UpcomingSessionCardDto] JSON (search / share API) to [BookingDetails].
BookingDetails bookingDetailsFromUpcomingCardMap(Map<String, dynamic> game) {
  final formattedDateTime = formatSessionStart(
    game['sessionStart']?.toString() ?? DateTime.now().toIso8601String(),
  );
  final imageUrlsFromApi = game['courtImageUrls'] as List<dynamic>? ?? [];
  final courtImageUrls = List<String>.from(imageUrlsFromApi);
  final rawStatus = game['status'];
  final status = rawStatus is int
      ? rawStatus
      : int.tryParse(rawStatus?.toString() ?? '') ?? 1;

  return BookingDetails(
    code: _sessionIdFromJson(game['sessionId']) ?? 0,
    teamName: game['groupName']?.toString() ?? '',
    imageUrl: game['imageUrl']?.toString() ?? '',
    day: formattedDateTime['day']!,
    date: '${game['dayOfWeek']} ${game['sessionDate']}',
    time: '${game['startTime']}-${game['endTime']}',
    courtName: game['courtName']?.toString() ?? 'N/A',
    location: game['location']?.toString() ?? '-',
    price: game['price']?.toString() ?? '-',
    shuttlecockInfo: game['shuttlecockModelName']?.toString() ?? '-',
    shuttlecockBrand: game['shuttlecockBrandName']?.toString() ?? '-',
    gameInfo: game['gameTypeName']?.toString() ?? '-',
    courtNumbers: game['courtNumbers']?.toString() ?? '',
    currentPlayers: game['currentParticipants'] is int
        ? game['currentParticipants'] as int
        : (game['currentParticipants'] as num?)?.toInt() ?? 0,
    maxPlayers: game['maxParticipants'] is int
        ? game['maxParticipants'] as int
        : (game['maxParticipants'] as num?)?.toInt() ?? 0,
    organizerName: game['organizerName']?.toString() ?? 'N/A',
    organizerImageUrl: game['organizerImageUrl']?.toString() ??
        'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
    courtImageUrls: courtImageUrls,
    notes: game['notes']?.toString() ?? '',
    status: status,
    currentUserStatus: game['userStatus']?.toString() ?? 'NotJoined',
    courtFee: double.tryParse(
      (game['courtFeePerPerson'] ?? game['courtFee'])?.toString() ?? '',
    ),
    shuttleFee: double.tryParse(
      (game['shuttlecockFeePerPerson'] ?? game['shuttlecockFee'])?.toString() ?? '',
    ),
    isBuffet: game['costingMethod'] == 2,
    sessionStart: game['sessionStart']?.toString() ?? DateTime.now().toIso8601String(),
  );
}
