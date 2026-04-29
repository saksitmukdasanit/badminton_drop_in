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

  // เปลี่ยนเป็น Future<void> เพื่อให้ await ได้
  Future<void> _showPaymentPanel(dynamic player) async {
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

    // 1. ดึงค่ายอดที่จ่ายแล้วมาหักลบ เพื่อคำนวณยอดคงเหลือที่ถูกต้องและไม่ให้ยอดเบิ้ล
    final double paidAmount = (num.tryParse('${_selectedPlayer['paidAmount'] ?? 0}') ?? 0).toDouble();

    final pId = _selectedPlayer['participantId'] ?? _selectedPlayer['userId'] ?? _selectedPlayer['id'];
    final pType = _selectedPlayer['participantType'] ?? 'Member';

    // 2. คำนวณยอดที่จะต้องจ่าย (Base + Adjustments)
    List<Map<String, dynamic>> customLineItems = [];

    for (var adj in adjustments) {
      double amount = adj.amount;
      if (adj.type == AdjustmentType.subtraction) amount = -amount;
      customLineItems.add({'description': adj.name, 'amount': amount});
    }

    // ลบการแสดง QrPaymentDialog ตรงนี้ออก เพราะใน ExpensePanelWidget มีแสดง Dialog ไปแล้ว ทำให้ไม่ต้องกด 2 รอบ

    // 4. เริ่มกระบวนการบันทึกจริง (ยิง API)
    setState(() => _isBillLoading = true);

    try {
      
      // 4.2 เรียก API Checkout เพื่อสร้างบิลจริง
      final checkoutRes = await ApiProvider().post(
        '/participants/$pType/$pId/checkout',
        data: {'customLineItems': customLineItems},
      );
      
      final finalBill = checkoutRes['data'];
      final int billId = finalBill['billId'];
      
      // --- NEW: ใช้ยอดชำระสุทธิจาก API บิลโดยตรง ป้องกันปัญหายอดติดลบจากการหักลบเอง ---
      final double actualDueAmount = (num.tryParse('${finalBill['totalAmount'] ?? 0}') ?? 0).toDouble();

      // 4.3 บันทึกการจ่ายเงิน
      if (actualDueAmount > 0) {
         // --- NEW: ถ้าเลือก "ยังไม่จ่าย" ไม่ต้องเรียก API /pay ---
         if (paymentMethod == 'ยังไม่จ่าย' || paymentMethod == 'ค้างชำระ') {
             _hidePaymentPanel();
             _fetchSessionData();
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('สร้างบิลและบันทึกค้างชำระสำเร็จ')));
             }
         } else {
             await _confirmPaymentAPI(billId, paymentMethod, actualDueAmount);
         }
      } else {
         // ถ้ายอดเป็น 0 (หักลบกลบหนี้หมดแล้ว) ให้ปิดหน้าจอได้เลย ไม่ต้องบันทึกรับเงินซ้ำ
         _hidePaymentPanel();
         _fetchSessionData();
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
      final res = await ApiProvider().post('/bills/$billId/pay', data: {'paymentMethod': method, 'amount': amount});

      if (mounted) {
        // --- NEW: ถ้าเป็น QR Code ให้แสดง Popup สแกน ---
        if (method == 'QR Code' && res['data'] != null && res['data']['qrCode'] != null) {
          String qrString = res['data']['qrCode'];
          final confirmed = await showQrPaymentDialog(
            context, 
            amount, 
            qrData: qrString,
            sessionId: widget.sessionId,
            billId: billId,
          );
          
          if (confirmed != true) {
            // ถ้ายกเลิก/กดปิด QR เอง ให้ดึงยอดรวมใหม่ และรอจนกว่าจะโหลดบิลค้างชำระเสร็จ
            if (!mounted) return;
            await _fetchSessionData();
            await _showPaymentPanel(_selectedPlayer);
            return; // ถ้ายกเลิก/กดปิด QR เอง ไม่ต้องโชว์ Success
          }
        }

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

        // --- FIX: ดึง Service Fee จากผู้เล่นที่เป็น Member เท่านั้น เพื่อป้องกันค่าเป็น 0 จาก Guest ---
        double serviceFee = 10.0; // Default fallback
        try {
          final member = participants.firstWhere((p) => (p['participantType'] ?? '').toString().toLowerCase() != 'guest', orElse: () => null);
          if (member != null && member['serviceFee'] != null) {
            double memberFee = (num.tryParse('${member['serviceFee']}') ?? 0).toDouble();
            if (memberFee > 0) serviceFee = memberFee;
          }
        } catch (_) {}

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
    final bool isBuffet = _sessionData?['costingMethod'] == 2;

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
                            isBuffet: isBuffet,
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
                            isBuffet: isBuffet,
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
                    isBuffet: isBuffet,
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
                      // --- FIX: ซิงค์ยอดฝั่ง API สุทธิ (Net) กับฝั่ง Widget ยอดเต็ม (Gross) ---
                      bool isServiceFeeUnpaid = false;
                      double serviceFeeRate = 10.0; // Fallback
                      if (_selectedPlayerBill != null && _selectedPlayerBill['lineItems'] != null) {
                        final items = _selectedPlayerBill['lineItems'] as List;
                        final item = items.firstWhere((i) => i['description'] == 'ค่าธรรมเนียม', orElse: () => null);
                        if (item != null) {
                          isServiceFeeUnpaid = true;
                          serviceFeeRate = (item['amount'] ?? 10.0).toDouble();
                        }
                      }
                      
                      double netPaid = (num.tryParse('${_selectedPlayer['paidAmount'] ?? 0}')?.toDouble() ?? 0.0);
                      double grossPaid = netPaid;
                      
                      // ถ้ายอดค่าธรรมเนียมไม่โผล่ในบิลค้างชำระ (แปลว่าจ่ายไปแล้ว) และมียอด netPaid > 0 ให้บวกค่าธรรมเนียมกลับเข้าไป
                      // เพื่อให้ยอดจ่ายรวม (Gross Paid) หักลบกับยอด Total ใน Widget ได้พอดี ไม่เหลือเศษค้างชำระ 10 บาทหลอกๆ
                      if (!isServiceFeeUnpaid && netPaid > 0) {
                        grossPaid += serviceFeeRate;
                      }
                      
                      // --- NEW: คำนวณยอดส่วนต่าง (Others) เพื่อให้บิลตรงกับยอดจริง ---
                      double sessionCourtFee = num.tryParse('${_sessionData?['courtFeePerPerson'] ?? 0}')?.toDouble() ?? 0.0;
                      double sessionShuttleFeePerGame = num.tryParse('${_sessionData?['shuttlecockFeePerPerson'] ?? 0}')?.toDouble() ?? 0.0;
                      int totalGames = num.tryParse('${_selectedPlayer['gamesPlayed'] ?? 0}')?.toInt() ?? 0;
                      bool isBuffet = _sessionData?['costingMethod'] == 2;
                      

                      return ExpensePanelWidget(
                        key: ValueKey(_selectedPlayerBill?.hashCode ?? DateTime.now().millisecondsSinceEpoch),
                        isHistoryMode: true, // เปิดโหมดประวัติเพื่อแสดงยอดเต็ม และซ่อนปุ่มถ้าหักลบยอดจ่ายแล้วเป็น 0
                        billData: _selectedPlayerBill, // กลับมาใช้ข้อมูลจริงจาก API เพราะ Backend ส่งชื่อที่ถูกต้องมาให้แล้ว
                        courtFee: sessionCourtFee,
                        shuttlecockFee: sessionShuttleFeePerGame,
                        totalGames: totalGames,
                        paidAmount: grossPaid, // FIX: ส่งยอด Gross Paid แทน Net Paid 
                        serviceFee: serviceFeeRate, // ส่งค่า Service Fee เรทเต็มเข้าไป
                        onConfirmPayment: _handlePayment,
                        isBuffet: isBuffet,
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

    // API แก้ไขแล้ว ดึงค่ายอดสุทธิมาใช้ได้โดยตรง
    double totalNetIncome = (num.tryParse('${data['totalIncome']}') ?? 0).toDouble();
    double totalNetPaid = (num.tryParse('${data['paidAmount']}') ?? 0).toDouble();
    double totalNetUnpaid = (num.tryParse('${data['unpaidAmount']}') ?? 0).toDouble();
    double totalServiceFeeCalc = (num.tryParse('${data['totalServiceFeeDeducted']}') ?? 0).toDouble();

    totalSummary['รายรับทั้งหมด (สุทธิ)'] = '${fmt(totalNetIncome)} บาท';
    totalSummary['เก็บเงินแล้ว (สุทธิ)'] = '${fmt(totalNetPaid)} บาท';

    if (totalAdditions > 0) {
      totalSummary['(ในนี้มี) เพิ่มค่าใช้จ่าย'] = '${fmt(totalAdditions)} บาท';
    }
    if (totalSubtractions < 0) {
      totalSummary['(ในนี้มี) ลดค่าใช้จ่าย'] = '${fmt(totalSubtractions.abs())} บาท';
    }

    totalSummary['ค่าบริการแอป (รวม)'] = '${fmt(totalServiceFeeCalc)} บาท';
    totalSummary['คงเหลือ (ค้างจ่ายสุทธิ)'] = '${fmt(totalNetUnpaid)} บาท';

    highlightKeysTotal.addAll(['รายรับทั้งหมด (สุทธิ)', 'เก็บเงินแล้ว (สุทธิ)', 'คงเหลือ (ค้างจ่ายสุทธิ)']);

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
        } else if (key.contains('คงเหลือ')) {
          String valStr = value.replaceAll(RegExp(r'[^0-9.-]'), '');
          double val = double.tryParse(valStr) ?? 0;
          textColor = val <= 0 ? Colors.green : Colors.red;
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
  final bool isBuffet;

  const PlayerListCard({
    super.key,
    required this.onPlayerTap,
    this.participants = const [],
    this.shuttlecockRate = 0,
    this.courtFee = 0,
    this.serviceFee = 10.0, // NEW
    this.isScrollable = false,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.isBuffet = false,
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

        // --- FIX: คำนวณยอดสุทธิของผู้จัด (Net) โดยหักค่าธรรมเนียมแอปออกด้วยตัวเอง ---
        // เพื่อป้องกันกรณี API ส่งยอดรวม (Gross) มา แล้วทำให้ตารางแสดงค่าธรรมเนียมรวมไปด้วย
        double rawTotal = (num.tryParse('${p['totalCost']}') ?? 0).toDouble();
        double rawPaid = (num.tryParse('${p['paidAmount']}') ?? 0).toDouble();
        
        // API ถูกแก้ไขให้ส่งยอดสุทธิมาแล้ว ใช้ค่า raw ตรงๆ ได้เลย
        double totalDisplayVal = rawTotal;
        double paidDisplayVal = rawPaid;
        double unpaidDisplayVal = (num.tryParse('${p['unpaidAmount']}') ?? 0).toDouble();

        final total = formatNum(totalDisplayVal);
        final paid = formatNum(paidDisplayVal);
        final unpaid = formatNum(unpaidDisplayVal);

        double othersNum = totalDisplayVal - (courtNum + shuttleNum);
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
                text(2, formatNum(courtNum), 14, FontWeight.w300, color: rowColor),
                text(5, gameDisplay, 12, FontWeight.w300, color: rowColor),
                text(2, others, 14, FontWeight.w300, color: rowColor),
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
                  text(2, 'สนาม', 14, FontWeight.w700),
                  text(5, 'เกมส์', 14, FontWeight.w700),
                  text(2, 'อื่นๆ', 14, FontWeight.w700),
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
