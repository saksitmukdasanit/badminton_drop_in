import 'package:badminton/component/manage_game_models.dart';
import 'package:flutter/material.dart';
import 'package:badminton/model/player.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/qr_payment_dialog.dart';
import 'package:badminton/widget/expense_panel.dart';

class ExpensePanel extends StatefulWidget {
  final Player? player;
  final VoidCallback onClose;
  final String sessionId;
  final List<dynamic> skillLevels;
  final bool isPaused;
  final VoidCallback? onTogglePause;
  final double courtFee;
  final double shuttleFee;
  final bool isEnded;
  final VoidCallback? onToggleEndGame;
  final VoidCallback? onPaymentSuccess;

  const ExpensePanel({
    super.key,
    this.player,
    required this.onClose,
    required this.sessionId,
    required this.skillLevels,
    this.isPaused = false,
    this.onTogglePause,
    this.courtFee = 0.0,
    this.shuttleFee = 0.0,
    this.isEnded = false,
    this.onToggleEndGame,
    this.onPaymentSuccess,
  });

  @override
  State<ExpensePanel> createState() => _ExpensePanelState();
}

class _ExpensePanelState extends State<ExpensePanel> {
  bool _isEmergencyContactVisible = false;
  late int _selectedSkillLevel;
  bool _isLoading = false;
  PlayerStats? _playerStats;
  dynamic _billData;

  @override
  void initState() {
    super.initState();
    _selectedSkillLevel = widget.player?.skillLevelId ?? 1;
    if (widget.player != null) _fetchData();
  }

