import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/component/payment_action_card.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';

class HistoryDetailPage extends StatefulWidget {
  final String code;
  const HistoryDetailPage({super.key, required this.code});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  String? _selectedGameResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'ประวัติ'),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildSummaryCard(),
                  _buildPaymentCard(),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: PaymentActionCard(onPayNowPressed: () {}),
                  ),
                  // _buildPaymentActionCard(),
                ],
              ),
            ),
          ];
        },
        body: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'เกมทั้งหมด',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'ดูเพิ่มเติม',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return _buildGameResultCard(index + 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'สรุป',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryInfo('วันที่ไปทั้งหมด', '2', 'เกม'),
                _buildSummaryInfo('ใช้ลูก', '2', 'ลูก'),
                _buildSummaryInfo('เวลาทั้งหมด', '2', 'ชม.'),
                _buildSummaryInfo('เล่นรอ', '1.30', 'ชม.'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'จองเป็นผู้เล่นตัวจริง',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ระบบจะโอนเงินคืนภายใน 7 วันทำการ',

                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  'T&C',
                  style: TextStyle(
                    color: Colors.teal,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),
            _buildPriceRow('ค่าสนาม', '120 บาท'),
            _buildPriceRow('ค่าธรรมเนียม', '10 บาท'),
            _buildPriceRow('ราคารวม', '130 บาท', isBold: true),
            Divider(height: 24),
            Row(
              children: [
                Text(
                  'ชำระเรียบร้อย',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                Text(
                  'dd/mm/yy hh:mm น.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'บัตรเครดิต **** **** **** 9000',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameResultCard(int gameNumber) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // --- ส่วนผู้เล่นด้านซ้าย ---
            Expanded(
              child: Column(
                children: [
                  _buildPlayerTeam(
                    const Color(0xFF1ABC9C),
                    Radius.circular(12),
                    Radius.circular(0),
                    false,
                  ), // สีเขียว

                  _buildPlayerTeam(
                    const Color(0xFF2C3E50),
                    Radius.circular(0),
                    Radius.circular(12),
                    true,
                  ), // สีน้ำเงินเข้ม
                ],
              ),
            ),
            // --- ส่วนรายละเอียดด้านขวา ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'เกมที่ $gameNumber',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            Image.asset(
                              'assets/icon/shuttlecock.png',
                              width: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '2',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Dropdown สำหรับผลการแข่งขัน
                    CustomDropdown(
                      labelText: '',
                      initialValue: _selectedGameResult,
                      items: [
                        {"code": 1, "value": 'ชนะ'},
                        {"code": 2, "value": 'แพ้'},
                        {"code": 3, "value": 'เสมอ'},
                      ],
                      onChanged: (value) {
                        setState(() => _selectedGameResult = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    // ช่องใส่ Note
                    TextField(
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'note...',
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget ย่อยสำหรับสร้างทีมผู้เล่น 2 คน
  Widget _buildPlayerTeam(
    Color bgColor,
    Radius top,
    Radius bottom,
    bool isBottom,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: top,
          topRight: top,
          bottomLeft: bottom,
          bottomRight: bottom,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundImage: NetworkImage(
                      'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'น้ำ',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 14),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundImage: NetworkImage(
                      'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'ชาย',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 14),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isBottom)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '08:56 นาที',
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 14),
                    color: Colors.white,
                  ),
                ),
                Text(
                  'สนาม 1',
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 14),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryInfo(String title, String value, String unit) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _buildPriceRow extends StatelessWidget {
  final String title;
  final String amount;
  final bool isBold;

  const _buildPriceRow(this.title, this.amount, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: getResponsiveFontSize(context, fontSize: 20),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: getResponsiveFontSize(context, fontSize: 20),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
