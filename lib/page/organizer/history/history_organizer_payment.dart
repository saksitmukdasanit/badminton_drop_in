import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/widget/expense_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:badminton/component/qr_payment_dialog.dart'; // Import ไฟล์กลาง

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
  double _calculatedServiceFee = 10.0; // NEW: State for service fee
  
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

    // 1. ดึงข้อมูลผู้เล่นล่าสุดจาก _participants เพื่อให้ได้ paidAmount ที่ถูกต้อง (แก้ปัญหายอดไม่ตรง)
    final pId = _selectedPlayer['participantId'] ?? _selectedPlayer['userId'] ?? _selectedPlayer['id'];
    final pType = _selectedPlayer['participantType'] ?? 'Member';
    
    final latestPlayer = _participants.firstWhere(
      (p) {
        final id = p['participantId'] ?? p['userId'] ?? p['walkinId'];
        return id.toString() == pId.toString();
      },
      orElse: () => _selectedPlayer,
    );
    
    final double paidAmount = num.tryParse('${latestPlayer['paidAmount'] ?? 0}')?.toDouble() ?? 0.0;

    // 2. คำนวณยอดที่จะต้องจ่าย (Base + Adjustments)
    // เตรียมข้อมูล Line Items
    List<Map<String, dynamic>> customLineItems = [];
    double baseTotal = 0.0;

    // --- FIX: ใช้ Logic เดียวกับ ExpensePanelWidget เพื่อให้ยอดตรงกัน 100% ---
    
    // 2.1 ค่าสนาม
    double courtFee = num.tryParse('${_sessionData?['courtFeePerPerson'] ?? 0}')?.toDouble() ?? 0.0;
    // พยายามดึงจาก API Preview ก่อน (เผื่อมีค่าพิเศษ)
    if (_selectedPlayerBill != null && _selectedPlayerBill['lineItems'] != null) {
       final items = _selectedPlayerBill['lineItems'] as List;
       final item = items.firstWhere((i) => i['description'] == 'ค่าคอร์ท', orElse: () => null);
       if (item != null) courtFee = (item['amount'] ?? 0).toDouble();
    }
    if (courtFee > 0) {
        customLineItems.add({'description': 'ค่าคอร์ท', 'amount': courtFee});
        baseTotal += courtFee;
    }

    // 2.2 ค่าธรรมเนียม
    double serviceFee = _calculatedServiceFee;
    if (_selectedPlayerBill != null && _selectedPlayerBill['lineItems'] != null) {
       final items = _selectedPlayerBill['lineItems'] as List;
       final item = items.firstWhere((i) => i['description'] == 'ค่าธรรมเนียม', orElse: () => null);
       if (item != null) serviceFee = (item['amount'] ?? 0).toDouble();
    }
    customLineItems.add({'description': 'ค่าธรรมเนียม', 'amount': serviceFee});
    baseTotal += serviceFee;

    // 2.3 ค่าลูกแบด (ใช้สูตรคำนวณเองเป็นหลัก: เกม x ราคา)
    double shuttleTotal = 0.0;
    final int totalGames = num.tryParse('${latestPlayer['gamesPlayed'] ?? 0}')?.toInt() ?? 0;
    final double shuttleFeePerPerson = num.tryParse('${_sessionData?['shuttlecockFeePerPerson'] ?? 0}')?.toDouble() ?? 0.0;

    if (totalGames > 0 && shuttleFeePerPerson > 0) {
       shuttleTotal = totalGames * shuttleFeePerPerson;
    } else {
       // Fallback: ถ้าคำนวณไม่ได้ (เช่น ราคาเป็น 0 หรือไม่มีเกม) ให้ลองดูจาก API
       if (_selectedPlayerBill != null && _selectedPlayerBill['lineItems'] != null) {
          final items = _selectedPlayerBill['lineItems'] as List;
          final item = items.firstWhere((i) => (i['description'] ?? '').toString().startsWith('ค่าลูกแบด'), orElse: () => null);
          if (item != null) shuttleTotal = (item['amount'] ?? 0).toDouble();
       }
    }
    
    if (shuttleTotal > 0) {
       customLineItems.add({'description': 'ค่าลูกแบด ($totalGames เกม)', 'amount': shuttleTotal});
       baseTotal += shuttleTotal;
    }

    // เพิ่มรายการปรับปรุง (Adjustments)
    double adjustmentsTotal = 0.0;
    for (var adj in adjustments) {
      double amount = adj.amount;
      if (adj.type == AdjustmentType.subtraction) amount = -amount;
      customLineItems.add({'description': adj.name, 'amount': amount});
      adjustmentsTotal += amount;
    }

    final double estimatedTotalAmount = baseTotal + adjustmentsTotal;
    final double dueAmount = estimatedTotalAmount - paidAmount;

    // 3. ถ้าเป็น QR Code ให้แสดง Dialog ก่อนยิง API (แก้ปัญหากดยกเลิกแล้วยังยิง API)
    if (paymentMethod == 'QR Code' && dueAmount > 0) {
      // --- FIX: เรียกใช้ฟังก์ชันกลาง ---
      final confirm = await showQrPaymentDialog(context, dueAmount);

      if (confirm != true) return; // ถ้ากดยกเลิก หรือปิด Dialog ให้หยุดทำงานทันที
    }

    // 4. เริ่มกระบวนการบันทึกจริง (ยิง API)
    setState(() => _isBillLoading = true);

    try {
      // 4.1 ยกเลิกบิลเก่า (ถ้ามี)
      if (_selectedPlayerBill != null && _selectedPlayerBill['billId'] != null) {
        try {
          await ApiProvider().put('/bills/${_selectedPlayerBill['billId']}/cancel');
        } catch (e) {
          print('Error cancelling old bill: $e'); // ไม่ต้อง throw error ปล่อยผ่านไปสร้างบิลใหม่ได้
        }
      }
      
      // 4.2 เรียก API Checkout เพื่อสร้างบิลจริง
      final checkoutRes = await ApiProvider().post(
        '/participants/$pType/$pId/checkout',
        data: {'customLineItems': customLineItems},
      );
      
      final finalBill = checkoutRes['data'];
      final int billId = finalBill['billId'];
      final double totalAmount = (finalBill['totalAmount'] ?? 0).toDouble();

      // 4.3 บันทึกการจ่ายเงิน (ส่งยอดเต็ม totalAmount ไปบันทึกตาม Logic ของระบบ)
      await _confirmPaymentAPI(billId, paymentMethod, totalAmount);

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
        final sessionData = response['data'];
        final participants = sessionData?['participants'] ?? [];

        // --- NEW: Calculate service fee dynamically ---
        double serviceFee = 10.0; // Default fallback
        final firstUnpaidPlayer = participants.firstWhere(
          (p) => (num.tryParse('${p['unpaidAmount']}') ?? 0) > 0,
          orElse: () => null,
        );

        if (firstUnpaidPlayer != null) {
          final totalCost = num.tryParse('${firstUnpaidPlayer['totalCost']}') ?? 0;
          final cPart = num.tryParse('${firstUnpaidPlayer['courtFee']}') ?? 0;
          final sPart = num.tryParse('${firstUnpaidPlayer['shuttleFee']}') ?? 0;
          final calculatedFee = totalCost - cPart - sPart;
          // The calculated fee should be a positive number and reasonable
          if (calculatedFee > 0 && calculatedFee < 100) {
            serviceFee = calculatedFee.toDouble();
          }
        }
        // --- END NEW ---

        setState(() {
          _sessionData = sessionData;
          _participants = participants;
          _calculatedServiceFee = serviceFee; // Store the calculated fee
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
                    serviceFee: _calculatedServiceFee, // NEW: Pass service fee
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
                            serviceFee: _calculatedServiceFee, // NEW: Pass service fee
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
                    serviceFee: _calculatedServiceFee, // NEW: Pass service fee
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
                    Builder(builder: (context) {
                      // --- NEW: ดึงค่า Service Fee จาก Bill Preview ---
                      double serviceFee = 10.0; // Fallback
                      if (_selectedPlayerBill != null && _selectedPlayerBill['lineItems'] != null) {
                        final items = _selectedPlayerBill['lineItems'] as List;
                        final item = items.firstWhere((i) => i['description'] == 'ค่าธรรมเนียม', orElse: () => null);
                        if (item != null) serviceFee = (item['amount'] ?? 10.0).toDouble();
                      }
                      return ExpensePanelWidget(
                        billData: _selectedPlayerBill,
                        courtFee: num.tryParse('${_sessionData?['courtFeePerPerson'] ?? 0}')?.toDouble() ?? 0.0,
                        shuttlecockFee: num.tryParse('${_sessionData?['shuttlecockFeePerPerson'] ?? 0}')?.toDouble() ?? 0.0,
                        totalGames: num.tryParse('${_selectedPlayer['gamesPlayed'] ?? 0}')?.toInt() ?? 0,
                        paidAmount: num.tryParse('${_selectedPlayer['paidAmount'] ?? 0}')?.toDouble() ?? 0.0,
                        serviceFee: serviceFee, // --- NEW: ส่งค่า Service Fee เข้าไป ---
                        onConfirmPayment: _handlePayment,
                      );
                    }),
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
    String fmt(dynamic val) => (num.tryParse('$val') ?? 0).toStringAsFixed(0);
    String fmtDec(dynamic val) => (num.tryParse('$val') ?? 0).toStringAsFixed(0);

    // --- คำนวณข้อมูลเชิงลึก ---
    final participants = (data['participants'] as List?) ?? [];
    
    // 1. ข้อมูลลูกแบด (ขีด = เกม)
    // --- REFACTORED: ใช้ค่าที่คำนวณมาแล้วจาก Backend ---
    double totalAdditions = (num.tryParse('${data['totalAdditions']}') ?? 0).toDouble();
    double totalSubtractions = (num.tryParse('${data['totalSubtractions']}') ?? 0).toDouble();
    double totalIncomeCalculated = (num.tryParse('${data['totalIncome']}') ?? 0).toDouble();
    
    int totalKeed = 0; // จำนวนเกมทั้งหมดของผู้เล่น (Player-Games)
    for (var p in participants) {
      totalKeed += (p['gamesPlayed'] as int? ?? 0);
    }
    
    double totalShuttleCost = (num.tryParse('${data['totalShuttlecockCost']}') ?? 0).toDouble();
    double costPerKeed = totalKeed > 0 ? totalShuttleCost / totalKeed : 0;

    // 2. ยอดจ่ายแยกประเภท (ใช้ค่าจาก API)
    double paidCourtAmount = (num.tryParse('${data['paidCourtAmount']}') ?? 0).toDouble();
    double unpaidCourtAmount = (num.tryParse('${data['unpaidCourtAmount']}') ?? 0).toDouble();
    int paidCourtCount = (data['paidCourtCount'] as int? ?? 0);
    int unpaidCourtCount = (data['unpaidCourtCount'] as int? ?? 0);

    double paidShuttleAmount = (num.tryParse('${data['paidShuttleAmount']}') ?? 0).toDouble();
    double unpaidShuttleAmount = (num.tryParse('${data['unpaidShuttleAmount']}') ?? 0).toDouble();
    
    // หมายเหตุ: paidKeed/unpaidKeed เป็นหน่วย "ขีด" (เกม) อาจจะยังต้องคำนวณหน้าบ้านเล็กน้อยถ้า API ไม่ส่งมา
    // หรือถ้าต้องการความแม่นยำ 100% ควรเพิ่ม field ใน API แต่ในที่นี้ขอคง Logic เดิมไว้เฉพาะส่วนหน่วยนับ
    double paidKeed = 0;
    double unpaidKeed = 0;
    for (var p in participants) {
       double totalCost = (num.tryParse('${p['totalCost']}') ?? 0).toDouble();
       double paid = (num.tryParse('${p['paidAmount']}') ?? 0).toDouble();
       double ratio = totalCost > 0 ? paid / totalCost : 0;
       if (ratio > 1) ratio = 1;
       int games = (p['gamesPlayed'] as int? ?? 0);
       paidKeed += games * ratio;
       unpaidKeed += games * (1 - ratio);
    }

    // 3. ค่าบริการ (Service Fee)
    // double totalServiceFee = participants.length * 10.0; // ใช้ค่าจาก API ดีกว่าถ้ามี แต่ในที่นี้คำนวณง่ายๆ
    double totalServiceFee = (num.tryParse('${data['totalIncome']}') ?? 0).toDouble() 
                           - (num.tryParse('${data['totalCourtIncome']}') ?? 0).toDouble()
                           - (num.tryParse('${data['totalShuttlecockFee']}') ?? 0).toDouble()
                           - totalAdditions + totalSubtractions.abs();
    if (totalServiceFee < 0) totalServiceFee = participants.length * 10.0; // Fallback
    
    // 4. คำนวณรายจ่ายจริง (ต้นทุนสนาม + ต้นทุนลูกแบด)
    double totalCourtCostReal = (num.tryParse('${data['totalCourtCost']}') ?? 0).toDouble();
    double totalShuttleCostReal = (num.tryParse('${data['totalShuttlecockCost']}') ?? 0).toDouble();
    double totalExpenseReal = totalCourtCostReal + totalShuttleCostReal;

    // แปลงข้อมูลจาก API เป็น Map สำหรับแสดงผล
    final courtCosts = {
      'ผู้เล่น': '${data['currentParticipants'] ?? 0} คน',
      'ต้นทุนค่าสนาม': '${fmt(data['totalCourtCost'])} บาท', // ใช้ totalCourtCost (ต้นทุน)
      'ค่าสนาม/คน': '${fmt(data['courtFeePerPerson'])} บาท',
      'ยอดรวม': '${fmt(data['totalCourtIncome'])} บาท',
      '-------': '', // ตัวคั่น
      'ชำระแล้ว': '$paidCourtCount คน',
      'เป็นเงิน': '${fmt(paidCourtAmount)} บาท',
      'รอชำระ': '$unpaidCourtCount คน',
      'เป็นเงิน ': '${fmt(unpaidCourtAmount)} บาท', // มี space ต่อท้ายเพื่อไม่ให้ key ซ้ำ
    };

    final shuttlecockCosts = {
      'ทุนค่าลูก/ลูก': '${fmt(data['shuttlecockCostPerUnit'])} บาท',
      'ทุนค่าลูก/ขีด': '${fmtDec(costPerKeed)} บาท',
      'ใช้รวม(ลูก)': '${data['totalShuttlecocks'] ?? 0} ลูก',
      'ใช้รวม(ขีด)': '$totalKeed ขีด',
      'ราคา/ขีด': '${fmt(data['shuttlecockFeePerPerson'])} บาท',
      'ยอดรวม': '${fmt(data['totalShuttlecockFee'])} บาท',
      '------------': '', // ตัวคั่น
      'ชำระแล้ว': '${fmtDec(paidKeed)} ขีด',
      'เป็นเงิน': '${fmt(paidShuttleAmount)} บาท',
      'รอชำระ': '${fmtDec(unpaidKeed)} ขีด',
      'เป็นเงิน ': '${fmt(unpaidShuttleAmount)} บาท',
    };

    final Map<String, String> totalSummary = {};
    final List<String> highlightKeysTotal = [];

    double totalTransferAmount = (num.tryParse('${data['totalTransferAmount']}') ?? 0).toDouble();
    double totalCashAmount = (num.tryParse('${data['totalCashAmount']}') ?? 0).toDouble();
    double totalCollected = totalTransferAmount + totalCashAmount;
    double totalUnpaid = totalIncomeCalculated - totalCollected;

    totalSummary['ได้รับเงินผ่านแอป'] = '${fmt(data['totalTransferAmount'])} บาท';
    totalSummary['เงินสด'] = '${fmt(data['totalCashAmount'])} บาท';

    if (totalAdditions > 0) {
      totalSummary['เพิ่มค่าใช้จ่าย'] = '${fmt(totalAdditions)} บาท';
      highlightKeysTotal.add('เพิ่มค่าใช้จ่าย');
    }
    if (totalSubtractions < 0) {
      totalSummary['ลดค่าใช้จ่าย'] = '${fmt(totalSubtractions.abs())} บาท';
      highlightKeysTotal.add('ลดค่าใช้จ่าย');
    }

    totalSummary['รายรับ'] = '${fmt(totalCollected)} บาท';
    totalSummary['ค่าบริการ'] = '${fmt(totalServiceFee)} บาท';
    totalSummary['คงเหลือ'] = '${fmt(totalUnpaid)} บาท';

    highlightKeysTotal.addAll(['รายรับ', 'ค่าบริการ', 'คงเหลือ']);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _SummaryCard(
            title: 'ค่าสนาม',
            data: courtCosts,
            highlightKeys: const ['ยอดรวม', 'เป็นเงิน', 'เป็นเงิน '],
          ),
          const SizedBox(height: 16),
          _SummaryCard(
            title: 'ยอดลูกแบด',
            data: shuttlecockCosts,
            highlightKeys: const ['ยอดรวม', 'เป็นเงิน', 'เป็นเงิน '],
          ),
          const SizedBox(height: 16),
          _SummaryCard(
            title: 'ยอดทั้งหมด',
            data: totalSummary,
            highlightKeys: highlightKeysTotal,
            useSingleColumn: true,
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
  final bool useSingleColumn;

  const _SummaryCard({
    required this.title,
    required this.data,
    this.highlightKeys = const [],
    this.useSingleColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    // แปลง Map ให้อยู่ในรูปแบบ List ของ RowData เพื่อจัดการ Layout ได้ง่ายขึ้น
    List<_RowData> rows = [];
    var keys = data.keys.toList();

    if (useSingleColumn) {
      for (var key in keys) {
        if (key.startsWith('---')) {
          rows.add(_RowData('DIVIDER', '', null, null));
        } else {
          rows.add(_RowData(key, data[key]!, null, null));
        }
      }
    } else {
      int i = 0;
      while (i < keys.length) {
        if (keys[i].startsWith('---')) {
          rows.add(_RowData('DIVIDER', '', null, null));
          i++;
        } else if (i + 1 < keys.length && !keys[i + 1].startsWith('---')) {
          rows.add(_RowData(keys[i], data[keys[i]]!, keys[i + 1], data[keys[i + 1]]!));
          i += 2;
        } else {
          rows.add(_RowData(keys[i], data[keys[i]]!, null, null));
          i++;
        }
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
    if (rowData.key1 == 'DIVIDER') {
      return const Divider(color: Colors.grey, thickness: 1, height: 16);
    }

    Widget buildCell(String key, String value) {
      final bool isHighlight = highlightKeys.contains(key);
      Color textColor = Colors.black;
      FontWeight fontWeight = FontWeight.normal;

      if (isHighlight) {
        fontWeight = FontWeight.bold;
        if (key == 'เป็นเงิน') {
          textColor = Colors.green;
        } else if (key == 'เป็นเงิน ') {
          textColor = Colors.red;
        } else if (key == 'ยอดรวม') {
          // ตรวจสอบว่าชำระครบหรือยัง โดยดูจากยอดรอชำระ ('เป็นเงิน ')
          bool isFullyPaid = true;
          if (data.containsKey('เป็นเงิน ')) {
            String pendingVal = data['เป็นเงิน ']!.replaceAll(RegExp(r'[^0-9.]'), '');
            double pending = double.tryParse(pendingVal) ?? 0;
            if (pending > 0) isFullyPaid = false;
          }
          textColor = isFullyPaid ? Colors.green : Colors.black;
        } else if (key == 'ลดค่าใช้จ่าย') {
          textColor = Colors.red;
        } else if (key == 'คงเหลือ') {
          String valStr = value.replaceAll(RegExp(r'[^0-9.-]'), '');
          double val = double.tryParse(valStr) ?? 0;
          textColor = val == 0 ? Colors.green : Colors.red;
        } else {
          // ยอดอื่นๆ ที่ต้องการเน้น (รายรับ, คงเหลือ, ค่าบริการ, etc.) ให้เป็นสีเขียว
          textColor = Colors.green;
        }
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              key.trim(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ],
      );
    }

    if (rowData.key2 != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Expanded(child: buildCell(rowData.key1, rowData.value1)),
            const SizedBox(width: 12),
            Expanded(child: buildCell(rowData.key2!, rowData.value2!)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: buildCell(rowData.key1, rowData.value1),
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
  final double serviceFee; // NEW

  const PlayerListCard({
    super.key,
    required this.onPlayerTap,
    this.participants = const [],
    this.shuttlecockRate = 0,
    this.courtFee = 0,
    this.serviceFee = 10.0, // NEW
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

        // --- FIX: ใช้ค่าจาก API โดยตรง ไม่ต้องคำนวณเอง ---
        final courtNum = num.tryParse('${p['courtFee']}') ?? 0;
        final shuttleNum = num.tryParse('${p['shuttleFee']}') ?? 0;
        
        final gamesNum = num.tryParse(games) ?? 0;
        final rateNum = num.tryParse('$shuttlecockRate') ?? 0;
        
        String formatNum(num n) => n.toStringAsFixed(0);
        
        // แสดงผล: ถ้าค่าลูกแบดตรงกับสูตรคูณ ให้แสดงสูตร ถ้าไม่ตรง (เช่น เหมาจ่าย) ให้แสดงยอดเลย
        final calcShuttle = gamesNum * rateNum;
        final gameDisplay = (calcShuttle - shuttleNum).abs() < 1 
            ? '${formatNum(gamesNum)} x ${formatNum(rateNum)} = ${formatNum(shuttleNum)}'
            : '${formatNum(shuttleNum)}';

        final totalFromApi = num.tryParse('${p['totalCost']}') ?? 0;
        final paidFromApi = num.tryParse('${p['paidAmount']}') ?? 0;
        
        // --- FIX: หักค่าบริการ (Service Fee) ออกจากทุกยอดเพื่อแสดงรายรับจริงของผู้จัด ---
        double totalDisplayVal = 0;
        double paidDisplayVal = 0;
        double unpaidDisplayVal = 0;

        if (totalFromApi > 0) {
           // 1. ยอดรวม: หักค่าบริการออก (เช่น 185 - 10 = 175)
           totalDisplayVal = (totalFromApi - serviceFee).clamp(0, double.infinity);
           
           // 2. จ่ายแล้ว: หักค่าบริการออก (ถือว่าลูกค้าจ่ายค่าบริการให้ระบบไปแล้ว ส่วนที่เหลือคือของผู้จัด)
           // เช่น จ่ายมา 185 -> ระบบหัก 10 -> ผู้จัดเห็นว่าจ่ายแล้ว 175
           paidDisplayVal = (paidFromApi >= serviceFee) ? (paidFromApi - serviceFee) : 0;
           
           // 3. ค้างจ่าย: คำนวณจาก ยอดรวมใหม่ - จ่ายแล้วใหม่
           unpaidDisplayVal = (totalDisplayVal - paidDisplayVal).clamp(0, double.infinity);
        }

        final total = formatNum(totalDisplayVal);
        final paid = formatNum(paidDisplayVal);
        final unpaid = formatNum(unpaidDisplayVal);

        // 4. อื่นๆ: คำนวณจากยอดรวมใหม่ (ไม่ต้องลบ serviceFee ซ้ำ เพราะ totalDisplayVal ลบไปแล้ว)
        final othersNum = totalDisplayVal - (courtNum + shuttleNum);
        final others = formatNum(othersNum);

        final unpaidNum = unpaidDisplayVal;
        final rowColor = unpaidNum > 0 ? Colors.red : Colors.green;

        return GestureDetector(
          onTap: () => onPlayerTap(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                text(2, '${index + 1}', 14, FontWeight.w300, color: rowColor),
                text(3, name, 14, FontWeight.w300, color: rowColor),
                // --- NEW: เพิ่มคอลัมน์ค่าสนาม ---
                text(2, formatNum(courtNum), 14, FontWeight.w300, color: rowColor),
                text(5, gameDisplay, 12, FontWeight.w300, color: rowColor),
                text(2, others, 14, FontWeight.w300, color: rowColor), // ย้าย "อื่นๆ" มาก่อน "ยอด"
                text(2, total, 14, FontWeight.w300, color: rowColor),
                text(2, paid, 14, FontWeight.w300, color: rowColor),
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
                  // --- NEW: เพิ่มหัวตารางค่าสนาม ---
                  text(2, 'สนาม', 14, FontWeight.w700),
                  text(5, 'เกมส์', 14, FontWeight.w700),
                  text(2, 'อื่นๆ', 14, FontWeight.w700), // ย้าย "อื่นๆ" มาก่อน "ยอด"
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
