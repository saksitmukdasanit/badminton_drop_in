// --- Widget หลัก สามารถนำไปใส่ใน Scaffold(body: HistoryOrganizerPage()) ---
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
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
    _fetchHistory();
    super.initState();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await ApiProvider().get('/GameSessions/my-history');
      if (response['status'] == 200) {
        setState(() {
          history = response['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchAnalytics(int sessionId) async {
    setState(() {
      _isAnalyticsLoading = true;
      _analyticsData = null;
    });
    try {
      final response = await ApiProvider().get('/GameSessions/$sessionId/analytics');
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
    searchController.dispose();
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
                Expanded(flex: 3, child: historyList(context)),
                Expanded(
                  flex: 4,
                  child: _selectedItem != null
                      ? _buildDetailsColumn(context)
                      : const Center(child: Text('กรุณาเลือกรายการ')),
                ),
                Expanded(
                  flex: 4,
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
                final dt = DateTime.tryParse(item['date'] ?? '')?.toLocal() ?? DateTime.now();
                final dateStr = '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}\n${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
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
                        textHistory(3, item['groupName'] ?? '-', 10, FontWeight.w300),
                        textHistory(2, '${item['totalIncome'] ?? 0}', 10, FontWeight.w300),
                        textHistory(2, '${item['paidAmount'] ?? 0}', 10, FontWeight.w300),
                        textHistory(2, '${item['unpaidAmount'] ?? 0}', 10, FontWeight.w300),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
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

  Widget detailsView(BuildContext context, {required dynamic item, Function()? onBack}) {
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
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsColumn(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsColumn(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: badmintonSummaryPage2(context, _analyticsData, _isAnalyticsLoading),
      ),
    );
  }

  Widget badmintonSummaryPage(BuildContext context, dynamic model) {
    return Column(
      children: [
        GroupInfoCard(model: model),
        SizedBox(height: 16),
        ImageSlideshow(model: model),
        SizedBox(height: 16),
        DetailsCard(model: model),
        SizedBox(height: 16),
        ActionButtons(),
        SizedBox(height: 16),
      ],
    );
  }

  Widget badmintonSummaryPage2(BuildContext context, Map<String, dynamic>? analytics, bool isLoading) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      children: [SummaryCard(data: analytics), SizedBox(height: 16), GameTimingCard(games: analytics?['matchHistory'])],
    );
  }
}

class GroupInfoCard extends StatelessWidget {
  final dynamic model;
  const GroupInfoCard({super.key, this.model});

  @override
  Widget build(BuildContext context) {
    final formattedDateTime = formatSessionStart(model['date'] ?? model['sessionStart'] ?? model['sessionDate'] ?? '');
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
                model['venueData'] != null ? model['venueData']['name'] : (model['courtName'] ?? model['venueName'] ?? '-'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              subtitle: Text(model['venueData'] != null ? model['venueData']['address'] : (model['location'] ?? '-'), style: TextStyle(fontSize: 16)),
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
    } else if (model['courtImageUrls'] is List && (model['courtImageUrls'] as List).isNotEmpty) {
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
          if (imageUrl != null) Image.network(imageUrl, fit: BoxFit.cover) else Container(height: 200, color: Colors.grey, child: Center(child: Icon(Icons.image, size: 50, color: Colors.white))),
        ],
      ),
    );
  }
}

// --- Widget ย่อย: การ์ดรายละเอียด ---
class DetailsCard extends StatelessWidget {
  final dynamic model;
  const DetailsCard({super.key, this.model});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ไอคอนสิ่งอำนวยความสะดวก
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children:
                  (model['facilities'] as List<dynamic>?)
                      ?.map(
                        (facility) =>
                            _buildFacilityIcon(context, facility['iconUrl']),
                      )
                      .toList() ??
                  [],
            ),
            SizedBox(height: 16),
            _buildText(
              context,
              'ค่าสนาม ${model['courtFeePerPerson']} บาท/ชั่วโมง',
            ),
            _buildText(
              context,
              '${model['shuttlecockBrandName']} ${model['shuttlecockModelName']} ${model['shuttlecockFeePerPerson']}/ลูก ',
            ),
            _buildText(context, '${model['gameTypeName']}'),
            _buildText(context, 'สนามที่ ${model['courtNumbers']}'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildText(
                      context,
                      'ผู้เล่น ${model['currentParticipants'] ?? 0}/${model['maxParticipants'] ?? 0} คน',
                    ),
                    _buildText(context, 'สำรอง 00/10 คน'),
                  ],
                ),
                GestureDetector(
                  onTap: () => context.push('/player-list/${model['gameSessionId'] ?? model['sessionId']}'),
                  child: Text(
                    'ดูผู้เล่น',
                    style: TextStyle(
                      color: Colors.teal[600],
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            Text('note : ${model['notes'] ?? '-'}'),

            // รายละเอียดค่าใช้จ่ายและผู้เล่น
            const Divider(height: 32),
            // รายได้
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('รายได้', style: TextStyle(fontSize: 18)),
                Text(
                  '${model['paidAmount'] ?? 0}/${model['totalIncome'] ?? 0} บาท',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0E9D7A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper สำหรับสร้างไอคอน
  Widget _buildFacilityIcon(BuildContext context, String iconUrl) {
    return CircleAvatar(
      radius: 22,
      child: Image.network(iconUrl),
    );
  }

  Widget _buildText(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: getResponsiveFontSize(context, fontSize: 14),
        fontWeight: FontWeight.w300,
      ),
    );
  }
}

// --- Widget ย่อย: ปุ่ม Action ด้านล่าง ---
class ActionButtons extends StatelessWidget {
  const ActionButtons({super.key});

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
              onPressed: () {
                context.push('/history-organizer-payment');
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
                context.push('/add-game/1');
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
                _buildSummaryRow(context, 'วันที่', data?['date'] != null ? formatSessionStart(data!['date'])['date']! : '-'),
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
                  (data?['totalPlayTimeStart']?.toString().isNotEmpty ?? false) ? data!['totalPlayTimeStart'] : '-',
                  unit: 'น.',
                  trailingTitle: 'เวลาสิ้นสุดการตี',
                  trailingValue: (data?['totalPlayTimeEnd']?.toString().isNotEmpty ?? false) ? data!['totalPlayTimeEnd'] : '-',
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
                  data?['longestGame']?['matchName'] ?? '-',
                  trailingTitle: 'ใช้เวลา',
                  trailingValue: '${data?['longestGame']?['duration'] ?? 0}',
                  trailingUnit: 'นาที',
                ),
                _buildSummaryRow(
                  context,
                  'เกมที่ใช้เวลาน้อยสุด',
                  data?['shortestGame']?['matchName'] ?? '-',
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ส่วน Title ด้านซ้าย
          Text(title, style: titleStyle),
          // ส่วน Value ตรงกลาง
          Row(
            children: [
              Text(value, style: valueStyle),
              if (unit != null) const SizedBox(width: 4),
              if (unit != null) Text(unit, style: unitStyle),
            ],
          ),
          // ส่วน Trailing (ถ้ามี)
          if (trailingTitle != null)
            Text(trailingTitle, style: titleStyle, textAlign: TextAlign.right),
          if (trailingValue != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(trailingValue, style: valueStyle),
                if (trailingUnit != null) const SizedBox(width: 4),
                if (trailingUnit != null) Text(trailingUnit, style: unitStyle),
              ],
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

    if (_currentPage > totalPages) _currentPage = totalPages > 0 ? totalPages : 1;
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
                _buildHeaderCell('สนาม/ลูก', flex: 2),
                _buildHeaderCell('ทีม A', flex: 3),
                _buildHeaderCell('vs', flex: 1),
                _buildHeaderCell('ทีม B', flex: 3),
                _buildHeaderCell('เวลา', flex: 2),
              ],
            ),
            const Divider(height: 24),
            // รายการเกม
            if (currentGames.isNotEmpty)
              ...currentGames.map((game) => _buildGameRow(context, game)).toList()
            else
              const Padding(padding: EdgeInsets.all(16), child: Text('ไม่มีข้อมูลเกม')),
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
                          foregroundColor: _currentPage == index + 1 ? Colors.white : Colors.black,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '${game['gameNumber'] ?? '-'}, ${game['courtName'] ?? '-'}, ${game['shuttlesUsed'] ?? '-'}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 10),
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(flex: 3, child: _buildTeam(context, game['teamA'] ?? [])),
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
          Expanded(flex: 3, child: _buildTeam(context, game['teamB'] ?? [])),
          Expanded(
            flex: 2,
            child: Text(
              game['duration'] ?? '00.00',
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
      children: players
          .map(
            (name) => Flexible(child: Container(
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
            )),
          )
          .toList(),
    );
  }
}
