// --- Widget หลัก สามารถนำไปใส่ใน Scaffold(body: HistoryOrganizerPage()) ---
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/text_box.dart';
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
  // State สำหรับจัดการการแสดงผลบนมือถือ
  bool _showDetailsOnMobile = false;
  late List<dynamic> history;

  void _backToListOnMobile() {
    setState(() {
      _showDetailsOnMobile = !_showDetailsOnMobile;
    });
  }

  @override
  void initState() {
    searchController = TextEditingController();
    history = _generateMockHistory(10);
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  _generateMockHistory(int count) {
    return List.generate(count, (i) {
      return (
        id: i + 1,
        datetime: '21/04/25\n18:00 น.',
        title: 'ก๊วนเหมียวเหมียว',
        income: '2460',
        expenses: '2400',
        accrued: '60',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarSubMain(title: 'ประวัติการจัดก๊วน', isBack: false),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 820) {
            // --- Layout สำหรับจอใหญ่ (Tablet) ---
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: historyList(context)),
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 16.0,
                        horizontal: 8,
                      ),
                      child: badmintonSummaryPage(context),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: 16,
                        bottom: 16,
                        left: 0,
                        right: 8,
                      ),
                      child: badmintonSummaryPage2(context),
                    ),
                  ),
                ),
              ],
            );
          } else if (constraints.maxWidth > 600) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: historyList(context)),
                Expanded(flex: 4, child: detailsView(context, onBack: null)),
              ],
            );
          } else {
            // --- Layout สำหรับจอเล็ก (Mobile) ---
            // ใช้ AnimatedSwitcher เพื่อสร้าง Animation สลับหน้า
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showDetailsOnMobile
                  ? detailsView(
                      context,
                      onBack: _backToListOnMobile,
                    ) // หน้ารายละเอียด
                  : historyList(context), // หน้ารายการ
            );
          }
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _backToListOnMobile(),
                child: Row(
                  children: [
                    textHistory(2, '21/04/25\n18:00 น.', 8, FontWeight.w300),
                    textHistory(3, 'ก๊วนเหมียวเหมียว', 8, FontWeight.w300),
                    textHistory(2, '2460', 8, FontWeight.w300),
                    textHistory(2, '2400', 8, FontWeight.w300),
                    textHistory(2, '60', 8, FontWeight.w300),
                  ],
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

  Widget detailsView(BuildContext context, {Function()? onBack}) {
    final bool isMobile = onBack != null;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ปุ่ม Back สำหรับ Mobile
            if (isMobile)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_back_ios),
                  label: const Text('กลับไปที่รายการ'),
                  onPressed: onBack,
                ),
              ),
            badmintonSummaryPage(context),
            badmintonSummaryPage2(context),
          ],
        ),
      ),
    );
  }

  Widget badmintonSummaryPage(BuildContext context) {
    return Column(
      children: const [
        GroupInfoCard(),
        SizedBox(height: 16),
        ImageSlideshow(),
        SizedBox(height: 16),
        DetailsCard(),
        SizedBox(height: 16),
        ActionButtons(),
        SizedBox(height: 16),
      ],
    );
  }

  Widget badmintonSummaryPage2(BuildContext context) {
    return Column(
      children: const [SummaryCard(), SizedBox(height: 16), GameTimingCard()],
    );
  }
}

class GroupInfoCard extends StatelessWidget {
  final dynamic model;
  const GroupInfoCard({super.key, this.model});

  @override
  Widget build(BuildContext context) {
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
              model['teamName'],
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
                model['courtName'],
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              subtitle: Text(model['location'], style: TextStyle(fontSize: 16)),
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
                '${model['date']} ${model['time']}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                ),
              ),
              backgroundColor: dayColors.firstWhere(
                (d) => d['code'] == model['day'],
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // ทำให้รูปภาพอยู่ในขอบเขตของการ์ด
      elevation: 2,
      child: Column(
        children: [
          // Placeholder สำหรับรูปภาพ
          Image.network(model['imageUrl'], fit: BoxFit.cover),
        ],
      ),
    );
  }
}

