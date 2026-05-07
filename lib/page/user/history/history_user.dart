import 'dart:async';

import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/skeleton.dart';
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
  final int _limit = 5; // เปลี่ยนให้ดึงข้อมูลทีละ 5 รายการ ตามที่คุณต้องการ
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<dynamic> _games = [];
  final ScrollController _scrollController = ScrollController();

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

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'เรียงลำดับประวัติ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('วันที่จัดก๊วน (ล่าสุดก่อน)'),
                trailing: (_selectedItem == 'latest' || _selectedItem == null) ? const Icon(Icons.check, color: Color(0xFF0E9D7A)) : null,
                onTap: () {
                  setState(() => _selectedItem = 'latest');
                  Navigator.pop(context);
                  _fetchHistoryGames(refresh: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('วันที่จัดก๊วน (เก่าสุดก่อน)'),
                trailing: _selectedItem == 'oldest' ? const Icon(Icons.check, color: Color(0xFF0E9D7A)) : null,
                onTap: () {
                  setState(() => _selectedItem = 'oldest');
                  Navigator.pop(context);
                  _fetchHistoryGames(refresh: true);
                },
              ),
            ],
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
              hintText: 'ชื่อก๊วน, ชื่อสนาม, หรือผู้จัด',
              controller: searchController,
              suffixIconData: Icons.sort,
              onSuffixIconPressed: () {
                _showSortOptions(context);
              },
            ),
            const SizedBox(height: 15),
            Expanded(
              child: _isLoadingInitial
                  ? const SessionCardListSkeleton()
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

  String _getStatusDisplay(dynamic game) {
    final status = game['status'];
    final userStatus = game['userStatus'];

    if (userStatus == 'Refund') return 'รอคืนเงิน';
    if (status == 5 || userStatus == 'PendingPayment' || userStatus == 'Unpaid') return 'ค้างชำระ';
    if (status == 3) return 'ยกเลิก';
    if (status == 1 || status == 2 || status == 4) return 'สำเร็จ';
    
    return 'สำเร็จ';
  }

  Color _getStatusColor(dynamic game) {
    final status = game['status'];
    final userStatus = game['userStatus'];

    if (userStatus == 'Refund') return Colors.orange;
    if (status == 5 || userStatus == 'PendingPayment' || userStatus == 'Unpaid') return Colors.red;
    if (status == 3) return const Color(0xFF64646D);
    
    return const Color(0xFF0E9D7A);
  }

  // Widget สำหรับแสดงข้อมูลผู้เล่นแต่ละแถว
  Widget _buildGangRow(dynamic game) {
    final formattedDateTime = formatSessionStart(
      game['sessionStart'] ?? DateTime.now().toIso8601String(),
    );
    final priceDisplay = game['price']?.replaceAll(' บาท', '') ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final imageUrlsFromApi =
              game['courtImageUrls'] as List<dynamic>? ?? [];
          final List<String> courtImageUrls = List<String>.from(imageUrlsFromApi);
          
          String sessionStartStr = game['sessionStart'] ?? '';
          if (sessionStartStr.isEmpty) {
            String d = game['sessionDate'] ?? '';
            String t = game['startTime'] ?? '';
            if (d.isNotEmpty && t.isNotEmpty) {
               d = d.split('T')[0];
               sessionStartStr = '${d}T$t';
               if (t.length == 5) sessionStartStr += ':00';
            } else {
               sessionStartStr = DateTime.now().toIso8601String();
            }
          }
          
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
                : ['https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png'],
            status: game['status'] ?? 1,
            currentUserStatus: game['userStatus'] ?? 'Joined',
            courtFee: double.tryParse((game['courtFeePerPerson'] ?? game['courtFee'])?.toString() ?? ''),
            shuttleFee: double.tryParse((game['shuttlecockFeePerPerson'] ?? game['shuttlecockFee'])?.toString() ?? ''),
            isBuffet: game['costingMethod'] == 2,
            sessionStart: sessionStartStr,
          );
          context.push('/booking-confirm-history', extra: data).then((_) {
            _fetchHistoryGames(refresh: true);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      game['groupName'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: getResponsiveFontSize(context, fontSize: 16),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(game).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusDisplay(game),
                      style: TextStyle(
                        color: _getStatusColor(game),
                        fontSize: getResponsiveFontSize(context, fontSize: 12),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${game['sessionDate']} ${game['startTime']}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: getResponsiveFontSize(context, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'ผู้จัด: ${game['organizerName'] ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: getResponsiveFontSize(context, fontSize: 13),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '฿ $priceDisplay',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: getResponsiveFontSize(context, fontSize: 15),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
