import 'dart:async';
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
  final String? organizerId;
  const SearchUserPage({super.key, this.organizerId});

  @override
  SearchUserPageState createState() => SearchUserPageState();
}

class SearchUserPageState extends State<SearchUserPage> {
  late TextEditingController searchController;
  Map<String, List<String>>? _appliedFilters;
  String? _selectedItem;
  String? _organizerIdFilter;
  Timer? _debounce; // สร้างตัวแปรหน่วงเวลา

  int _page = 1;
  final int _limit = 10;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<dynamic> _games = [];
  final ScrollController _scrollController = ScrollController();

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
    // ผูก Listener กับฟังก์ชันที่มี Debounce ป้องกันการยิง API รัวๆ
    searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _organizerIdFilter = widget.organizerId;
    _fetchUpcomingGames(refresh: true);
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // เมื่อเลื่อนถึงขอบล่างของจอ จะทำการโหลดหน้าถัดไป
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchUpcomingGames(refresh: false);
      }
    }
  }

  void _onSearchChanged() {
    // ถ้ากำลังพิมพ์อยู่ ให้ยกเลิก Timer เดิม แล้วเริ่มนับใหม่ 500ms
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchUpcomingGames(refresh: true);
      }
    });
  }

  Future<void> _fetchUpcomingGames({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      if (mounted) setState(() => _isLoadingInitial = true);
    } else {
      if (mounted) setState(() => _isLoadingMore = true);
    }

    try {
      // แปะค่าการค้นหาและการจัดเรียงส่งไปให้ API (Query Params)
      final queryParams = <String, dynamic>{};
      if (searchController.text.isNotEmpty)
        queryParams['keyword'] = searchController.text;
      if (_selectedItem != null) queryParams['sortBy'] = _selectedItem;
      if (_organizerIdFilter != null)
        queryParams['organizerId'] = _organizerIdFilter;
      queryParams['page'] = _page;
      queryParams['limit'] = _limit;

      final response = await ApiProvider().get(
        '/player/gamesessions/upcoming',
        queryParameters: queryParams,
      );
      if (response['status'] == 200) {
        final List<dynamic> newData = response['data'] ?? [];
        if (mounted) {
          setState(() {
            if (refresh) {
              _games = newData;
            } else {
              _games.addAll(newData);
            }

            // ถ้าข้อมูลที่ได้มาน้อยกว่า limit แสดงว่าหมดแล้ว
            if (newData.length < _limit) {
              _hasMore = false;
            }
            _page++;
          });
        }
      } else {
        throw Exception('Invalid API response format');
      }
    } catch (e) {
      print('Failed to load upcoming games: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _isLoadingMore = false;
        });
      }
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

  // เพิ่มฟังก์ชันสำหรับจัดการ Bookmark
  Future<void> _toggleBookmark(int index, bool isBookmarked) async {
    final game = _games[index];
    final sessionId = game['sessionId'];

    // Optimistic UI update
    setState(() {
      _games[index]['isBookmarked'] = isBookmarked;
    });

    try {
      if (isBookmarked) {
        await ApiProvider().post('/player/gamesessions/$sessionId/bookmark');
      } else {
        await ApiProvider().delete('/player/gamesessions/$sessionId/bookmark');
      }
    } catch (e) {
      // Revert UI on error
      if (mounted) {
        setState(() {
          _games[index]['isBookmarked'] = !isBookmarked;
        });
      }
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
            colors: [const Color(0xFFFFFFFF), const Color(0xFFCBF5EA)],
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
              onSuffixIconPressed: () => _showFilter(context),
            ),

            const SizedBox(height: 15),
            CustomDropdown(
              labelText:
                  'จัดเรียงตาม', // Dropdown นี้จะทำงานได้แล้วเพราะ Logic ใน build
              initialValue: _selectedItem,
              items: _items,
              // isRequired: true,
              onChanged: (value) {
                setState(() {
                  _selectedItem = value;
                  _fetchUpcomingGames(refresh: true);
                });
              },
            ),

            Expanded(
              child: _isLoadingInitial
                  ? const Center(child: CircularProgressIndicator())
                  : _games.isEmpty
                  ? const Center(child: Text('ไม่พบก๊วนที่กำลังจะมาถึง'))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _games.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _games.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final game = _games[index];
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
                            price:
                                'สนาม ${game['courtFeePerPerson'] ?? game['courtFee'] ?? '-'} บ.\nลูก ${(game['costingMethod'] == 2) ? 'เหมาจ่าย' : '${game['shuttlecockFeePerPerson'] ?? game['shuttlecockFee'] ?? '-'} บ.'}',
                            shuttlecockInfo: game['shuttlecockModelName'],
                            shuttlecockBrand: game['shuttlecockBrandName'],
                            gameInfo: game['gameTypeName'],
                            currentPlayers: game['currentParticipants'] ?? 0,
                            maxPlayers: game['maxParticipants'] ?? 0,
                            organizerName:
                                game['organizerName'], // ไม่มีข้อมูลผู้จัด
                            organizerImageUrl:
                                game['organizerImageUrl'] ?? "", // Placeholder
                            // แก้ไข: ดึงสถานะ Bookmark จริงจาก API
                            isInitiallyBookmarked:
                                game['isBookmarked'] ?? false,
                            // เพิ่ม: รับค่าเมื่อกดหัวใจ
                            onBookmarkTap: (val) => _toggleBookmark(index, val),
                            // หมายเหตุ: หาก GameCard2 มี callback onBookmarkTap ให้ใส่ Logic ตรงนี้
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
                                currentPlayers:
                                    game['currentParticipants'] ?? 0,
                                maxPlayers: game['maxParticipants'] ?? 0,
                                organizerName: game['organizerName'],
                                organizerImageUrl: game['organizerImageUrl'],
                                courtImageUrls: courtImageUrls,
                                status: game['status'],
                                notes: game['notes'],
                                currentUserStatus:
                                    game['userStatus'] ??
                                    'NotJoined', // ส่งค่าจาก API
                                courtFee: double.tryParse(
                                  (game['courtFeePerPerson'] ??
                                              game['courtFee'])
                                          ?.toString() ??
                                      '',
                                ),
                                shuttleFee: double.tryParse(
                                  (game['shuttlecockFeePerPerson'] ??
                                              game['shuttlecockFee'])
                                          ?.toString() ??
                                      '',
                                ),
                                isBuffet:
                                    game['costingMethod'] ==
                                    2, // 1 = คิดตามเกม, 2 = เหมาจ่าย
                                sessionStart: game['sessionStart'] ?? DateTime.now().toIso8601String(),
                              );
                              context.push(
                                '/booking-confirm',
                                extra: bookingDetails,
                              );
                            },
                                onTapOrganizer: () async {
                                  // โชว์ Loading ก่อนเปิด Dialog
                                  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                                  
                                  try {
                                    final res = await ApiProvider().get('/player/gamesessions/${game['sessionId']}/organizer-summary');
                                    if (!context.mounted) return;
                                    Navigator.of(context, rootNavigator: true).pop(); // ปิด Loading
                                    
                                    if (res['status'] == 200 && res['data'] != null) {
                                      final data = res['data'];
                                      showUserProfileDialog(
                                        context,
                                        imageUrl: data['profilePhotoUrl'] ?? game['organizerImageUrl'] ?? '',
                                        name: data['nickname'] ?? game['organizerName'] ?? 'N/A',
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
                                    Navigator.of(context, rootNavigator: true).pop(); // ปิด Loading กรณี Error
                                    showUserProfileDialog(context, imageUrl: game['organizerImageUrl'] ?? '', name: game['organizerName'] ?? 'N/A');
                                  }
                                },
                            onTapPlayers: () => context.push(
                              '/player-list/${game['sessionId']}',
                            ), // ใช้ sessionId
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
