import 'package:badminton/component/app_bar.dart';
import 'package:badminton/widget/expense_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _RowData {
  final String key1;
  final String value1;
  final String? key2;
  final String? value2;
  _RowData(this.key1, this.value1, this.key2, this.value2);
}

enum AdjustmentType { addition, subtraction }

class ExpenseAdjustment {
  final String name;
  final double amount;
  final AdjustmentType type;

  ExpenseAdjustment({
    required this.name,
    required this.amount,
    required this.type,
  });
}

class HistoryOrganizerPaymentPage extends StatefulWidget {
  const HistoryOrganizerPaymentPage({super.key});

  @override
  State<HistoryOrganizerPaymentPage> createState() =>
      _HistoryOrganizerPaymentPageState();
}

class _HistoryOrganizerPaymentPageState
    extends State<HistoryOrganizerPaymentPage> {
  // State สำหรับควบคุมการแสดงผลของ Panel ด้านขวา
  bool _isPanelVisible = false;
  late TextEditingController _expenseNameController;
  late TextEditingController _expenseAmountController;

  void _showPaymentPanel() {
    setState(() {
      _isPanelVisible = !_isPanelVisible;
    });
  }

  @override
  void initState() {
    _expenseNameController = TextEditingController();
    _expenseAmountController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _expenseNameController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarSubMain(title: 'ประวัติการจัดก๊วน'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double menuWidth = _isPanelVisible ? 350 : constraints.maxWidth;
          if (constraints.maxWidth > 820) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                    child: CostsSummary(),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: PlayerListCard(
                    onPlayerTap: _showPaymentPanel,
                    isScrollable: true,
                  ),
                ),

                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: _paymentPanel(context),
                  ),
                ),
              ],
            );
          } else if (constraints.maxWidth >= 600) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: menuWidth,
                    color: Colors.transparent,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isPanelVisible)
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                              child: CostsSummary(),
                            ),
                          ),
                        Expanded(
                          flex: 4,
                          child: PlayerListCard(
                            onPlayerTap: _showPaymentPanel,
                            isScrollable: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isPanelVisible)
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: _paymentPanel(context),
                    ),
                  ),
              ],
            );
          } else {
            return ListView(
              children: [
                if (!_isPanelVisible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: CostsSummary(),
                  ),
                if (!_isPanelVisible)
                  PlayerListCard(onPlayerTap: _showPaymentPanel),
                if (_isPanelVisible)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _paymentPanel(context),
                  ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _paymentPanel(BuildContext context) {
    return Card(
      color: Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  // --- ส่วนหัว ---
                  const Text(
                    'สรุปค่าใช้จ่าย บิว (อุรัสยา แสนดี)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // --- ส่วนค่าสนาม ---
                  ExpensePanelWidget(),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _showPaymentPanel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CostsSummary extends StatelessWidget {
  const CostsSummary({super.key});

  @override
  Widget build(BuildContext context) {
    // ข้อมูลจำลองสำหรับแต่ละ Card
    const courtCosts = {
      'ผู้เล่น': '24 คน',
      'ต้นทุนค่าสนาม': '2000 บาท',
      'ค่าสนาม/คน': '100 บาท',
      'ยอดรวม': '2400 บาท',
      'ชำระแล้ว': '20 คน',
      'เป็นเงิน': '2000 บาท',
      'รอชำระ': '4 คน',
      'เป็นเงิน ': '400 บาท',
    };

    const shuttlecockCosts = {
      'ทุนค่าลูก/ลูก': '76 บาท',
      'ทุนค่าลูก/ขีด': '19 บาท',
      'ใช้รวม(ลูก)': '100 ลูก',
      'ใช้รวม(ขีด)': '400 ขีด',
      'ราคา/ขีด': '20 บาท',
      'ยอดรวม': '8000 บาท',
      'ชำระแล้ว': '188 ขีด',
      'เป็นเงิน': '3760 บาท',
      'รอชำระ': '20 ขีด',
      'เป็นเงิน ': '400 บาท',
    };

    const totalSummary = {
      'ได้รับเงินผ่านแอป': '6230 บาท',
      'เงินสด': '330 บาท',
      'รายรับ': '6560 บาท',
      'ค่าบริการแอป': '120 บาท',
      'คงเหลือ': '6440 บาท',
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _SummaryCard(
            title: 'ค่าสนาม',
            data: courtCosts,
            highlightKeys: const ['ยอดรวม ', 'เป็นเงิน'],
          ),
          const SizedBox(height: 16),
          _SummaryCard(
            title: 'ยอดลูกแบด',
            data: shuttlecockCosts,
            highlightKeys: const ['เป็นเงิน ', 'ยอดรวม'],
          ),
          const SizedBox(height: 16),
          _SummaryCard(
            title: 'ยอดทั้งหมด',
            data: totalSummary,
            highlightKeys: const ['รายรับ', 'คงเหลือ'],
          ),
        ],
      ),
    );
  }
}

// --- Widget ย่อยสำหรับสร้าง Card แต่ละใบ ---
class _SummaryCard extends StatelessWidget {
  final String title;
  final Map<String, String> data;
  final List<String> highlightKeys;

  const _SummaryCard({
    required this.title,
    required this.data,
    this.highlightKeys = const [],
  });

  @override
  Widget build(BuildContext context) {
    // แปลง Map ให้อยู่ในรูปแบบ List ของ RowData เพื่อจัดการ Layout ได้ง่ายขึ้น
    List<_RowData> rows = [];
    var keys = data.keys.toList();
    for (int i = 0; i < keys.length; i += 2) {
      if (i + 1 < keys.length) {
        rows.add(
          _RowData(keys[i], data[keys[i]]!, keys[i + 1], data[keys[i + 1]]!),
        );
      } else {
        rows.add(_RowData(keys[i], data[keys[i]]!, null, null));
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Color(0xFFB3B3C1), // สีของเส้นขอบ
          width: 0, // ความหนาเส้นขอบ
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- ส่วนหัว (Header) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF64646D),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
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
              children: rows
                  .map((rowData) => _buildSummaryRow(rowData))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget ย่อยสำหรับสร้างแต่ละแถว ---
  Widget _buildSummaryRow(_RowData rowData) {
    final bool highlightLeft = highlightKeys.contains(rowData.key1);
    final bool highlightRight =
        rowData.key2 != null && highlightKeys.contains(rowData.key2!);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // --- คอลัมน์ซ้าย ---
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    rowData.key1.trim(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
                Text(
                  rowData.value1,
                  style: TextStyle(
                    fontWeight: highlightLeft
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: highlightLeft ? Colors.red : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // --- คอลัมน์ขวา ---
          Expanded(
            child: rowData.key2 != null
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          rowData.key2!.trim(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      Text(
                        rowData.value2!,
                        style: TextStyle(
                          fontWeight: highlightRight
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: highlightRight ? Colors.green : Colors.black,
                        ),
                      ),
                    ],
                  )
                : const SizedBox(), // ถ้าไม่มีข้อมูลคอลัมน์ขวา ให้เป็นช่องว่าง
          ),
        ],
      ),
    );
  }
}

// --- Widget ย่อย: รายชื่อผู้เล่น (กลาง) ---
class PlayerListCard extends StatelessWidget {
  final VoidCallback onPlayerTap; // Callback ที่จะถูกเรียกเมื่อกดที่รายชื่อ
  final bool isScrollable;
  final EdgeInsetsGeometry padding;

  const PlayerListCard({
    super.key,
    required this.onPlayerTap,
    this.isScrollable = false,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final playerListView = ListView.builder(
      shrinkWrap: !isScrollable,
      physics: isScrollable ? null : const NeverScrollableScrollPhysics(),
      itemCount: 14,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: onPlayerTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                text(2, '00', 14, FontWeight.w300),
                text(3, 'แก้ว', 14, FontWeight.w300),
                text(2, '4', 14, FontWeight.w300),
                text(3, 'x 20 = 120', 14, FontWeight.w300),
                text(2, '220', 14, FontWeight.w300),
                text(2, '120', 14, FontWeight.w300),
                text(2, '100', 14, FontWeight.w300),
              ],
            ),
          ),
        );
      },
    );

    return Padding(
      padding: padding,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Color(0xFFB3B3C1), // สีของเส้นขอบ
            width: 0, // ความหนาเส้นขอบ
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'สรุปค่าใช้จ่ายผู้เล่น',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '32/70 คน',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  text(2, 'no', 14, FontWeight.w700),
                  text(3, 'ชื่อเล่น', 14, FontWeight.w700),
                  text(2, 'เกมส์', 14, FontWeight.w700),
                  text(3, 'qty', 14, FontWeight.w700),
                  text(2, 'ยอด', 14, FontWeight.w700),
                  text(2, 'จ่าย', 14, FontWeight.w700),
                  text(2, 'ค้าง', 14, FontWeight.w700),
                ],
              ),
              isScrollable
                  ? Expanded(child: playerListView) // <<< สำหรับจอใหญ่
                  : playerListView, // <<< สำหรับจอมือถือ
            ],
          ),
        ),
      ),
    );
  }

  Widget text(int flex, String text, double fontSize, FontWeight fontWeight) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
      ),
    );
  }
}
