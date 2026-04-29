// --- Widget หลัก สามารถนำไปใส่ใน Scaffold(body: HistoryOrganizerPage()) ---
import 'dart:async';

import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/details_card.dart'; // Import Widget กลาง
import 'package:badminton/component/text_box.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HistoryOrganizerPage extends StatefulWidget {
  const HistoryOrganizerPage({super.key});

  @override
  State<HistoryOrganizerPage> createState() => _HistoryOrganizerPageState();
}

class _HistoryOrganizerPageState extends State<HistoryOrganizerPage> {
  late TextEditingController searchController;
  // State สำหรับเก็บรายการที่เลือก
  dynamic _selectedItem;
  List<dynamic> history = [];
  Map<String, dynamic>? _sessionDetail;
  bool _isDetailLoading = false;
  Map<String, dynamic>? _analyticsData;
  bool _isAnalyticsLoading = false;
  bool isLoading = false;

  int _page = 1;
  final int _limit = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  void _backToList() {
    setState(() {
      _selectedItem = null;
      _sessionDetail = null;
      _analyticsData = null;
    });
  }

  @override
  void initState() {
    searchController = TextEditingController();
    searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _fetchHistory(refresh: true);
    super.initState();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchHistory(refresh: false);
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _fetchHistory(refresh: true);
    });
  }

  Future<void> _fetchHistory({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      setState(() => isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final queryParams = <String, dynamic>{
        'page': _page,
        'limit': _limit,
      };
      if (searchController.text.isNotEmpty) {
        queryParams['keyword'] = searchController.text;
      }

      final response = await ApiProvider().get('/GameSessions/my-history', queryParameters: queryParams);
      if (response['status'] == 200) {
        final List<dynamic> newData = response['data'] ?? [];
        setState(() {
          if (refresh) {
            history = newData;
          } else {
            history.addAll(newData);
          }
          if (newData.length < _limit) _hasMore = false;
          _page++;
          isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      // --- FIX: เช็ค mounted ก่อน setState ป้องกัน Error เมื่อถูกดีดไปหน้า Login ---
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAnalytics(int sessionId) async {
    setState(() {
      _isAnalyticsLoading = true;
      _analyticsData = null;
    });
    try {
      final response = await ApiProvider().get(
        '/GameSessions/$sessionId/analytics',
      );
      if (mounted && response['status'] == 200) {
        setState(() {
          _analyticsData = response['data'];
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isAnalyticsLoading = false);
    }
  }

  Future<void> _fetchSessionDetail(int sessionId) async {
    setState(() {
      _isDetailLoading = true;
      _sessionDetail = null;
    });
    try {
      final response = await ApiProvider().get('/GameSessions/$sessionId');
      if (mounted && response['status'] == 200) {
        setState(() {
          _sessionDetail = response['data'];
          // --- FIX: เติมข้อมูลการเงินจาก _selectedItem (ที่ได้จากหน้า List) ลงไปใน _sessionDetail ---
          if (_selectedItem != null) {
             _sessionDetail!['paidAmount'] = _selectedItem['paidAmount'];
             _sessionDetail!['totalIncome'] = _selectedItem['totalIncome'];
          }
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isDetailLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarSubMain(title: 'ประวัติการจัดก๊วน', isBack: false),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: historyList(context)),
                Expanded(
                  flex: 1,
                  child: _selectedItem != null
                      ? _buildDetailsColumn(context)
                      : const Center(child: Text('กรุณาเลือกรายการ')),
                ),
                Expanded(
                  flex: 1,
                  child: _selectedItem != null
                      ? _buildAnalyticsColumn(context)
                      : const SizedBox(),
                ),
              ],
            );
          } else if (constraints.maxWidth > 600) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: historyList(context)),
                Expanded(
                  flex: 6,
                  child: _selectedItem != null
                      ? detailsView(context, item: _selectedItem, onBack: null)
                      : const Center(child: Text('กรุณาเลือกรายการ')),
                ),
              ],
            );
          }
          return _selectedItem != null
              ? detailsView(context, item: _selectedItem, onBack: _backToList)
              : historyList(context);
        },
      ),
    );
  }

  Widget historyList(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        controller: _scrollController,
        children: [
          Text(
            'ประวัติการจัดก๊วน',
            style: TextStyle(
              fontSize: getResponsiveFontSize(context, fontSize: 16),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          CustomTextFormField(
            labelText: 'พิมพ์เพื่อค้นหา...',
            hintText: '',
            controller: searchController,
            suffixIconData: Icons.tune_outlined,
            onSuffixIconPressed: () {},
          ),
          const SizedBox(height: 16),
          // ใช้ DataTable เพื่อสร้างตาราง
          Row(
            children: [
              textHistory(2, 'วัน/เวลา', 12, FontWeight.w700),
              textHistory(3, 'ชื่อก๊วน', 12, FontWeight.w700),
              textHistory(2, 'รายได้', 12, FontWeight.w700),
              textHistory(2, 'จ่ายแล้ว', 12, FontWeight.w700),
              textHistory(2, 'ค้างจ่าย', 12, FontWeight.w700),
            ],
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: Text('ไม่พบข้อมูล')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                final dt =
                    DateTime.tryParse(item['date'] ?? '')?.toLocal() ??
                    DateTime.now();
                final dateStr =
                    '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
                final isSelected = item == _selectedItem;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedItem = item;
                    });
                    _fetchAnalytics(item['gameSessionId']);
                    _fetchSessionDetail(item['gameSessionId']);
                  },
                  child: Container(
                    color: isSelected ? Colors.grey[200] : Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        textHistory(2, dateStr, 10, FontWeight.w300),
                        textHistory(
                          3,
                          item['groupName'] ?? '-',
                          10,
                          FontWeight.w300,
                        ),
                        textHistory(
                          2,
                          '${(num.tryParse('${item['totalIncome'] ?? 0}') ?? 0).toStringAsFixed(0)}',
                          10,
                          FontWeight.w300,
                        ),
                        textHistory(
                          2,
                          '${(num.tryParse('${item['paidAmount'] ?? 0}') ?? 0).toStringAsFixed(0)}',
                          10,
                          FontWeight.w300,
                        ),
                        textHistory(
                          2,
                          '${(num.tryParse('${item['unpaidAmount'] ?? 0}') ?? 0).toStringAsFixed(0)}',
                          10,
                          FontWeight.w300,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 120), // เผื่อระยะด้านล่างกัน MenuBar บัง
        ],
      ),
    );
  }

  Widget textHistory(
    int flex,
    String text,
    double fontSize,
    FontWeight fontWeight,
  ) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: getResponsiveFontSize(context, fontSize: fontSize),
          fontWeight: fontWeight,
        ),
      ),
    );
  }

  Widget detailsView(
    BuildContext context, {
    required dynamic item,
    Function()? onBack,
  }) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ปุ่ม Back
            if (onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_back_ios),
                  label: const Text('กลับไปที่รายการ'),
                  onPressed: onBack,
                ),
              ),
            if (_isDetailLoading)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_sessionDetail != null)
              badmintonSummaryPage(context, _sessionDetail)
            else
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: Text('ไม่สามารถโหลดข้อมูลรายละเอียดได้')),
              ),
            badmintonSummaryPage2(context, _analyticsData, _isAnalyticsLoading),
            const SizedBox(height: 120), // เผื่อระยะด้านล่างกัน MenuBar บัง
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsColumn(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            if (_isDetailLoading)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_sessionDetail != null)
              badmintonSummaryPage(context, _sessionDetail)
            else
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: Text('ไม่สามารถโหลดข้อมูลรายละเอียดได้')),
              ),
            const SizedBox(height: 120), // เผื่อระยะด้านล่างกัน MenuBar บัง
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsColumn(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 10,right: 10,bottom: 10),
        child: Column(
          children: [
            badmintonSummaryPage2(
              context,
              _analyticsData,
              _isAnalyticsLoading,
            ),
            const SizedBox(height: 120), // เผื่อระยะด้านล่างกัน MenuBar บัง
          ],
        ),
      ),
    );
  }

  Widget badmintonSummaryPage(BuildContext context, dynamic model) {
    return Column(
      children: [
        GroupInfoCard(model: model),
        SizedBox(height: 10),
        ImageSlideshow(model: model),
        SizedBox(height: 10),
        DetailsCard(model: model),
        SizedBox(height: 10),
        ActionButtons(model: model, onNavigateBack: () {
          _fetchHistory(refresh: true); // บังคับดึงข้อมูลรายการใหม่
          if (model != null && model['gameSessionId'] != null) {
            _fetchSessionDetail(model['gameSessionId']); // โหลดรายละเอียดใหม่
            _fetchAnalytics(model['gameSessionId']); // โหลดสถิติใหม่
          }
        }),
        SizedBox(height: 10),
      ],
    );
  }

  Widget badmintonSummaryPage2(
    BuildContext context,
    Map<String, dynamic>? analytics,
    bool isLoading,
  ) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [
        SummaryCard(data: analytics),
        SizedBox(height: 10),
        GameTimingCard(
          games:
              analytics?['matchHistory'] is List
                  ? analytics!['matchHistory']
                  : [],
        ),
      ],
    );
  }
}

