import 'dart:async';
import 'dart:math';

import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/text_box.dart';
import 'package:badminton/page/user/booking_confirm.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// class Gang {
//   final int id;
//   final String gangName;
//   final String organizer;
//   final int price;
//   final String status;
//   final String date;

//   Gang({
//     required this.id,
//     required this.gangName,
//     required this.organizer,
//     required this.price,
//     required this.status,
//     required this.date,
//   });
// }

class HistoryUserPage extends StatefulWidget {
  const HistoryUserPage({super.key});

  @override
  HistoryUserPageState createState() => HistoryUserPageState();
}

class HistoryUserPageState extends State<HistoryUserPage> {
  late TextEditingController searchController;
  String? _selectedItem;

  Timer? _debounce;

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
    super.initState();
    searchController = TextEditingController();
    searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _fetchHistoryGames(refresh: true);
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchHistoryGames(refresh: false);
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _fetchHistoryGames(refresh: true);
    });
  }

  Future<void> _fetchHistoryGames({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      if (mounted) setState(() => _isLoadingInitial = true);
    } else {
      if (mounted) setState(() => _isLoadingMore = true);
    }

    try {
      final queryParams = <String, dynamic>{};
      if (searchController.text.isNotEmpty)
        queryParams['keyword'] = searchController.text;
      if (_selectedItem != null) queryParams['sortBy'] = _selectedItem;
      queryParams['page'] = _page;
      queryParams['limit'] = _limit;

      final response = await ApiProvider().get(
        '/player/gamesessions/history',
        queryParameters: queryParams,
      );
      if (response['status'] == 200) {
        final List<dynamic> newData = response['data'] ?? [];
        if (mounted) {
          setState(() {
            if (refresh)
              _games = newData;
            else
              _games.addAll(newData);

            if (newData.length < _limit) _hasMore = false;
            _page++;
          });
        }
      }
    } catch (e) {
      print('Failed to load history games: $e');
    } finally {
      if (mounted)
        setState(() {
          _isLoadingInitial = false;
          _isLoadingMore = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'History', isBack: false),
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
                // setState(() {
                //   _showFilter(context);
                // });
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'กรุณาเลือกเพศ';
                }
                return null;
              },
            ),
            const SizedBox(height: 15),
            _buildHeader(context),
            Expanded(
              child: _isLoadingInitial
                  ? const Center(child: CircularProgressIndicator())
                  : _games.isEmpty
                  ? const Center(child: Text('ไม่พบประวัติก๊วน'))
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
                        return _buildGangRow(_games[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget สำหรับ Header ของตาราง
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'วันเวลา',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ชื่อก๊วน',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'ผู้จัด',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'จ่าย',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'สถานะ',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDisplay(dynamic status) {
    final matches = statusColors.where((d) => d['code'] == status.toString());
    if (matches.isNotEmpty) return matches.first['display'];

    if (status == 1 || status == 2) return 'สำเร็จ';
    if (status == 3 || status == 4) return 'ยกเลิก';
    return 'สำเร็จ';
  }

  Color _getStatusColor(dynamic status) {
    final matches = statusColors.where((d) => d['code'] == status.toString());
    if (matches.isNotEmpty) return matches.first['color'];

    if (status == 3 || status == 4) return const Color(0xFF64646D);
    return const Color(0xFF0E9D7A);
  }

  // Widget สำหรับแสดงข้อมูลผู้เล่นแต่ละแถว
  Widget _buildGangRow(dynamic game) {
    final formattedDateTime = formatSessionStart(
      game['sessionStart'] ?? DateTime.now().toIso8601String(),
    );
    final courtFee = game['courtFeePerPerson'] ?? game['courtFee'] ?? '0';
    final shuttleFee =
        game['shuttlecockFeePerPerson'] ?? game['shuttlecockFee'] ?? '0';
    final totalCost =
        (double.tryParse(courtFee.toString()) ?? 0) +
        (double.tryParse(shuttleFee.toString()) ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${game['sessionDate']} ${game['startTime']}',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 10),
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              game['groupName'] ?? 'N/A',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              game['organizerName'] ?? 'N/A',
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              totalCost.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () {
                final imageUrlsFromApi =
                    game['courtImageUrls'] as List<dynamic>? ?? [];
                final List<String> courtImageUrls = List<String>.from(
                  imageUrlsFromApi,
                );
                final data = BookingDetails(
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
                    (game['courtFeePerPerson'] ?? game['courtFee'])
                            ?.toString() ??
                        '',
                  ),
                  shuttleFee: double.tryParse(
                    (game['shuttlecockFeePerPerson'] ?? game['shuttlecockFee'])
                            ?.toString() ??
                        '',
                  ),
                  isBuffet: game['costingMethod'] == 2,
                  sessionStart: game['sessionStart'] ?? DateTime.now().toIso8601String(),
                );
                context.push('/booking-confirm-history', extra: data);
              },
              child: Text(
                _getStatusDisplay(game['status']),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 14),
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(game['status']),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
