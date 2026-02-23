import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/widget/expense_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _RowData {
  final String key1;
  final String value1;
  final String? key2;
  final String? value2;
  _RowData(this.key1, this.value1, this.key2, this.value2);
}

class HistoryOrganizerPaymentPage extends StatefulWidget {
  final int sessionId;
  const HistoryOrganizerPaymentPage({super.key, required this.sessionId});

  @override
  State<HistoryOrganizerPaymentPage> createState() =>
      _HistoryOrganizerPaymentPageState();
}

class _HistoryOrganizerPaymentPageState
    extends State<HistoryOrganizerPaymentPage> {
  // State สำหรับควบคุมการแสดงผลของ Panel ด้านขวา
  bool _isPanelVisible = false;
  bool _isLoading = true;
  Map<String, dynamic>? _sessionData;
  List<dynamic> _participants = [];
  
  // State สำหรับ Panel ขวา
  dynamic _selectedPlayer;
  dynamic _selectedPlayerBill;
  bool _isBillLoading = false;

  late TextEditingController _expenseNameController;
  late TextEditingController _expenseAmountController;

  void _showPaymentPanel(dynamic player) async {
    setState(() {
      _selectedPlayer = player;
      _isPanelVisible = true;
      _isBillLoading = true;
      _selectedPlayerBill = null;
    });

    try {
      // ดึงข้อมูลบิลของผู้เล่นที่เลือก
      final pType = player['participantType'] ?? 'Member'; // เดาค่าเริ่มต้น
      final pId = player['participantId'] ?? player['userId'] ?? player['id'];
      
      // เปลี่ยนเป็น bill-preview เพื่อดูข้อมูลก่อน (เหมือนหน้า ManageGame)
      final response = await ApiProvider().get('/participants/$pType/$pId/bill-preview');
      if (mounted) {
        setState(() {
          _selectedPlayerBill = response['data'];
          _isBillLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBillLoading = false;
        });
      }
    }
  }

  void _hidePaymentPanel() {
    setState(() {
      _isPanelVisible = false;
      _selectedPlayer = null;
      _selectedPlayerBill = null;
    });
  }

  // ฟังก์ชันสำหรับจัดการการจ่ายเงิน (ยิง API ครั้งเดียว)
  Future<void> _handlePayment(String paymentMethod, List<ExpenseAdjustment> adjustments) async {
    if (_selectedPlayer == null) return;

    setState(() => _isBillLoading = true);

    try {
      final pType = _selectedPlayer['participantType'] ?? 'Member';
      final pId = _selectedPlayer['participantId'] ?? _selectedPlayer['userId'] ?? _selectedPlayer['id'];

      // ดึงยอดที่จ่ายไปแล้ว
      final double paidAmount = num.tryParse('${_selectedPlayer['paidAmount'] ?? 0}')?.toDouble() ?? 0.0;

      // --- NEW: ถ้ามีบิลเก่าอยู่แล้ว ให้ยกเลิกก่อน เพื่อไม่ให้ยอดทบกัน ---
      if (_selectedPlayerBill != null && _selectedPlayerBill['billId'] != null) {
        try {
          await ApiProvider().put('/bills/${_selectedPlayerBill['billId']}/cancel');
        } catch (e) {
          print('Error cancelling old bill: $e'); // ไม่ต้อง throw error ปล่อยผ่านไปสร้างบิลใหม่ได้
        }
      }
      
      // 1. เตรียมข้อมูล Line Items (ค่าสนาม, ค่าธรรมเนียม, ค่าลูกแบด, รายการปรับปรุง)
      List<Map<String, dynamic>> customLineItems = [];
      
      final courtFeePerPerson = num.tryParse('${_sessionData?['courtFeePerPerson'] ?? 0}')?.toDouble() ?? 0.0;
      final shuttleFeePerPerson = num.tryParse('${_sessionData?['shuttlecockFeePerPerson'] ?? 0}')?.toDouble() ?? 0.0;
      final gamesPlayed = num.tryParse('${_selectedPlayer['gamesPlayed'] ?? 0}')?.toInt() ?? 0;

      if (courtFeePerPerson > 0) {
        customLineItems.add({'description': 'ค่าคอร์ท', 'amount': courtFeePerPerson});
      }
      customLineItems.add({'description': 'ค่าธรรมเนียม', 'amount': 10.0});

      double shuttleTotal = gamesPlayed * shuttleFeePerPerson;
      if (shuttleTotal > 0) {
        customLineItems.add({'description': 'ค่าลูกแบด ($gamesPlayed เกม)', 'amount': shuttleTotal});
      }

      for (var adj in adjustments) {
        double amount = adj.amount;
        if (adj.type == AdjustmentType.subtraction) amount = -amount;
        customLineItems.add({'description': adj.name, 'amount': amount});
      }

      // 2. เรียก API Checkout เพื่อสร้างบิลจริง
      final checkoutRes = await ApiProvider().post(
        '/participants/$pType/$pId/checkout',
        data: {'customLineItems': customLineItems},
      );
      
      final finalBill = checkoutRes['data'];
      final int billId = finalBill['billId'];
      final double totalAmount = (finalBill['totalAmount'] ?? 0).toDouble();

      // --- NEW: คำนวณยอดที่ต้องจ่ายเพิ่ม (ส่วนต่าง) ---
      final double dueAmount = totalAmount - paidAmount;

      // 3. จัดการการจ่ายเงิน
      if (paymentMethod == 'QR Code' && dueAmount > 0) {
        // กรณี QR Code: แสดง QR สำหรับยอดส่วนต่างเท่านั้น
        if (mounted) {
          setState(() => _isBillLoading = false); // หยุดโหลดเพื่อแสดง Dialog
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildQrPaymentDialog(context, dueAmount, billId, totalAmount),
          );
        }
      } else {
        // กรณีเงินสด หรือยอด <= 0 (คืนเงิน/เท่าเดิม): บันทึกเลย
        // ส่งยอดเต็มไปบันทึก เพื่อให้บิลสมบูรณ์
        await _confirmPaymentAPI(billId, paymentMethod, totalAmount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาดในการชำระเงิน')));
      }
    } finally {
      if (mounted) setState(() => _isBillLoading = false);
    }
  }

  // --- NEW: ฟังก์ชันยิง API จ่ายเงิน ---
  Future<void> _confirmPaymentAPI(int billId, String method, double amount) async {
    try {
      await ApiProvider().post('/bills/$billId/pay', data: {'paymentMethod': method, 'amount': amount});

      if (mounted) {
        _hidePaymentPanel();
        _fetchSessionData();
        
        showDialogMsg(
          context,
          title: 'บันทึกสำเร็จ',
          subtitle: 'อัปเดตข้อมูลการชำระเงินเรียบร้อยแล้ว',
          btnLeft: 'ตกลง',
          btnLeftBackColor: const Color(0xFF0E9D7A),
          btnLeftForeColor: Colors.white,
          onConfirm: () {},
        );
      }
    } finally {
      if (mounted) setState(() => _isBillLoading = false);
    }
  }

  // --- NEW: Dialog QR Code ---
  Widget _buildQrPaymentDialog(BuildContext context, double dueAmount, int billId, double totalBillAmount) {
    final qrData = "PromptPay:08x-xxx-xxxx:$dueAmount"; 

    return AlertDialog(
      title: const Text('สแกนจ่ายส่วนต่าง'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: QrImageView(data: qrData, version: QrVersions.auto, size: 200.0),
          ),
          const SizedBox(height: 16),
          Text('ยอดที่ต้องชำระเพิ่ม: ${dueAmount.toStringAsFixed(0)} บาท', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _isBillLoading = true);
            _confirmPaymentAPI(billId, 'QR Code', totalBillAmount);
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0E9D7A), foregroundColor: Colors.white),
          child: const Text('ยืนยันการชำระเงิน'),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _expenseNameController = TextEditingController();
    _expenseAmountController = TextEditingController();
    _fetchSessionData();
  }

  Future<void> _fetchSessionData() async {
    setState(() => _isLoading = true);
    try {
      // เปลี่ยนไปเรียก API financials แทน
      final response = await ApiProvider().get('/GameSessions/${widget.sessionId}/financials');
      if (mounted && response['status'] == 200) {
        setState(() {
          _sessionData = response['data'];
          // สมมติว่า API ส่ง participants มาใน sessionData หรือต้องดึงแยก
          // ถ้า API /GameSessions/{id} ส่ง participants มาด้วย:
          _participants = _sessionData?['participants'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _expenseNameController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shuttlecockRate = _sessionData?['shuttlecockFeePerPerson'] ?? 0;
    final courtFee = _sessionData?['courtFeePerPerson'] ?? 0;

    return Scaffold(
      appBar: AppBarSubMain(title: 'ประวัติการจัดก๊วน'),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
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
                    child: CostsSummary(sessionData: _sessionData),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: PlayerListCard(
                    participants: _participants,
                    shuttlecockRate: shuttlecockRate,
                    courtFee: courtFee,
                    onPlayerTap: _showPaymentPanel,
                    isScrollable: true,
                  ),
                ),

                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: _isPanelVisible ? _paymentPanel(context) : const SizedBox(),
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
                              child: CostsSummary(sessionData: _sessionData),
                            ),
                          ),
                        Expanded(
                          flex: 4,
                          child: PlayerListCard(
                            participants: _participants,
                            shuttlecockRate: shuttlecockRate,
                            courtFee: courtFee,
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
                    child: CostsSummary(sessionData: _sessionData),
                  ),
                if (!_isPanelVisible)
                  PlayerListCard(
                    participants: _participants,
                    shuttlecockRate: shuttlecockRate,
                    courtFee: courtFee,
                    onPlayerTap: _showPaymentPanel,
                  ),
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
    final playerName = _selectedPlayer != null 
        ? (_selectedPlayer['nickname'] ?? _selectedPlayer['name'] ?? '-') 
        : '-';

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
                  Text(
                    'สรุปค่าใช้จ่าย $playerName',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // --- ส่วนค่าสนาม ---
                  if (_isBillLoading)
                    const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
                  else
                    ExpensePanelWidget(
                      billData: _selectedPlayerBill,
                      courtFee: num.tryParse('${_sessionData?['courtFeePerPerson'] ?? 0}')?.toDouble() ?? 0.0,
                      shuttlecockFee: num.tryParse('${_sessionData?['shuttlecockFeePerPerson'] ?? 0}')?.toDouble() ?? 0.0,
                      totalGames: num.tryParse('${_selectedPlayer['gamesPlayed'] ?? 0}')?.toInt() ?? 0,
                      paidAmount: num.tryParse('${_selectedPlayer['paidAmount'] ?? 0}')?.toDouble() ?? 0.0,
                      onConfirmPayment: _handlePayment, // ส่งฟังก์ชันจัดการจ่ายเงินเข้าไป
                    ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _hidePaymentPanel,
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
  final Map<String, dynamic>? sessionData;
  const CostsSummary({super.key, this.sessionData});

  @override
  Widget build(BuildContext context) {
    final data = sessionData ?? {};
    
    // แปลงข้อมูลจาก API เป็น Map สำหรับแสดงผล
    final courtCosts = {
      'ผู้เล่น': '${data['currentParticipants'] ?? 0} คน',
      'ต้นทุนค่าสนาม': '${data['totalCourtCost'] ?? 0} บาท', // ใช้ totalCourtCost (ต้นทุน)
      'ค่าสนาม/คน': '${data['courtFeePerPerson'] ?? 0} บาท',
      'ยอดรวม': '${data['totalCourtIncome'] ?? 0} บาท', // ใช้ totalCourtIncome (รายได้)
      // 'ชำระแล้ว': '20 คน', // ข้อมูลนี้อาจต้องคำนวณจาก participants list
      // 'เป็นเงิน': '2000 บาท',
      // 'รอชำระ': '4 คน',
      // 'เป็นเงิน ': '400 บาท',
    };

    final shuttlecockCosts = {
      'ทุนค่าลูก/ลูก': '${data['shuttlecockFeePerPerson'] ?? 0} บาท', // เช็ค key อีกที
      // 'ทุนค่าลูก/ขีด': '19 บาท',
      'ใช้รวม(ลูก)': '${data['totalShuttlecocks'] ?? 0} ลูก',
      // 'ใช้รวม(ขีด)': '400 ขีด',
      // 'ราคา/ขีด': '20 บาท',
      'ยอดรวม': '${data['totalShuttlecockFee'] ?? 0} บาท',
      // 'ชำระแล้ว': '188 ขีด',
      // 'เป็นเงิน': '3760 บาท',
      // 'รอชำระ': '20 ขีด',
      // 'เป็นเงิน ': '400 บาท',
    };

    final totalSummary = {
      // 'ได้รับเงินผ่านแอป': '6230 บาท',
      // 'เงินสด': '330 บาท',
      'รายรับ': '${data['totalIncome'] ?? 0} บาท',
      // 'ค่าบริการแอป': '120 บาท',
      'คงเหลือ': '${(data['totalIncome'] ?? 0) - (data['totalExpense'] ?? 0)} บาท', // สมมติ
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
  final Function(dynamic) onPlayerTap; // Callback ส่ง player กลับไป
  final List<dynamic> participants;
  final dynamic shuttlecockRate;
  final dynamic courtFee;
  final bool isScrollable;
  final EdgeInsetsGeometry padding;

  const PlayerListCard({
    super.key,
    required this.onPlayerTap,
    this.participants = const [],
    this.shuttlecockRate = 0,
    this.courtFee = 0,
    this.isScrollable = false,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final playerListView = ListView.builder(
      shrinkWrap: !isScrollable,
      physics: isScrollable ? null : const NeverScrollableScrollPhysics(),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        final name = p['nickname'] ?? p['name'] ?? '-';
        final games = '${p['gamesPlayed'] ?? 0}';

        final gamesNum = num.tryParse(games) ?? 0;
        final rateNum = num.tryParse('$shuttlecockRate') ?? 0;
        final courtNum = num.tryParse('$courtFee') ?? 0;
        final totalNum = gamesNum * rateNum;
        String formatNum(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();
        final gameDisplay = '${formatNum(gamesNum)} x ${formatNum(rateNum)} = ${formatNum(totalNum)}';

        final total = '${p['totalCost'] ?? 0}';
        final paid = '${p['paidAmount'] ?? 0}';
        final unpaid = '${p['unpaidAmount'] ?? 0}';

        final totalCostNum = num.tryParse(total) ?? 0;
        // FIX: หักค่าธรรมเนียม 10 บาทออกจากสูตรคำนวณ เพื่อให้ช่อง "อื่นๆ" เป็น 0 ในกรณีปกติ
        final othersNum = totalCostNum - (totalNum + courtNum + 10);
        final others = formatNum(othersNum);

        final unpaidNum = num.tryParse(unpaid) ?? 0;
        final rowColor = unpaidNum > 0 ? Colors.red : Colors.green;

        return GestureDetector(
          onTap: () => onPlayerTap(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                text(2, '${index + 1}', 14, FontWeight.w300, color: rowColor),
                text(3, name, 14, FontWeight.w300, color: rowColor),
                text(5, gameDisplay, 12, FontWeight.w300, color: rowColor),
                text(2, total, 14, FontWeight.w300, color: rowColor),
                text(2, paid, 14, FontWeight.w300, color: rowColor),
                text(2, others, 14, FontWeight.w300, color: rowColor),
                text(2, unpaid, 14, FontWeight.w300, color: rowColor),
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
                  // Text(
                  //   '32/70 คน',
                  //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  // ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  text(2, 'no', 14, FontWeight.w700),
                  text(3, 'ชื่อเล่น', 14, FontWeight.w700),
                  text(5, 'เกมส์', 14, FontWeight.w700),
                  text(2, 'ยอด', 14, FontWeight.w700),
                  text(2, 'จ่าย', 14, FontWeight.w700),
                  text(2, 'อื่นๆ', 14, FontWeight.w700),
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

  Widget text(int flex, String text, double fontSize, FontWeight fontWeight, {Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
      ),
    );
  }
}