// --- Widget ย่อย: การ์ดรายละเอียด ---
class DetailsCard extends StatelessWidget {
  const DetailsCard({super.key});

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
              spacing: 8.0, // ระยะห่างระหว่างไอคอนแนวนอน
              runSpacing: 8.0, // ระยะห่างระหว่างบรรทัด
              children: [
                _buildFacilityIcon(context, Icons.wifi),
                _buildFacilityIcon(context, Icons.ac_unit),
                _buildFacilityIcon(context, Icons.chair),
                _buildFacilityIcon(context, Icons.search),
                _buildFacilityIcon(context, Icons.directions_run),
                _buildFacilityIcon(context, Icons.shower),
              ],
            ),
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildText(context, 'ค่าสนาม 60 บาท/ชั่วโมง'),
                    _buildText(context, 'Yonex 20บาท/ลูก '),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildText(context, 'เล่น 21 แต้ม/2เซ็ต'),
                    _buildText(context, 'สนามที่ 4, 5, 6'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildText(context, 'ผู้เล่น 57/80 คน'),
                        _buildText(context, 'สำรอง 00/10 คน'),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => context.push('/player-list/1'),
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
                Text('note : มาเล่นแบดมินตันกับเพื่อนในก๊วนที่วงเวีย...'),
              ],
            ),

            // รายละเอียดค่าใช้จ่ายและผู้เล่น
            const Divider(height: 32),
            // รายได้
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('รายได้', style: TextStyle(fontSize: 18)),
                Text(
                  '2460/2460 บาท',
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
  Widget _buildFacilityIcon(BuildContext context, IconData icon) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: Color(0xFF0E9D7A),
      child: Icon(icon, color: Colors.white),
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
  const SummaryCard({super.key});

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
                _buildSummaryRow(context, 'ก๊วน', 'แมวเหมียว'),
                _buildSummaryRow(context, 'วันที่', '15 ตุลาคม พ.ศ. 2568'),
                _buildSummaryRow(
                  context,
                  'ตีทั้งหมด',
                  '50',
                  unit: 'เกม',
                  trailingTitle: 'ใช้ลูก',
                  trailingValue: '52',
                  trailingUnit: 'ลูก',
                ),
                _buildSummaryRow(
                  context,
                  'เวลาเริ่มตี',
                  '19.05',
                  unit: 'นาที',
                  trailingTitle: 'เวลาสิ้นสุดการตี',
                  trailingValue: '22.15',
                  trailingUnit: 'นาที',
                ),
                _buildSummaryRow(
                  context,
                  'เวลาตีต่อเกมเฉลี่ย',
                  '15.05',
                  unit: 'นาที',
                ),
                _buildSummaryRow(
                  context,
                  'เกมที่ใช้เวลานานสุด',
                  'A+B vs C+D',
                  trailingTitle: 'ใช้เวลา',
                  trailingValue: '20.30',
                  trailingUnit: 'นาที',
                ),
                _buildSummaryRow(
                  context,
                  'เกมที่ใช้เวลาน้อยสุด',
                  'A+B vs C+D',
                  trailingTitle: 'ใช้เวลา',
                  trailingValue: '20.30',
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
class GameTimingCard extends StatelessWidget {
  const GameTimingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text(
              'เกมที่ใช้เวลานานที่สุด',
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
            ...List.generate(8, (index) => _buildGameRow(context, index)),
            // Pagination
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: index == 0 ? Colors.white : Colors.black,
                    backgroundColor: index == 0
                        ? Colors.blue
                        : Colors.transparent,
                  ),
                  child: Text('${index + 1}'),
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
  Widget _buildGameRow(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '01, 1, 23',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 10),
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(flex: 3, child: _buildTeam(context, ['แชมป์', 'บิว'])),
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
          Expanded(flex: 3, child: _buildTeam(context, ['มิก', 'ปุ้ย'])),
          Expanded(
            flex: 2,
            child: Text(
              '00.00',
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
  Widget _buildTeam(BuildContext context, List<String> players) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: players
          .map(
            (name) => Container(
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
          )
          .toList(),
    );
  }
}