  @override
  void didUpdateWidget(covariant ExpensePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player != oldWidget.player && widget.player != null) {
      _fetchData();
      setState(() => _selectedSkillLevel = widget.player?.skillLevelId ?? 1);
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final parts = widget.player!.id.split('_');
    final pType = parts[0].toLowerCase();
    final pId = parts[1];

    try {
      final statsRes = await ApiProvider().get('/gamesessions/${widget.sessionId}/player-stats/$pType/$pId');
      _playerStats = PlayerStats.fromJson(statsRes['data']);
    } catch (e) {}

    try {
      final billRes = await ApiProvider().get('/participants/$pType/$pId/bill-preview');
      _billData = billRes['data'];
    } catch (e) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handlePayment(String paymentMethod, List<ExpenseAdjustment> adjustments) async {
    setState(() => _isLoading = true);
    try {
      final parts = widget.player!.id.split('_');
      final pType = parts[0].toLowerCase();
      final pId = parts[1];
    
      double estimatedTotal = 0.0;
      List<Map<String, dynamic>> customLineItems = [];

      // --- FIX: ตรวจสอบว่าจ่ายค่าสนามไปแล้วหรือยัง ---
      double courtAmount = 0.0;
      if (_billData != null && _billData['lineItems'] != null) {
         final items = _billData['lineItems'] as List;
         final item = items.firstWhere((i) => i['description'] == 'ค่าคอร์ท' || i['description'] == 'ค่าสนาม', orElse: () => null);
         if (item != null) courtAmount = (item['amount'] ?? 0).toDouble();
      } else {
         courtAmount = widget.courtFee; // Fallback
      }
      if (courtAmount > 0) {
         customLineItems.add({'description': 'ค่าสนาม', 'amount': courtAmount});
         estimatedTotal += courtAmount;
      }

      // --- FIX: ตรวจสอบว่าจ่ายค่าธรรมเนียมไปแล้วหรือยัง ---
      double serviceFee = 0.0;
      if (_billData != null && _billData['lineItems'] != null) {
         final items = _billData['lineItems'] as List;
         final item = items.firstWhere((i) => i['description'] == 'ค่าธรรมเนียม', orElse: () => null);
         if (item != null) serviceFee = (item['amount'] ?? 0).toDouble();
      } else {
         serviceFee = 10.0; // Fallback
      }
      if (serviceFee > 0) {
         customLineItems.add({'description': 'ค่าธรรมเนียม', 'amount': serviceFee});
         estimatedTotal += serviceFee;
      }

      double shuttleTotal = 0.0;
      final int totalGames = _playerStats?.totalGamesPlayed ?? 0;
      if (totalGames > 0 && widget.shuttleFee > 0) {
         shuttleTotal = totalGames * widget.shuttleFee;
      } else {
         if (_billData != null && _billData['lineItems'] != null) {
            final items = _billData['lineItems'] as List;
            final item = items.firstWhere((i) => (i['description'] ?? '').toString().startsWith('ค่าลูกแบด'), orElse: () => null);
            if (item != null) shuttleTotal = (item['amount'] ?? 0).toDouble();
         }
      }
      if (shuttleTotal > 0) {
         customLineItems.add({'description': 'ค่าลูกแบด ($totalGames เกม)', 'amount': shuttleTotal});
         estimatedTotal += shuttleTotal;
      }

      for (var adj in adjustments) {
        double amount = adj.amount;
        if (adj.type == AdjustmentType.subtraction) amount = -amount;
        customLineItems.add({'description': adj.name, 'amount': amount});
        estimatedTotal += amount;
      }

      if (paymentMethod == 'QR Code') {
        if (mounted) {
          setState(() => _isLoading = false); 
          final confirm = await showQrPaymentDialog(context, estimatedTotal);
          if (confirm != true) return; 
          setState(() => _isLoading = true); 
        }
      }

      final checkoutRes = await ApiProvider().post('/participants/$pType/$pId/checkout', data: {'customLineItems': customLineItems});
      final int billId = checkoutRes['data']['billId'];

      // --- NEW: ดักไว้ว่าถ้ายังไม่จ่าย ให้แค่ปิดหน้าจอ ไม่ต้องเรียก API ยืนยันรับเงิน ---
      if (paymentMethod == 'ยังไม่จ่าย' || paymentMethod == 'ค้างชำระ') {
        if (mounted) {
          showDialogMsg(
            context, title: 'บันทึกสำเร็จ', subtitle: 'สร้างบิลและบันทึกค้างชำระเรียบร้อยแล้ว', btnLeft: 'ตกลง', btnLeftBackColor: const Color(0xFF0E9D7A), btnLeftForeColor: Colors.white,
            onConfirm: () { widget.onClose(); widget.onPaymentSuccess?.call(); },
          );
        }
      } else if (estimatedTotal > 0) {
        await _confirmPaymentAPI(billId, paymentMethod, estimatedTotal);
      } else {
        widget.onClose(); widget.onPaymentSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        if (!errStr.contains('401') && !errStr.contains('Invalid tokens')) {
          showDialogMsg(context, title: 'เกิดข้อผิดพลาด', subtitle: 'ในการชำระเงิน', btnLeft: 'ตกลง', onConfirm: () {});
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmPaymentAPI(int billId, String method, double amount) async {
    await ApiProvider().post('/bills/$billId/pay', data: {'paymentMethod': method, 'amount': amount});
    if (mounted) {
      showDialogMsg(
        context, title: 'ชำระเงินสำเร็จ', subtitle: 'บันทึกการชำระเงินเรียบร้อยแล้ว', btnLeft: 'ตกลง', btnLeftBackColor: const Color(0xFF0E9D7A), btnLeftForeColor: Colors.white,
        onConfirm: () { widget.onClose(); widget.onPaymentSuccess?.call(); },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.player == null) return const SizedBox.shrink();
    final player = widget.player!;
    final sizedBoxheight = 20.0;

    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 450,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (player.imageUrl != null && player.imageUrl!.isNotEmpty)
                      CircleAvatar(radius: 30, backgroundImage: NetworkImage(player.imageUrl!))
                    else
                      const CircleAvatar(radius: 30, child: Icon(Icons.person)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player.fullName ?? player.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                          Row(
                            children: [
                              const Text('ระดับมือ: '),
                              DropdownButton<String>(
                                value: _selectedSkillLevel.toString(),
                                items: widget.skillLevels.map((level) => DropdownMenuItem<String>(value: level['code'], child: Text(level['value']))).toList(),
                                onChanged: (val) { if (val != null) setState(() => _selectedSkillLevel = int.parse(val)); },
                              ),
                              const Spacer(),
                              IconButton(icon: const Icon(Icons.medical_services_outlined, color: Colors.red), onPressed: () => setState(() => _isEmergencyContactVisible = !_isEmergencyContactVisible)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isEmergencyContactVisible
                      ? Container(
                          key: const ValueKey('contact_visible'), width: double.infinity, color: Colors.red[100], padding: const EdgeInsets.all(12),
                          child: Text('ผู้ติดต่อฉุกเฉิน: ${(player.emergencyContactName?.isNotEmpty == true) ? player.emergencyContactName : "-"} ${(player.emergencyContactPhone?.isNotEmpty == true) ? player.emergencyContactPhone : "-"}', style: TextStyle(color: Colors.red[800])),
                        )
                      : const SizedBox.shrink(key: ValueKey('contact_hidden')),
                ),
                SizedBox(height: sizedBoxheight),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    children: [
                      const TextSpan(text: 'เล่นไป '), TextSpan(text: '${_playerStats?.totalGamesPlayed ?? 0} เกม  ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const TextSpan(text: 'เวลาที่รอ '), TextSpan(text: '${_playerStats?.totalMinutesPlayed ?? "00:00"} นาที', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
                SizedBox(height: sizedBoxheight),
                Table(
                  border: TableBorder.all(color: Colors.grey.shade700, width: 1),
                  columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1), 4: FlexColumnWidth(2)},
                  children: [
                    buildRow(['เกมที่', '#', 'ทีม', 'VS', 'คู่แข่ง'], isHeader: true),
                    if (_playerStats?.matchHistory != null)
                      ..._playerStats!.matchHistory.asMap().entries.map((entry) {
                        int index = entry.key;
                        MatchHistoryItem history = entry.value;
                        return buildRow([(index + 1).toString(), history.courtNumber.toString(), history.teammate.nickname, 'VS', history.opponents.map((op) => op.nickname).join(', ')]);
                      }).toList(),
                  ],
                ),
                SizedBox(height: sizedBoxheight),
                Row(
                  children: [
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 8, vertical: 16), text: widget.isPaused ? 'ผู้เล่นกลับสู่เกม' : 'หยุดเกมส์ผู้เล่น',
                        backgroundColor: widget.isPaused ? const Color(0xFF0E9D7A) : const Color(0xFFFFFFFF), foregroundColor: widget.isPaused ? Colors.white : const Color(0xFF0E9D7A),
                        side: const BorderSide(color: Color(0xFFB3B3C1)), fontSize: 12, fontWeight: FontWeight.w600, onPressed: widget.onTogglePause ?? () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 8, vertical: 16), text: widget.isEnded ? 'กลับสู่เกมส์' : 'จบเกมส์ผู้เล่น',
                        backgroundColor: widget.isEnded ? Colors.red : const Color(0xFFFFFFFF), foregroundColor: widget.isEnded ? Colors.white : const Color(0xFF0E9D7A),
                        side: const BorderSide(color: Color(0xFFB3B3C1)), fontSize: 12, fontWeight: FontWeight.w600, onPressed: widget.onToggleEndGame ?? () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 8, vertical: 16), text: 'ค่าใช้จ่าย', backgroundColor: Colors.grey,
                        side: const BorderSide(color: Colors.grey), fontSize: 12, fontWeight: FontWeight.w600, icon: Icons.keyboard_arrow_up, enabled: false, onPressed: () {},
                      ),
                    ),
                  ],
                ),
                SizedBox(height: sizedBoxheight),
                if (_isLoading) const Center(child: CircularProgressIndicator())
                else ExpensePanelWidget(
                  billData: _billData,
                  courtFee: widget.courtFee,
                  shuttlecockFee: widget.shuttleFee,
                  totalGames: _playerStats?.totalGamesPlayed ?? 0,
                  paidAmount: (_billData?['paidAmount'] ?? 0.0).toDouble(),
                  serviceFee: (_billData?['serviceFee'] ?? 10.0).toDouble(),
                  onConfirmPayment: (adjustments) =>
                      _handlePayment('Cash', adjustments), // Default to 'Cash' or any method
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TableRow buildRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells.map((cell) => Padding(padding: const EdgeInsets.all(8.0), child: Text(cell, textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, fontSize: 16)))).toList(),
    );
  }
}