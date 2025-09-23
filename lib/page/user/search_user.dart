import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/filter_option.dart';
import 'package:badminton/component/game_card2.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/page/user/booking_confirm.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchUserPage extends StatefulWidget {
  const SearchUserPage({super.key});

  @override
  SearchUserPageState createState() => SearchUserPageState();
}

class SearchUserPageState extends State<SearchUserPage> {
  late TextEditingController searchController;
  Map<String, List<String>>? _appliedFilters;
  String? _selectedItem;
  final List<String> _items = [
    'ล่าสุด',
    'ยอดนิยม',
    'วันที่',
    'ใกล้ฉัน',
    'ค่าสนาม',
    'ค่าลูก',
  ];

  @override
  void initState() {
    searchController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
              child: ListView.builder(
                itemCount: dataList.length,
                itemBuilder: (context, index) {
                  final game = dataList[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    child: GameCard2(
                      teamName: game['teamName'],
                      imageUrl: game['imageUrl'],
                      day: game['day'],
                      date: game['date'],
                      time: game['time'],
                      courtName: game['courtName'],
                      location: game['location'],
                      price: game['price'],
                      shuttlecockInfo: game['shuttlecockInfo'],
                      gameInfo: game['gameInfo'],
                      currentPlayers: game['currentPlayers'],
                      maxPlayers: game['maxPlayers'],
                      organizerName: game['organizerName'],
                      organizerImageUrl: game['organizerImageUrl'],
                      isInitiallyBookmarked: game['isInitiallyBookmarked'],
                      onCardTap: () {
                        final bookingDetails = BookingDetails(
                          code: '1',
                          teamName: game['teamName'],
                          imageUrl: game['imageUrl'],
                          day: game['day'],
                          date: game['date'],
                          time: game['time'],
                          courtName: game['courtName'],
                          location: game['location'],
                          price: game['price'],
                          shuttlecockInfo: game['shuttlecockInfo'],
                          gameInfo: game['gameInfo'],
                          currentPlayers: game['currentPlayers'],
                          maxPlayers: game['maxPlayers'],
                          organizerName: game['organizerName'],
                          organizerImageUrl: game['organizerImageUrl'],
                          address: '123/456 สนามแบดมินตัน ABC, กรุงเทพ 10240',
                          courtImageUrls: [
                            'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
                            'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
                            'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
                            'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
                          ],
                          status: '',
                        );
                        context.push('/booking-confirm', extra: bookingDetails);
                      },
                      onTapOrganizer: () => showUserProfileDialog(context),
                      onTapPlayers: () =>
                          context.push('/player-list/${game['teamName']}'),
                    ),
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
