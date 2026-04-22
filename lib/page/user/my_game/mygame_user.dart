import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/game_card.dart';
import 'package:badminton/component/game_card2.dart';
import 'package:badminton/page/user/booking_confirm.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MyGameUserPage extends StatefulWidget {
  const MyGameUserPage({super.key});

  @override
  MyGameUserPageState createState() => MyGameUserPageState();
}

class MyGameUserPageState extends State<MyGameUserPage> {
  late Future<Map<String, List<dynamic>>> _myGamesFuture;

  @override
  void initState() {
    super.initState();
    _myGamesFuture = _fetchMyGames();
  }

  Future<Map<String, List<dynamic>>> _fetchMyGames() async {
    try {
      // TODO: เปลี่ยน Path ให้ตรงกับ API Backend สำหรับดึงรายการเกมของฉัน
      final response = await ApiProvider().get('/player/gamesessions/my');
      if (response['status'] == 200) {
        final data = response['data'] ?? {};
        return {
          'playing': data['playing'] ?? [],
          'upcoming': data['upcoming'] ?? [],
          'refund': data['refund'] ?? [],
        };
      } else {
        throw Exception('Invalid API response');
      }
    } catch (e) {
      throw Exception('Failed to load my games: $e');
    }
  }

  // --- NEW: ฟังก์ชันสำหรับจัดการ Bookmark ---
  Future<void> _toggleBookmark(dynamic game, bool isBookmarked) async {
    final sessionId = game['sessionId'];
    if (sessionId == null) return;

    // อัปเดต UI ทันที (Optimistic Update)
    if (mounted) {
      setState(() {
        game['isBookmarked'] = isBookmarked;
      });
    }

    try {
      if (isBookmarked) {
        await ApiProvider().post('/player/gamesessions/$sessionId/bookmark');
      } else {
        await ApiProvider().delete('/player/gamesessions/$sessionId/bookmark');
      }
    } catch (e) {
      // หาก API Error ให้ Rollback การเปลี่ยนแปลงบน UI
      if (mounted) {
        setState(() {
          game['isBookmarked'] = !isBookmarked;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'เกมส์ของฉัน', isBack: false),
      body: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<Map<String, List<dynamic>>>(
          future: _myGamesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
            }

            final gamesData =
                snapshot.data ?? {'playing': [], 'upcoming': [], 'refund': []};

            if (gamesData['playing']!.isEmpty &&
                gamesData['upcoming']!.isEmpty &&
                gamesData['refund']!.isEmpty) {
              return const Center(child: Text('คุณยังไม่มีก๊วนที่เข้าร่วม'));
            }

            return ListView(
              children: [
                if (gamesData['playing']!.isNotEmpty)
                  _buildSection(
                    context,
                    title: 'กำลังเล่น',
                    games: gamesData['playing']!,
                  ),
                if (gamesData['upcoming']!.isNotEmpty)
                  _buildSection(
                    context,
                    title: 'ก๊วนที่กำลังมาถึง',
                    games: gamesData['upcoming']!,
                  ),
                if (gamesData['refund']!.isNotEmpty)
                  _buildSection(
                    context,
                    title: 'รอคืนเงิน',
                    games: gamesData['refund']!,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<dynamic> games,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: getResponsiveFontSize(context, fontSize: 20),
              ),
            ),
            if (games.length > 2)
              Text(
                'ดูเพิ่มเติม',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: getResponsiveFontSize(context, fontSize: 14),
                  color: const Color(0xFF393941),
                  decoration: TextDecoration.underline,
                ),
              ),
          ],
        ),
        ...games.map((game) => _buildGameCard(context, game)).toList(),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildGameCard(BuildContext context, dynamic game) {
    final formattedDateTime = formatSessionStart(
      game['sessionStart'] ?? DateTime.now().toIso8601String(),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: GameCard(
        teamName: game['groupName'] ?? 'N/A',
        imageUrl:
            game['imageUrl'] ??
            'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
        day: formattedDateTime['day'] ?? 'Mon',
        date: '${game['dayOfWeek']} ${game['sessionDate']}'.trim(),
        time: '${game['startTime']}-${game['endTime']}',
        courtName: game['courtName'] ?? 'N/A',
        location: game['location'] ?? '-',
        price:
            'สนาม ${game['courtFeePerPerson'] ?? game['courtFee'] ?? '-'} บ.\nลูก ${(game['costingMethod'] == 2) ? 'เหมาจ่าย' : '${game['shuttlecockFeePerPerson'] ?? game['shuttlecockFee'] ?? '-'} บ.'}',
        shuttlecockInfo: game['shuttlecockModelName'] ?? '-',
        shuttlecockBrand: game['shuttlecockBrandName'] ?? '-',
        gameInfo: game['gameTypeName'] ?? '-',
        currentPlayers: game['currentParticipants'] ?? 0,
        maxPlayers: game['maxParticipants'] ?? 0,
        organizerName: game['organizerName'] ?? 'N/A',
        organizerImageUrl:
            game['organizerImageUrl'] ??
            'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
        isInitiallyBookmarked: game['isBookmarked'] ?? false,
        // --- FIX: เพิ่ม Callback เพื่อส่งค่าการกด Bookmark กลับมา ---
        onBookmarkTap: (isBookmarked) => _toggleBookmark(game, isBookmarked),
        onCardTap: () {
          final imageUrlsFromApi =
              game['courtImageUrls'] as List<dynamic>? ?? [];
          final List<String> courtImageUrls = List<String>.from(
            imageUrlsFromApi,
          );
          
          // แปลงวันที่และเวลาให้เป็น String ที่สมบูรณ์สำหรับใช้เปรียบเทียบเวลาในการแสดงปุ่ม Cancel
          String sessionStartStr = game['sessionStart'] ?? '';
          if (sessionStartStr.isEmpty) {
            String d = game['sessionDate'] ?? '';
            String t = game['startTime'] ?? '';
            if (d.isNotEmpty && t.isNotEmpty) {
               d = d.split('T')[0]; // ดึงเฉพาะ YYYY-MM-DD
               sessionStartStr = '${d}T$t';
               if (t.length == 5) sessionStartStr += ':00'; // เติมวินาทีให้ parse ได้สมบูรณ์
            } else {
               sessionStartStr = DateTime.now().toIso8601String();
            }
          }

          final bookingDetails = BookingDetails(
            code: game['sessionId'] ?? 0,
            teamName: game['groupName'] ?? '',
            imageUrl: game['imageUrl'] ?? '',
            day: formattedDateTime['day'] ?? 'Mon',
            date: '${game['dayOfWeek']} ${game['sessionDate']}'.trim(),
            time: '${game['startTime']}-${game['endTime']}',
            courtName: game['courtName'] ?? '',
            location: game['location'] ?? '',
            price: (game['price'] ?? 0).toString(),
            shuttlecockInfo: game['shuttlecockModelName'] ?? '',
            shuttlecockBrand: game['shuttlecockBrandName'] ?? '',
            gameInfo: game['gameTypeName'] ?? '',
            courtNumbers: game['courtNumbers'] ?? '',
            currentPlayers: game['currentParticipants'] ?? 0,
            maxPlayers: game['maxParticipants'] ?? 0,
            organizerName: game['organizerName'] ?? '',
            organizerImageUrl: game['organizerImageUrl'] ?? '',
            notes: game['notes'] ?? '',
            courtImageUrls: courtImageUrls.isNotEmpty
                ? courtImageUrls
                : [
                    'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
                  ],
            status: game['status'] ?? 1,
            currentUserStatus: game['userStatus'] ?? 'Joined',
            courtFee: double.tryParse(
              (game['courtFeePerPerson'] ?? game['courtFee'])?.toString() ?? '',
            ),
            shuttleFee: double.tryParse(
              (game['shuttlecockFeePerPerson'] ?? game['shuttlecockFee'])
                      ?.toString() ??
                  '',
            ),
            isBuffet: game['costingMethod'] == 2,
            sessionStart: sessionStartStr,
          );
          context.push('/booking-confirm-game', extra: bookingDetails);
        },
        onTapOrganizer: () async {
          // โชว์ Loading ก่อนเปิด Dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );

          try {
            final res = await ApiProvider().get(
              '/player/gamesessions/${game['sessionId']}/organizer-summary',
            );
            if (!context.mounted) return;
            Navigator.of(context, rootNavigator: true).pop(); // ปิด Loading

            if (res['status'] == 200 && res['data'] != null) {
              final data = res['data'];
              showUserProfileDialog(
                context,
                imageUrl:
                    data['profilePhotoUrl'] ?? game['organizerImageUrl'] ?? '',
                name: data['nickname'] ?? game['organizerName'] ?? 'N/A',
                // *หมายเหตุ: หากฟังก์ชัน showUserProfileDialog (ใน function.dart) รับพารามิเตอร์ hostedCount / cancelledCount
                // ให้เอาคอมเมนต์ 2 บรรทัดข้างล่างออก และเปลี่ยนชื่อให้ตรงกับที่คุณสร้างไว้ครับ
                hostedCount: data['totalHosted'] ?? 0,
                cancelledCount: data['totalCancelled'] ?? 0,
                organizerId: data['organizerId'],
                isFollowed: data['isFollowed'],
              );
            } else {
              showUserProfileDialog(
                context,
                imageUrl: game['organizerImageUrl'] ?? '',
                name: game['organizerName'] ?? 'N/A',
                // organizerId and isFollowed are null, so no follow button will be shown
              );
            }
          } catch (e) {
            if (!context.mounted) return;
            Navigator.of(
              context,
              rootNavigator: true,
            ).pop(); // ปิด Loading กรณี Error
            showUserProfileDialog(
              context,
              imageUrl: game['organizerImageUrl'] ?? '',
              name: game['organizerName'] ?? 'N/A',
            );
          }
        },
        onTapPlayers: () => context.push(
          '/player-list/${game['sessionId']}',
        ), // เปลี่ยนเป็นส่ง sessionId เหมือนหน้า Search
      ),
    );
  }
}
