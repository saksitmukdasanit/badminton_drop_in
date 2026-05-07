import 'dart:async';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/filter_option.dart';
import 'package:badminton/component/game_card.dart';
import 'package:badminton/component/skeleton.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/page/user/search/search_sessions_map.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/booking_details_mapper.dart';
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
  /// รายการกว้างสำหรับโหมดแผนที่ (sync จาก API เป็นชุดเดียวกับตัวกรอง แต่ limit ใหญ่กว่า)
  List<dynamic> _mapGames = [];
  bool _syncingMapPins = false;
  int _viewMode = 0; // 0 = รายการ, 1 = แผนที่
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

  Map<String, dynamic> _buildUpcomingQueryParams({required int page, required int limit}) {
    final queryParams = <String, dynamic>{'page': page, 'limit': limit};
    if (searchController.text.isNotEmpty) {
      queryParams['keyword'] = searchController.text;
    }
    if (_selectedItem != null) {
      queryParams['sortBy'] = _selectedItem;
    }
    if (_organizerIdFilter != null) {
      queryParams['organizerId'] = _organizerIdFilter;
    }

    if (_appliedFilters != null) {
      final dayThaiToEnum = <String, String>{
        'จันทร์': 'Monday',
        'อังคาร': 'Tuesday',
        'พุธ': 'Wednesday',
        'พฤหัสบดี': 'Thursday',
        'ศุกร์': 'Friday',
        'เสาร์': 'Saturday',
        'อาทิตย์': 'Sunday',
      };

      final selectedDays = _appliedFilters!['วันที่จัด']
          ?.map((thai) => dayThaiToEnum[thai])
          .whereType<String>()
          .toList();
      if (selectedDays != null && selectedDays.isNotEmpty) {
        queryParams['daysOfWeek'] = selectedDays.join(',');
      }
    }

    return queryParams;
  }

  Future<void> _syncMapPins() async {
    setState(() => _syncingMapPins = true);
    try {
      final qp = _buildUpcomingQueryParams(page: 1, limit: 150);
      final response = await ApiProvider().get(
        '/player/gamesessions/upcoming',
        queryParameters: qp,
      );
      if (response['status'] == 200 && mounted) {
        setState(() {
          _mapGames = response['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('sync map pins failed: $e');
    } finally {
      if (mounted) {
        setState(() => _syncingMapPins = false);
      }
    }
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
      final queryParams = _buildUpcomingQueryParams(page: _page, limit: _limit);

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

            if (newData.length < _limit) {
              _hasMore = false;
            }
            _page++;
          });
          if (refresh) {
            unawaited(_syncMapPins());
          }
        }
      } else {
        throw Exception('Invalid API response format');
      }
    } catch (e) {
      debugPrint('Failed to load upcoming games: $e');
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
      setState(() {
        _appliedFilters = result;
      });
      // ดึงข้อมูลใหม่หลัง apply filter (ก่อนหน้านี้ filter ถูกเก็บแต่ไม่มีผลกับ API)
      _fetchUpcomingGames(refresh: true);
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

  void _openBookingConfirm(BuildContext context, Map<String, dynamic> game) {
    final details = bookingDetailsFromUpcomingCardMap(game);
    context.push('/booking-confirm', extra: details);
  }

  Widget _buildMainContent() {
    if (_viewMode == 1) {
      return SearchSessionsMapView(
        games: _mapGames,
        isLoadingOverlay: _syncingMapPins,
      );
    }

    if (_games.isEmpty) {
      return const Center(child: Text('ไม่พบก๊วนที่กำลังจะมาถึง'));
    }

    return ListView.builder(
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
        final formattedDateTime = formatSessionStart(game['sessionStart']);
        return Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: GameCard(
            teamName: game['groupName'] ?? 'N/A',
            imageUrl: game['imageUrl'] ?? 'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
            day: formattedDateTime['day']!,
            date: '${game['dayOfWeek']} ${game['sessionDate']}',
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
                game['organizerImageUrl'] ?? 'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
            isInitiallyBookmarked: game['isBookmarked'] ?? false,
            onBookmarkTap: (val) => _toggleBookmark(index, val),
            onCardTap: () => _openBookingConfirm(
              context,
              Map<String, dynamic>.from(game as Map),
            ),
            onTapOrganizer: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final res = await ApiProvider()
                    .get('/player/gamesessions/${game['sessionId']}/organizer-summary');
                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true).pop();

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
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(context, rootNavigator: true).pop();
                showUserProfileDialog(
                  context,
                  imageUrl: game['organizerImageUrl'] ?? '',
                  name: game['organizerName'] ?? 'N/A',
                );
              }
            },
            onTapPlayers: () => context.push(
              '/player-list/${game['sessionId']}',
            ),
          ),
        );
      },
    );
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
                  ? const SessionCardListSkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment<int>(
                              value: 0,
                              label: Text('รายการ'),
                              icon: Icon(Icons.list),
                            ),
                            ButtonSegment<int>(
                              value: 1,
                              label: Text('แผนที่'),
                              icon: Icon(Icons.map_outlined),
                            ),
                          ],
                          selected: {_viewMode},
                          onSelectionChanged: (Set<int> next) {
                            setState(() => _viewMode = next.first);
                          },
                        ),
                        const SizedBox(height: 10),
                        Expanded(child: _buildMainContent()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
