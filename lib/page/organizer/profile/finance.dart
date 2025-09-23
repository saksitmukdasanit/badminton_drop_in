import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/button.dart';
import 'package:badminton/component/dropdown.dart';
import 'package:badminton/page/organizer/history/history_organizer.dart';
import 'package:badminton/page/organizer/history/history_organizer_payment.dart';
import 'package:badminton/shared/function.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// --- Data Models (สร้างขึ้นมาเพื่อจัดระเบียบข้อมูล) ---
class IncomeHistory {
  final String date;
  final String time;
  final String groupName;
  final int income;
  final int total;
  IncomeHistory(this.date, this.time, this.groupName, this.income, this.total);
}

class WithdrawalHistory {
  final String date;
  final String time;
  final int amount;
  final String bank;
  final String status;
  WithdrawalHistory(this.date, this.time, this.amount, this.bank, this.status);
}

// --- Main Widget ---
class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

bool isHistory = false;
bool isHistoryFinance = false;

class _FinancePageState extends State<FinancePage> {
  @override
  Widget build(BuildContext context) {
    // ใช้ DefaultTabController ห่อ Scaffold เพื่อควบคุม Tab
    return DefaultTabController(
      length: 2, // จำนวน Tab
      child: Scaffold(
        appBar: AppBarSubMain(title: 'การเงิน', isBack: false),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              if (!isHistory && !isHistoryFinance)
                Column(
                  children: [
                    BalanceCardFinance(
                      balance: '1860 บาท',
                      incomeText: 'รายได้: 4000 บาท',
                      pendingText: 'รอชำระ: 1600 บาท',
                      onWithdrawPressed: () => _showWithdrawAmountSheet(),
                    ),
                    const SizedBox(height: 16),
                    IncomeChartCard(
                      title: 'รายละเอียด 5 เกมล่าสุด',
                      totalIncomeText: 'รายได้ 2,560 บาท',
                      chartData: [
                        ChartGroup(
                          name: 'ก๊วนแซมสเดย์',
                          playersValue: 42,
                          paidValue: 30,
                        ),
                        ChartGroup(
                          name: 'ก๊วนแมวเหมียว',
                          playersValue: 78,
                          paidValue: 52,
                        ),
                        ChartGroup(
                          name: 'ก๊วนหมาบ้า',
                          playersValue: 50,
                          paidValue: 38,
                        ),
                        ChartGroup(
                          name: 'ก๊วนช้าง',
                          playersValue: 65,
                          paidValue: 45,
                        ),
                        ChartGroup(
                          name: 'ก๊วนหมีง่วง',
                          playersValue: 42,
                          paidValue: 32,
                        ),
                      ],
                      onDetailsPressed: () {
                        print('Details button pressed!');
                        // Navigate to details page
                      },
                    ),
                    const SizedBox(height: 16),
                    HistoryCardFinance(
                      initialTimeRange: 'วันนี้',
                      timeRangeItems: [
                        'วันนี้',
                        'สัปดาห์นี้',
                        'เดือนนี้',
                        'ทั้งหมด',
                      ],
                      incomeHistory: [
                        HistoryItem(
                          date: '21/04/25',
                          time: '13:03 PM',
                          amount: '3000',
                          totalAmount: '4500',
                          groupName: 'ก๊วนแบดหรรษา',
                        ),
                        HistoryItem(
                          date: '21/04/25',
                          time: '13:03 PM',
                          amount: '3000',
                          totalAmount: '4500',
                          groupName: 'ก๊วนแบดหรรษา',
                        ),
                        HistoryItem(
                          date: '21/04/25',
                          time: '13:03 PM',
                          amount: '3000',
                          totalAmount: '4500',
                          groupName: 'ก๊วนแบดหรรษา',
                        ),
                        HistoryItem(
                          date: '21/04/25',
                          time: '13:03 PM',
                          amount: '3000',
                          totalAmount: '4500',
                          groupName: 'ก๊วนแบดหรรษา',
                        ),
                        HistoryItem(
                          date: '21/04/25',
                          time: '13:03 PM',
                          amount: '3000',
                          totalAmount: '4500',
                          groupName: 'ก๊วนแบดหรรษา',
                        ),
                      ],
                      withdrawalHistoryView: const Center(
                        child: Text('ประวัติเงินออกแสดงที่นี่'),
                      ),
                      onTimeRangeChanged: (value) {
                        print('Selected time range: $value');
                        // Fetch new data based on the selected time range
                      },
                      onIncomeItemAmountTap: (item) {
                        setState(() {
                          isHistoryFinance = true;
                        });
                      },
                      onIncomeItemGroupTap: (item) {
                        setState(() {
                          isHistory = true;
                        });
                      },
                    ),
                  ],
                ),
              if (isHistory)
                detailsViewHistory(
                  context,
                  onBack: () => setState(() {
                    isHistory = false;
                    isHistoryFinance = false;
                  }),
                ),
              if (isHistoryFinance)
                detailsViewHistoryFinance(
                  context,
                  onBack: () => setState(() {
                    isHistoryFinance = false;
                    isHistory = false;
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWithdrawAmountSheet() {
    final amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ถอนเงินจำนวน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ระบุจำนวนเงิน',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // ปิด Bottom Sheet
                  _showWithdrawConfirmationDialog(); // เปิด Dialog ยืนยัน
                },
                child: const Text('ถอนเงิน'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showWithdrawConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              _buildDialogRow('ถอนเงิน', '100 บาท'),
              _buildDialogRow('ค่าธรรมเนียม', '10 บาท'),
              const Divider(height: 24),
              _buildDialogRow('ราคารวม', '90 บาท', isBold: true),
              const SizedBox(height: 20),
              const Text('ยืนยันการถอนเงินไปที่'),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'เลขบัตรประชาชน *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                items: const [
                  DropdownMenuItem(value: 'Kbank', child: Text('Kbank')),
                ],
                onChanged: (v) {},
                decoration: const InputDecoration(
                  labelText: 'ธนาคาร *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Bookbank *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'รูป Bookbank *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: () {},
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('ยืนยันการถอนเงิน'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogRow(String title, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget detailsViewHistory(BuildContext context, {Function()? onBack}) {
    final bool isMobile = onBack != null;
    return Column(
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

  Widget detailsViewHistoryFinance(BuildContext context, {Function()? onBack}) {
    final bool isMobile = onBack != null;
    return Column(
      mainAxisSize: MainAxisSize.max,
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
        CostsSummary(),
        PlayerListCard(
          padding: EdgeInsetsGeometry.symmetric(vertical: 16),
          onPlayerTap: () {},
        ),
      ],
    );
  }
}

class BalanceCardFinance extends StatelessWidget {
  /// ตัวแปรสำหรับรับข้อมูลที่จะแสดงผล
  final String balance;
  final String incomeText;
  final String pendingText;
  final String title;
  final String buttonText;

  /// Callback function สำหรับจัดการการกดปุ่ม
  final VoidCallback onWithdrawPressed;

  const BalanceCardFinance({
    super.key,
    required this.balance,
    required this.incomeText,
    required this.pendingText,
    required this.onWithdrawPressed,
    this.title = 'เงินคงเหลือ', // กำหนดค่าเริ่มต้น
    this.buttonText = 'ถอนเงิน', // กำหนดค่าเริ่มต้น
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF666666)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Card(
        color: Colors.transparent, // ต้องเป็น transparent เพื่อโชว์ gradient
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, // ใช้ค่าจาก parameter
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, fontSize: 20),
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFB3B3C1),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        incomeText, // ใช้ค่าจาก parameter
                        style: TextStyle(
                          fontSize: getResponsiveFontSize(
                            context,
                            fontSize: 10,
                          ),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB3B3C1),
                        ),
                      ),
                      Text(
                        pendingText, // ใช้ค่าจาก parameter
                        style: TextStyle(
                          fontSize: getResponsiveFontSize(
                            context,
                            fontSize: 10,
                          ),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB3B3C1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              /// Balance Text
              Text(
                balance, // ใช้ค่าจาก parameter
                style: TextStyle(
                  color: Colors.white,
                  fontSize: getResponsiveFontSize(context, fontSize: 32),
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 24),

              /// Withdraw Button
              SizedBox(
                width: double.infinity,
                child: CustomElevatedButton(
                  text: buttonText, // ใช้ค่าจาก parameter
                  backgroundColor: const Color(0xFF0E9D7A),
                  onPressed:
                      onWithdrawPressed, // เรียกใช้ callback function ที่ส่งเข้ามา
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryItem {
  final String date;
  final String time;
  final String amount;
  final String totalAmount;
  final String groupName;
  // เพิ่ม ID หรือข้อมูลอื่นๆ ที่จำเป็นได้ที่นี่
  final dynamic originalData; //เผื่อต้องการข้อมูลดั้งเดิมทั้งหมด

  HistoryItem({
    required this.date,
    required this.time,
    required this.amount,
    required this.totalAmount,
    required this.groupName,
    this.originalData,
  });
}

class HistoryCardFinance extends StatefulWidget {
  // --- Parameters for data and configuration ---
  final String initialTimeRange;
  final List<String> timeRangeItems;
  final List<HistoryItem> incomeHistory;
  final Widget withdrawalHistoryView; // รับเป็น Widget มาเลยเพื่อความยืดหยุ่น

  // --- Callbacks for interactions ---
  final ValueChanged<String?> onTimeRangeChanged;
  final ValueChanged<HistoryItem> onIncomeItemAmountTap;
  final ValueChanged<HistoryItem> onIncomeItemGroupTap;

  const HistoryCardFinance({
    super.key,
    required this.initialTimeRange,
    required this.timeRangeItems,
    required this.incomeHistory,
    required this.withdrawalHistoryView,
    required this.onTimeRangeChanged,
    required this.onIncomeItemAmountTap,
    required this.onIncomeItemGroupTap,
  });

  @override
  State<HistoryCardFinance> createState() => _HistoryCardFinanceState();
}

class _HistoryCardFinanceState extends State<HistoryCardFinance> {
  late String _selectedFinance;

  @override
  void initState() {
    super.initState();
    _selectedFinance = widget.initialTimeRange;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomDropdown(
          labelText: 'ช่องเวลา',
          initialValue: _selectedFinance,
          items: widget.timeRangeItems,
          onChanged: (value) {
            setState(() {
              _selectedFinance = value!;
            });
            widget.onTimeRangeChanged(value); // แจ้งเตือน Parent Widget
          },
        ),
        const SizedBox(height: 20),
        DefaultTabController(
          length: 2,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // TabBar
                  TabBar(
                    tabs: const [
                      Tab(text: 'ประวัติเงินเข้า'),
                      Tab(text: 'ประวัติเงินออก'),
                    ],
                    labelColor: Colors.black,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: TextStyle(
                      // fontSize: getResponsiveFontSize(context, fontSize: 14),
                      fontSize:
                          14, // เปลี่ยนเป็นค่าคงที่ใน component หรือรับค่ามา
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // TabBarView
                  SizedBox(
                    height: 555, // อาจจะต้องปรับให้ยืดหยุ่นกว่านี้
                    child: TabBarView(
                      children: [
                        // Tab 1: Income History
                        _buildIncomeHistoryList(),
                        // Tab 2: Withdrawal History
                        widget.withdrawalHistoryView,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeHistoryList() {
    if (widget.incomeHistory.isEmpty) {
      return const Center(child: Text('ไม่มีข้อมูลประวัติเงินเข้า'));
    }
    return ListView.separated(
      itemCount: widget.incomeHistory.length,
      itemBuilder: (context, index) {
        final item = widget.incomeHistory[index];
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(
              '${item.date} ${item.time}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5E5E5E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            InkWell(
              onTap: () => widget.onIncomeItemAmountTap(item), // ใช้ callback
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: item.amount,
                      style: const TextStyle(
                        color: Color(0XFF0E9D7A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: '/${item.totalAmount}',
                      style: const TextStyle(
                        color: Color(0xFF5E5E5E),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: () => widget.onIncomeItemGroupTap(item), // ใช้ callback
              child: Text(
                item.groupName,
                style: const TextStyle(
                  color: Color(0xFF5E5E5E),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
      separatorBuilder: (context, index) => const Divider(),
    );
  }
}

class ChartGroup {
  final String name;
  final double playersValue;
  final double paidValue;

  ChartGroup({
    required this.name,
    required this.playersValue,
    required this.paidValue,
  });
}

class IncomeChartCard extends StatelessWidget {
  // --- Parameters for data and configuration ---
  final String title;
  final String totalIncomeText;
  final List<ChartGroup> chartData;
  final VoidCallback onDetailsPressed;

  // --- Configuration for chart appearance ---
  final Color playersColor;
  final String playersLegend;
  final Color paidColor;
  final String paidLegend;

  const IncomeChartCard({
    super.key,
    required this.title,
    required this.totalIncomeText,
    required this.chartData,
    required this.onDetailsPressed,
    this.playersColor = const Color(0xFF1E3A8A), // Blue
    this.playersLegend = 'คนเล่น',
    this.paidColor = const Color(0xFF0E9D7A), // Green
    this.paidLegend = 'จ่ายแล้ว',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF393941),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              totalIncomeText,
              style: const TextStyle(
                color: Color(0xFF393941),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            _buildLegend(),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.7,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: _generateBarGroups(),
                  titlesData: _buildTitlesData(),
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: true),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onDetailsPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Details'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper methods moved inside the component ---

  List<BarChartGroupData> _generateBarGroups() {
    return List.generate(chartData.length, (index) {
      final group = chartData[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: group.playersValue,
            color: playersColor,
            width: 12,
            borderRadius: BorderRadius.zero,
          ),
          BarChartRodData(
            toY: group.paidValue,
            color: paidColor,
            width: 12,
            borderRadius: BorderRadius.zero,
          ),
        ],
      );
    });
  }

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      leftTitles: const AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 40,
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (value, meta) {
            if (value.toInt() >= chartData.length) return const SizedBox();
            return SideTitleWidget(
              meta: meta,
              space: 4,
              child: Text(
                chartData[value.toInt()].name,
                style: const TextStyle(fontSize: 10),
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(playersColor, playersLegend),
        const SizedBox(width: 24),
        _legendItem(paidColor, paidLegend),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
