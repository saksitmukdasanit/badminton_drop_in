import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/filter_option.dart';
import 'package:badminton/component/game_card2.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/page/user/booking_confirm.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchUserPage extends StatefulWidget {
  const SearchUserPage({super.key});

  @override
  SearchUserPageState createState() => SearchUserPageState();
}

class SearchUserPageState extends State<SearchUserPage> {
  late Future<List<dynamic>> _upcomingGamesFuture;
  late TextEditingController searchController;
  Map<String, List<String>>? _appliedFilters;
  String? _selectedItem;

  final List<dynamic> _items = [
    {"code": 1, "value": 'ล่าสุด'},
    {"code": 2, "value": 'ยอดนิยม'},
    {"code": 3, "value": 'วันที่'},
    {"code": 4, "value": 'ใกล้ฉัน'},
    {"code": 5, "value": 'ค่าสนาม'},
    {"code": 6, "value": 'ค่าลูก'},
  ];

  @override
  void initState() {
    searchController = TextEditingController();
    _upcomingGamesFuture = _fetchUpcomingGames();
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _fetchUpcomingGames() async {
    try {
      final response = await ApiProvider().get('/GameSessions/upcoming');
      if (response['status'] == 200) {
        return response['data']; // คืนค่า List ของข้อมูลก๊วน
      } else {
        throw Exception('Invalid API response format');
      }
    } catch (e) {
      // โยน Error ออกไปเพื่อให้ FutureBuilder จัดการ
      throw Exception('Failed to load upcoming games: $e');
    }
  }

  

  Future<void> _showFilter(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // *** สำคัญมาก: ทำให้ Bottom Sheet ขยายเต็มจอได้
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FilterBottomSheet();
      },
    );

    if (result != null) {
      // 4. อัปเดต State เพื่อให้หน้าจอแสดงผลใหม่
      setState(() {
        _appliedFilters = result;
      });

      // คุณสามารถนำค่า _appliedFilters ไปใช้กรองข้อมูลต่อได้เลย
      print('Filters applied: $_appliedFilters');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'หาก๊วน', isBack: false),
      body: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CustomTextFormField(
              labelText: 'พิมพ์เพื่อค้นหา...',
              hintText: '',
              controller: searchController,
              suffixIconData: Icons.filter_list,
              onSuffixIconPressed: () {
                setState(() {
                  _showFilter(context);
                });
              },
            ),

            const SizedBox(height: 15),
            CustomDropdown(
              labelText: 'จัดเรียงตาม',
              initialValue: _selectedItem,
              items: _items,
              // isRequired: true,
              onChanged: (value) {
                setState(() {
                  _selectedItem = value;
                });
              },
            ),

            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _upcomingGamesFuture, // ใช้ Future ที่เราสร้างไว้
                builder: (context, snapshot) {
                  // --- กรณี 1: กำลังโหลดข้อมูล ---
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // --- กรณี 2: เกิด Error ---
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                    );
                  }
                  // --- กรณี 3: ไม่มีข้อมูล ---
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('ไม่พบก๊วนที่กำลังจะมาถึง'),
                    );
                  }

                  // --- กรณี 4: มีข้อมูล ---
                  final games = snapshot.data!;
                  return ListView.builder(
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      final game = games[index];
                      // แปลงวันที่เวลา
                      final formattedDateTime = formatSessionStart(
                        game['sessionStart'],
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 10),
                        child: GameCard2(
                          // --- ใช้ข้อมูลจาก API ---
                          teamName: game['groupName'] ?? 'N/A',
                          imageUrl: game['imageUrl'], // Placeholder
                          day: formattedDateTime['day']!,
                          date: '${game['dayOfWeek']} ${game['sessionDate']}',
                          time: '${game['startTime']}-${game['endTime']}',
                          courtName:
                              game['courtName'] ??
                              'N/A', // แสดงชื่อสนาม+ที่อยู่รวมกันไปก่อน
                          location:
                              game['location'], // ไม่มีข้อมูล location แยก
                          price: game['price'], // ไม่มีข้อมูลราคา
                          shuttlecockInfo: game['shuttlecockModelName'],
                          shuttlecockBrand: game['shuttlecockBrandName'],
                          gameInfo: game['gameTypeName'],
                          currentPlayers: game['currentParticipants'] ?? 0,
                          maxPlayers: game['maxParticipants'] ?? 0,
                          organizerName:
                              game['organizerName'], // ไม่มีข้อมูลผู้จัด
                          organizerImageUrl:
                              game['organizerImageUrl'] ?? "", // Placeholder
                          isInitiallyBookmarked: false,
                          onCardTap: () {
                            final imageUrlsFromApi =
                                game['courtImageUrls'] as List<dynamic>? ??
                                []; // ดึงมาเป็น List<dynamic> และป้องกันค่า null
                            final List<String> courtImageUrls =
                                List<String>.from(
                                  imageUrlsFromApi,
                                ); // แปลงเป็น List<String>
                            final bookingDetails = BookingDetails(
                              code: game['sessionId'],
                              teamName: game['groupName'],
                              imageUrl: game['imageUrl'],
                              day: formattedDateTime['day']!,
                              date:
                                  '${game['dayOfWeek']} ${game['sessionDate']}',
                              time: '${game['startTime']}-${game['endTime']}',
                              courtName: game['courtName'],
                              location: game['location'],
                              price: game['price'],
                              shuttlecockInfo: game['shuttlecockModelName'],
                              shuttlecockBrand: game['shuttlecockBrandName'],
                              gameInfo: game['gameTypeName'],
                              courtNumbers: game['courtNumbers'],
                              currentPlayers: game['currentParticipants'] ?? 0,
                              maxPlayers: game['maxParticipants'] ?? 0,
                              organizerName: game['organizerName'],
                              organizerImageUrl: game['organizerImageUrl'],
                              courtImageUrls: courtImageUrls,
                              status: game['status'],
                              notes: game['notes'],
                            );
                            context.push(
                              '/booking-confirm',
                              extra: bookingDetails,
                            );
                          },
                          onTapOrganizer: () => showUserProfileDialog(context),
                          onTapPlayers: () => context.push(
                            '/player-list/${game['sessionId']}',
                          ), // ใช้ sessionId
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
