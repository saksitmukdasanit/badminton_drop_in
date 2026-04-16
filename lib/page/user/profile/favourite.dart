import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/game_card2.dart';
import 'package:badminton/page/user/booking_confirm.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FavouritePage extends StatefulWidget {
  const FavouritePage({super.key});

  @override
  FavouritePageState createState() => FavouritePageState();
}

class FavouritePageState extends State<FavouritePage> {
  bool _isLoading = true;
  List<dynamic> _bookmarkedGames = [];
  List<dynamic> _followedOrganizers = [];

  @override
  void initState() {
    super.initState();
    _fetchFavourites();
  }

  Future<void> _fetchFavourites() async {
    try {
      final responses = await Future.wait([
        ApiProvider().get('/player/gamesessions/bookmarked'),
        ApiProvider().get('/users/my-followed'),
      ]);

      if (mounted) {
        setState(() {
          _bookmarkedGames = responses[0]['data'] ?? [];
          _followedOrganizers = responses[1]['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching favourites: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBookmark(int index, bool isBookmarked) async {
    final game = _bookmarkedGames[index];
    final sessionId = game['sessionId'];

    // Optimistic Update: ซ่อนการ์ดทิ้งทันทีเมื่อกดยกเลิก
    if (!isBookmarked && mounted) {
       setState(() {
         _bookmarkedGames.removeAt(index);
       });
    }

    try {
      if (isBookmarked) {
        await ApiProvider().post('/player/gamesessions/$sessionId/bookmark');
      } else {
        await ApiProvider().delete('/player/gamesessions/$sessionId/bookmark');
      }
    } catch (e) {
       _fetchFavourites(); // หาก Error ให้โหลดข้อมูลใหม่กลับมา
    }
  }

  Future<void> _unfollowOrganizer(int index) async {
    final org = _followedOrganizers[index];
    final orgId = org['organizerId'];

    if (mounted) {
      setState(() {
         _followedOrganizers.removeAt(index);
      });
    }

    try {
      await ApiProvider().post('/users/$orgId/follow');
    } catch (e) {
      _fetchFavourites();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: false,
      backgroundColor: Colors.white,
      appBar: const AppBarSubMain(title: 'Favourite', isBack: true),
      body: Container(
        padding: const EdgeInsets.all(15),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : ListView(
          children: [
            // --- ส่วนหัวข้อ "เกมที่บันทึก" ---
            _buildSectionHeader(context, title: 'เกมที่บันทึก'),
            const SizedBox(height: 16),
                if (_bookmarkedGames.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 32.0),
                    child: Center(child: Text('ยังไม่มีเกมที่บันทึกไว้', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ..._bookmarkedGames.asMap().entries.map((entry) {
                    final index = entry.key;
                    final game = entry.value;
                    final formattedDateTime = formatSessionStart(game['sessionStart'] ?? DateTime.now().toIso8601String());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: GameCard2(
                        teamName: game['groupName'] ?? 'N/A',
                        imageUrl: game['imageUrl'] ?? 'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
                        day: formattedDateTime['day'] ?? 'Mon',
                        date: '${game['dayOfWeek']} ${game['sessionDate']}'.trim(),
                        time: '${game['startTime']}-${game['endTime']}',
                        courtName: game['courtName'] ?? 'N/A',
                        location: game['location'] ?? '-',
                        price: 'สนาม ${game['courtFeePerPerson'] ?? game['courtFee'] ?? '-'} บ.\nลูก ${(game['costingMethod'] == 2) ? 'เหมาจ่าย' : '${game['shuttlecockFeePerPerson'] ?? game['shuttlecockFee'] ?? '-'} บ.'}',
                        shuttlecockInfo: game['shuttlecockModelName'] ?? '-',
                        shuttlecockBrand: game['shuttlecockBrandName'] ?? '-',
                        gameInfo: game['gameTypeName'] ?? '-',
                        currentPlayers: game['currentParticipants'] ?? 0,
                        maxPlayers: game['maxParticipants'] ?? 0,
                        organizerName: game['organizerName'] ?? 'N/A',
                        organizerImageUrl: game['organizerImageUrl'] ?? 'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
                        isInitiallyBookmarked: true,
                        onBookmarkTap: (val) => _toggleBookmark(index, val),
                        onCardTap: () {
                          final imageUrlsFromApi = game['courtImageUrls'] as List<dynamic>? ?? [];
                          final List<String> courtImageUrls = List<String>.from(imageUrlsFromApi);
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
                            courtImageUrls: courtImageUrls.isNotEmpty ? courtImageUrls : ['https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png'],
                            status: game['status'] ?? 1,
                            currentUserStatus: game['userStatus'] ?? 'NotJoined',
                            courtFee: double.tryParse((game['courtFeePerPerson'] ?? game['courtFee'])?.toString() ?? ''),
                            shuttleFee: double.tryParse((game['shuttlecockFeePerPerson'] ?? game['shuttlecockFee'])?.toString() ?? ''),
                            isBuffet: game['costingMethod'] == 2,
                            sessionStart: game['sessionStart'] ?? DateTime.now().toIso8601String(),
                          );
                          context.push('/booking-confirm', extra: bookingDetails);
                        },
                      ),
                    );
                  }),

            // --- ส่วนหัวข้อ "ผู้จัดที่ชอบ" ---
            _buildSectionHeader(context, title: 'ผู้จัดที่ชอบ'),
            const SizedBox(height: 16),

                if (_followedOrganizers.isEmpty)
                  const Center(child: Text('ยังไม่มีผู้จัดที่ชื่นชอบ', style: TextStyle(color: Colors.grey)))
                else
                  ..._followedOrganizers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final org = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: GestureDetector(
                          onTap: () {
                            final orgId = org['organizerId'];
                            if (orgId != null) {
                              context.go('/search-user?organizerId=$orgId');
                            }
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundImage: NetworkImage(
                                  org['profilePhotoUrl'] ?? "https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png",
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      org['nickname'] ?? 'N/A',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text("จำนวนครั้งที่จัด ${org['totalHosted'] ?? 0} ครั้ง"),
                                    Text("จำนวนที่ยกเลิกจัด ${org['totalCancelled'] ?? 0} ครั้ง"),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.favorite, color: Colors.red),
                                onPressed: () => _unfollowOrganizer(index),
                              )
                            ],
                          ),
                        ),
                      );
                  }),
          ],
        ),
      ),
    );
  }

  // Widget สำหรับสร้าง Header ของแต่ละ Section
  Widget _buildSectionHeader(BuildContext context, {required String title}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: () {},
          child: const SizedBox(), // ปิดดูเพิ่มเติมไปก่อน เพราะในหน้านี้โหลดมาหมดแล้ว
        ),
      ],
    );
  }
}
