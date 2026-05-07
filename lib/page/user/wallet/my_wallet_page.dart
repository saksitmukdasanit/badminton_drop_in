import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/skeleton.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MyWalletPage extends StatefulWidget {
  const MyWalletPage({super.key});

  @override
  State<MyWalletPage> createState() => _MyWalletPageState();
}

class _MyWalletPageState extends State<MyWalletPage> {
  bool _isLoading = true;
  double _balance = 0.0;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  Future<void> _fetchWalletData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiProvider().get('/player/wallet/me');
      if (mounted && res['status'] == 200) {
        setState(() {
          _balance = (num.tryParse('${res['data']['balance']}') ?? 0).toDouble();
          _transactions = res['data']['transactions'] ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'เกิดข้อผิดพลาด',
          subtitle: 'ไม่สามารถดึงข้อมูลกระเป๋าเงินได้: ${e.toString().replaceFirst('Exception: ', '')}',
          btnLeft: 'ตกลง',
          onConfirm: () => context.pop(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm น.').format(dt);
    } catch (e) {
      return '-';
    }
  }

  void _showWithdrawDialog() {
    if (_balance <= 0) {
      showDialogMsg(
        context,
        title: 'ไม่สามารถถอนเงินได้',
        subtitle: 'ยอดเงินคงเหลือของคุณเป็น 0 บาท',
        btnLeft: 'ตกลง',
        onConfirm: () {},
      );
      return;
    }

    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('ถอนเงินเข้าบัญชี', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ยอดที่ถอนได้สูงสุด: ${_balance.toStringAsFixed(0)} บาท'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ระบุจำนวนเงินที่ต้องการถอน',
                  suffixText: 'บาท',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
              onPressed: () {
                double? amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0 && amount <= _balance) {
                  context.pop();
                  _processWithdraw(amount);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('จำนวนเงินไม่ถูกต้อง หรือเกินยอดคงเหลือ')));
                }
              },
              child: const Text('ยืนยันถอนเงิน', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processWithdraw(double amount) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiProvider().post('/player/wallet/withdraw', data: {'amount': amount});
      if (mounted && res['status'] == 200) {
        showDialogMsg(
          context,
          title: 'ทำรายการสำเร็จ',
          subtitle: res['message'] ?? 'ส่งคำขอถอนเงินเรียบร้อยแล้ว',
          btnLeft: 'ตกลง',
          onConfirm: () => _fetchWalletData(),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        if (errorMsg.contains('ตั้งค่าบัญชี')) {
          showDialogMsg(
            context,
            title: 'ยังไม่ได้ตั้งค่าบัญชีรับเงิน',
            subtitle: errorMsg,
            btnLeft: 'ไปตั้งค่าบัญชี',
            btnLeftBackColor: Colors.white,
            btnLeftForeColor: Theme.of(context).colorScheme.primary,
            btnRight: 'ปิด',
            onConfirm: () => context.push('/saved-payment'),
          );
        } else {
          showDialogMsg(context, title: 'เกิดข้อผิดพลาด', subtitle: errorMsg, btnLeft: 'ตกลง', onConfirm: () {});
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: const AppBarSubMain(title: 'กระเป๋าเงินของฉัน'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const WalletPageSkeleton()
            : RefreshIndicator(
                onRefresh: _fetchWalletData,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // --- ส่วนหัว: แสดงยอดเงิน ---
                    _buildBalanceCard(),
                    const SizedBox(height: 24),
                    
                    // --- ส่วนประวัติรายการ ---
                    const Text(
                      'ประวัติรายการ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_transactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'คุณยังไม่มีประวัติการทำรายการ',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      )
                    else
                      ..._transactions.map((tx) => _buildTransactionItem(tx)).toList(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'ยอดเงินคงเหลือ (เครดิต)',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '฿ ${_balance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showWithdrawDialog();
              },
              icon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0E9D7A)),
              label: const Text(
                'ถอนเงิน',
                style: TextStyle(color: Color(0xFF0E9D7A), fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(dynamic tx) {
    final int type = tx['transactionType'] ?? 1; // 1 = IN (Refund), 2 = OUT (Payment)
    final bool isIncome = type == 1;
    final double amount = (num.tryParse('${tx['amount']}') ?? 0).toDouble();
    final String dateStr = _formatDate(tx['createdDate'] ?? '');
    final String desc = tx['description'] ?? (isIncome ? 'รับเงินคืน' : 'ชำระค่าก๊วน');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isIncome
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          child: Icon(
            isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
        title: Text(desc, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(dateStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${amount.toStringAsFixed(0)} ฿',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }
}