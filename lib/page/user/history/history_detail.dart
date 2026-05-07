import 'package:badminton/component/Button.dart';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/component/player_match_card.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

class HistoryDetailPage extends StatefulWidget {
  final String code;
  const HistoryDetailPage({super.key, required this.code});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _sessionDetail;
  List<dynamic> _matches = [];

  @override
  void initState() {
    super.initState();
    _fetchHistoryDetail();
  }

  Future<void> _fetchHistoryDetail() async {
    try {
      // เรียก Endpoint ตามที่ Controller ใน C# กำหนดไว้
      final response = await ApiProvider().get('/player/gamesessions/${widget.code}/history-detail');
      if (mounted) {
        setState(() {
          _sessionDetail = response['data'] ?? {};
          _matches = _sessionDetail?['matches'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'ประวัติ'),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildSummaryCard(),
                          _buildPaymentCard(),
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
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: _matches.isEmpty ? 1 : _matches.length,
                          itemBuilder: (context, index) {
                            if (_matches.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: Text('ไม่พบประวัติเกมการแข่งขัน', style: TextStyle(color: Colors.white)),
                                ),
                              );
                            }
                        final matchData = _matches[index];
                        if (matchData['myTeam'] != null && matchData['myTeam'].isNotEmpty) {
                          matchData['me'] = matchData['myTeam'][0];
                        }
                        return PlayerMatchCard(match: matchData, index: index + 1);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSummaryCard() {
    final summary = _sessionDetail?['summary'] ?? {};
    final totalGames = summary['totalGames']?.toString() ?? '0';
    final totalShuttlecocks = summary['totalShuttlecocks']?.toString() ?? '0';
    final totalPlayTime = summary['totalPlayTime']?.toString() ?? '0';
    final totalWaitTime = summary['totalWaitTime']?.toString() ?? '0';

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
                _buildSummaryInfo('เกมที่เล่น', totalGames, 'เกม'),
                _buildSummaryInfo('เวลาเล่น', totalPlayTime, 'นาที'),
                _buildSummaryInfo('เวลารอ', totalWaitTime, 'นาที'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    final payment = _sessionDetail?['payment'] ?? {};
    final status = payment['status'] ?? 'Pending';
    final totalAmount = payment['totalAmount']?.toString() ?? '0';
    final paymentDate = payment['paymentDate'] ?? '-';
    final paymentMethod = payment['paymentMethod'] ?? '-';
    final lineItems = payment['lineItems'] as List? ?? [];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...lineItems.map((item) {
              final amount = item['amount'];
              final formattedAmount = (amount is num && amount == amount.toInt()) ? amount.toInt().toString() : amount.toString();
              return _buildPriceRow(item['description'] ?? '', '$formattedAmount บาท');
            }),
            _buildPriceRow(status == 'Pending' ? 'ยอดค้างชำระ' : 'ราคารวม', '${(num.tryParse(totalAmount) ?? 0).toInt()} บาท', isBold: true),
            Divider(height: 24),
            if (status == 'Completed') ...[
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
                    paymentDate,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'ชำระผ่าน $paymentMethod',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Text(
                    'ค้างชำระ',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CustomElevatedButton(
                  text: 'ชำระเงิน',
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    context.push('/payment-now/${widget.code}');
                  },
                ),
              ),
            ]
          ],
        ),
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