class GroupInfoCard extends StatelessWidget {
  final dynamic model;
  const GroupInfoCard({super.key, this.model});

  @override
  Widget build(BuildContext context) {
    final formattedDateTime = formatSessionStart(
      model['date'] ?? model['sessionStart'] ?? model['sessionDate'] ?? '',
    );
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- ส่วนหัวของการ์ด (Header) ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            color: const Color(0xFF6B7280), // สีเทาเข้ม
            child: Text(
              model['groupName'] ?? '-',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // --- ส่วนเนื้อหา ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                model['venueData'] != null
                    ? model['venueData']['name']
                    : (model['courtName'] ?? model['venueName'] ?? '-'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              subtitle: Text(
                model['venueData'] != null
                    ? model['venueData']['address']
                    : (model['location'] ?? '-'),
                style: TextStyle(fontSize: 16),
              ),
              trailing: Icon(
                Icons.location_on,
                color: Color(0Xff0E9D7A),
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Chip(
              label: Text(
                // --- (แก้ไข) ใช้ข้อมูลจาก parameter ---
                '${formattedDateTime['date']} ${formattedDateTime['time']} น.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
              backgroundColor: dayColors.firstWhere(
                (d) => d['code'] == formattedDateTime['day'],
                orElse: () => {'code': 'N/A', 'display': Colors.grey},
              )['display'],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(width: 0, color: Colors.transparent),
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

// --- Widget ย่อย: สไลด์รูปภาพ ---
class ImageSlideshow extends StatelessWidget {
  final dynamic model;
  const ImageSlideshow({super.key, this.model});

  @override
  Widget build(BuildContext context) {
    String? imageUrl;
    if (model['photoUrls'] is List && (model['photoUrls'] as List).isNotEmpty) {
      imageUrl = model['photoUrls'][0];
    } else if (model['courtImageUrls'] is List &&
        (model['courtImageUrls'] as List).isNotEmpty) {
      imageUrl = model['courtImageUrls'][0];
    } else {
      imageUrl = model['imageUrl'];
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // ทำให้รูปภาพอยู่ในขอบเขตของการ์ด
      elevation: 2,
      child: Column(
        children: [
          // Placeholder สำหรับรูปภาพ
          if (imageUrl != null)
            Image.network(imageUrl, fit: BoxFit.cover)
          else
            Container(
              height: 200,
              color: Colors.grey,
              child: Center(
                child: Icon(Icons.image, size: 50, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Widget ย่อย: ปุ่ม Action ด้านล่าง ---
class ActionButtons extends StatelessWidget {
  final dynamic model;
  final VoidCallback? onNavigateBack;
  const ActionButtons({super.key, this.model, this.onNavigateBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: CustomElevatedButton(
              text: 'สรุปยอดเงิน',
              backgroundColor: Color(0xFFFFFFFF),
              foregroundColor: Color(0xFF0E9D7A),
              fontSize: 11,
              onPressed: () async {
                final sessionId = model['gameSessionId'] ?? model['sessionId'];
                await context.push('/history-organizer-payment', extra: sessionId);
                onNavigateBack?.call();
              },
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: CustomElevatedButton(
              text: 'คัดลอกสร้างเกมใหม่',
              backgroundColor: Color(0xFF0E9D7A),
              foregroundColor: Color(0xFFFFFFFF),
              fontSize: 11,
              onPressed: () {
                if (model != null) {
                  DateTime? historyDate;
                  // พยายามดึงวันที่จาก model
                  if (model['date'] != null) {
                    historyDate = DateTime.tryParse(model['date']);
                  } else if (model['sessionDate'] != null) {
                    historyDate = DateTime.tryParse(model['sessionDate']);
                  } else if (model['sessionStart'] != null) {
                    historyDate = DateTime.tryParse(model['sessionStart']);
                  }

                  DateTime initialDate = DateTime.now();
                  if (historyDate != null) {
                    final now = DateTime.now();
                    int targetWeekday = historyDate.weekday;
                    // คำนวณหาวันถัดไปที่ตรงกับวันในสัปดาห์ของประวัติ (เช่น เคยสร้างวันจันทร์ ก็หาจันทร์ถัดไป)
                    int daysUntil = (targetWeekday - now.weekday + 7) % 7;
                    if (daysUntil == 0) daysUntil = 7; // ถ้าตรงกับวันนี้พอดี ให้เลือกสัปดาห์หน้า
                    initialDate = now.add(Duration(days: daysUntil));
                  }

                  context.push('/add-game/new', extra: {
                    'sessionData': model,
                    'initialDate': initialDate,
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  const SummaryCard({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    // ใช้ Card เป็น Widget หลักเพื่อให้มีขอบโค้งและเงา
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias, // ทำให้ child อยู่ในขอบเขตของ Card
      child: Column(
        children: [
          // --- ส่วนหัวของการ์ด (Header) ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            color: const Color(0xFF6B7280), // สีเทาเข้ม
            child: const Text(
              'สรุปผลการจัดก๊วน',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // --- ส่วนเนื้อหา ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSummaryRow(context, 'ก๊วน', data?['groupName'] ?? '-'),
                _buildSummaryRow(
                  context,
                  'วันที่',
                  data?['date'] != null
                      ? formatSessionStart(data!['date'])['date']!
                      : '-',
                ),
                _buildSummaryRow(
                  context,
                  'ตีทั้งหมด',
                  '${data?['totalGames'] ?? 0}',
                  unit: 'เกม',
                  trailingTitle: 'ใช้ลูก',
                  trailingValue: '${data?['totalShuttlecocks'] ?? 0}',
                  trailingUnit: 'ลูก',
                ),
                _buildSummaryRow(
                  context,
                  'เวลาเริ่มตี',
                  (data?['totalPlayTimeStart']?.toString().isNotEmpty ?? false)
                      ? data!['totalPlayTimeStart']
                      : '-',
                  unit: 'น.',
                  trailingTitle: 'เวลาสิ้นสุดการตี',
                  trailingValue:
                      (data?['totalPlayTimeEnd']?.toString().isNotEmpty ??
                          false)
                      ? data!['totalPlayTimeEnd']
                      : '-',
                  trailingUnit: 'น.',
                ),
                _buildSummaryRow(
                  context,
                  'เวลาตีต่อเกมเฉลี่ย',
                  '${data?['averagePlayTimePerGame'] ?? 0}',
                  unit: 'นาที',
                ),
                _buildSummaryRow(
                  context,
                  'เกมที่ใช้เวลานานสุด',
                  data?['longestGame']?['players'] ?? '-',
                  trailingTitle: 'ใช้เวลา',
                  trailingValue: '${data?['longestGame']?['duration'] ?? 0}',
                  trailingUnit: 'นาที',
                ),
                _buildSummaryRow(
                  context,
                  'เกมที่ใช้เวลาน้อยสุด',
                  data?['shortestGame']?['players'] ?? '-',
                  trailingTitle: 'ใช้เวลา',
                  trailingValue: '${data?['shortestGame']?['duration'] ?? 0}',
                  trailingUnit: 'นาที',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper สำหรับสร้างแต่ละแถวใน Card
  Widget _buildSummaryRow(
    BuildContext context,
    String title,
    String value, {
    String? unit,
    String? trailingTitle,
    String? trailingValue,
    String? trailingUnit,
  }) {
    var titleStyle = TextStyle(
      fontSize: getResponsiveFontSize(context, fontSize: 12),
      color: Colors.black87,
    );
    var valueStyle = TextStyle(
      fontSize: getResponsiveFontSize(context, fontSize: 12),
      color: Color(0xFF0E9D7A),
      fontWeight: FontWeight.bold,
    );
    var unitStyle = TextStyle(
      fontSize: getResponsiveFontSize(context, fontSize: 12),
      color: Colors.black87,
    );

    // FIX: ปรับโครงสร้าง Row เพื่อป้องกัน Overflow และจัด Layout ให้สวยงาม
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title
          Text(title, style: titleStyle),
          const SizedBox(width: 8),

          // 2. Value (Expanded เพื่อให้ยืดหดได้และไม่ดันจนหลุดขอบ)
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(
                  value,
                  style: valueStyle,
                  textAlign: TextAlign.right,
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(unit, style: unitStyle),
                ],
                if (trailingTitle != null) ...[
                  const SizedBox(width: 12),
                  Text(trailingTitle, style: titleStyle),
                ],
                if (trailingValue != null) ...[
                  const SizedBox(width: 4),
                  Text(trailingValue, style: valueStyle),
                  if (trailingUnit != null) const SizedBox(width: 4),
                  if (trailingUnit != null) Text(trailingUnit, style: unitStyle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Widget ย่อย: การ์ดเกมที่ใช้เวลานานที่สุด ---
class GameTimingCard extends StatefulWidget {
  final List<dynamic>? games;
  const GameTimingCard({super.key, this.games});

  @override
  State<GameTimingCard> createState() => _GameTimingCardState();
}

class _GameTimingCardState extends State<GameTimingCard> {
  int _currentPage = 1;
  final int _itemsPerPage = 5;

  @override
  Widget build(BuildContext context) {
    final games = widget.games ?? [];
    final totalPages = (games.length / _itemsPerPage).ceil();

    if (_currentPage > totalPages)
      _currentPage = totalPages > 0 ? totalPages : 1;
    if (_currentPage < 1) _currentPage = 1;

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final currentGames = games.sublist(
      startIndex < games.length ? startIndex : 0,
      endIndex < games.length ? endIndex : games.length,
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text(
              'รายการเกมทั้งหมด',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 20),
            // Header ของตาราง
            Row(
              children: [
                _buildHeaderCell('สนาม', flex: 2),
                _buildHeaderCell('ทีม A', flex: 3),
                _buildHeaderCell('vs', flex: 1),
                _buildHeaderCell('ทีม B', flex: 3),
                _buildHeaderCell('เวลา', flex: 2),
              ],
            ),
            const Divider(height: 24),
            // รายการเกม
            if (currentGames.isNotEmpty)
              ...currentGames
                  .map((game) => _buildGameRow(context, game))
                  .toList()
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('ไม่มีข้อมูลเกม'),
              ),
            // Pagination
            if (totalPages > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    totalPages,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _currentPage = index + 1;
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: _currentPage == index + 1
                              ? Colors.white
                              : Colors.black,
                          backgroundColor: _currentPage == index + 1
                              ? const Color(0xFF0E9D7A)
                              : Colors.transparent,
                          minimumSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                        ),
                        child: Text('${index + 1}'),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper สำหรับสร้าง Header ของตาราง
  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
      ),
    );
  }

  // Helper สำหรับสร้างแต่ละแถวของเกม
  Widget _buildGameRow(BuildContext context, dynamic game) {
    // รองรับทั้ง camelCase และ PascalCase และป้องกัน null
    final rawTeamA = game['teamA'] ?? game['TeamA'];
    // แก้ไข: เอา string ไปแสดงตรงๆ โดยไม่ต้อง split (ใส่ใน list เพื่อให้ _buildTeam ทำงานได้)
    final teamA =
        rawTeamA is List ? rawTeamA : (rawTeamA != null ? [rawTeamA] : []);

    final rawTeamB = game['teamB'] ?? game['TeamB'];
    final teamB =
        rawTeamB is List ? rawTeamB : (rawTeamB != null ? [rawTeamB] : []);

    final duration = '${game['duration'] ?? "00.00"}';
    // แก้ไข: เพิ่ม key ที่ตรงกับ JSON (courtNumber, matchId, shuttlecocksUsed)
    final courtName =
        game['courtName'] ??
        game['CourtName'] ??
        game['courtNumber'] ??
        '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$courtName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 10),
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(flex: 3, child: _buildTeam(context, teamA)),
          Expanded(
            flex: 1,
            child: Text(
              'vs',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 10),
              ),
            ),
          ),
          Expanded(flex: 3, child: _buildTeam(context, teamB)),
          Expanded(
            flex: 2,
            child: Text(
              duration,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 10),
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper สำหรับสร้าง Widget แสดงชื่อผู้เล่นในทีม
  Widget _buildTeam(BuildContext context, List<dynamic> players) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: players.map((player) {
        // รองรับกรณีข้อมูลเป็น Object (Map) หรือ String
        String name = '-';
        if (player is Map) {
          name =
              player['name'] ??
              player['firstName'] ??
              player['nickname'] ??
              '-';
        } else {
          name = '$player';
        }
        return Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              name,
              style: TextStyle(
                color: Color(0xFF0E9D7A),
                fontSize: getResponsiveFontSize(context, fontSize: 10),
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF0E9D7A),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
