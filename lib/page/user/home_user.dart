import 'dart:async';
import 'dart:ui';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/game_card.dart';
import 'package:badminton/component/skeleton.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:badminton/shared/route_observer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:badminton/shared/user_role.dart';

class HomeUserPage extends StatefulWidget {
  const HomeUserPage({super.key});

  @override
  HomeUserPageState createState() => HomeUserPageState();
}

class HomeUserPageState extends State<HomeUserPage>
    with WidgetsBindingObserver, RouteAware {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchDashboardData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // กลับมาที่หน้านี้จากการ pop หน้าอื่น → refresh data
    _fetchDashboardData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // refresh เมื่อ app กลับมา foreground
    if (state == AppLifecycleState.resumed) {
      _fetchDashboardData();
    }
  }

  Future<void> _fetchDashboardData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return; // ข้ามการดึงข้อมูลสำหรับ Guest
    }
    try {
      final response = await ApiProvider().get('/player/dashboard');
      if (mounted) {
        setState(() {
          _dashboardData = response['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ดึงข้อมูลผิดพลาด: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatPlayTime(int totalMinutes) {
    if (totalMinutes < 60) return '$totalMinutes นาที';
    int hours = totalMinutes ~/ 60;
    int mins = totalMinutes % 60;
    return mins > 0 ? '$hours ชม. $mins น.' : '$hours ชม.';
  }

  @override
  Widget build(BuildContext context) {
    // สอดคล้องกับ gradient ใน menu_bar (ผู้เล่น)
    const playerHomeGradient = LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBarHome(),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: playerHomeGradient),
        child: _isLoading
            ? const HomeDashboardSkeleton()
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: ListView(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    left: 20,
                    right: 20,
                    bottom: 120, // เผื่อระยะให้ MenuBar ด้านล่าง
                  ),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('สถิติการเล่นของคุณ'),
                    const SizedBox(height: 15),
                    _buildStatsGrid(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('แมตช์ต่อไปของคุณ'),
                    const SizedBox(height: 15),
                    _buildNextGameCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      return Row(
        children: [
          const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            backgroundImage: AssetImage('assets/icon/profile.png'),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สวัสดี, ผู้เยี่ยมชม 🏸',
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(context, fontSize: 22),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () => context.push('/login'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'เข้าสู่ระบบ / สมัครสมาชิก',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final profile = _dashboardData?['profile'] ?? {};
    final nickname = profile['nickname'] ?? 'ผู้เล่น';
    final photoUrl = profile['profilePhotoUrl'];
    final skillLevel = profile['latestSkillLevelName'] ?? 'ยังไม่มีข้อมูลระดับมือ';

    return Row(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: Colors.white,
          backgroundImage: photoUrl != null && photoUrl.isNotEmpty
              ? NetworkImage(photoUrl)
              : const AssetImage('assets/icon/profile.png') as ImageProvider,
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สวัสดี, $nickname 🏸',
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 22),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  skillLevel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4A4A4A),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = _dashboardData?['stats'] ?? {};
    final NumberFormat currencyFormat = NumberFormat('#,##0');

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      shrinkWrap: true, // สำคัญมากเมื่อใช้ใน ListView
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      children: [
        _buildStatCard(
          title: 'แมตช์ที่เล่น',
          value: '${stats['totalMatches'] ?? 0} เกม',
          icon: Icons.sports_tennis,
          color: Colors.blue,
        ),
        _buildStatCard(
          title: 'เกมที่ชนะ',
          value: '${stats['totalWins'] ?? 0} เกม',
          icon: Icons.emoji_events,
          color: Colors.orange,
        ),
        _buildStatCard(
          title: 'ค้างชำระ',
          value: '฿${currencyFormat.format(stats['unpaidBalance'] ?? 0)}',
          icon: Icons.warning_amber_rounded,
          color: Colors.redAccent,
        ),
        _buildStatCard(
          title: 'กระเป๋าเงิน (Wallet)',
          value: '฿${currencyFormat.format(stats['walletBalance'] ?? 0)}',
          icon: Icons.account_balance_wallet,
          color: Colors.green,
        ),
        _buildStatCard(
          title: 'เวลาบนคอร์ท',
          value: _formatPlayTime(stats['totalPlayTimeMinutes'] ?? 0),
          icon: Icons.timer,
          color: Colors.purple,
        ),
        _buildStatCard(
          title: 'ยอดใช้จ่ายรวม',
          value: '฿${currencyFormat.format(stats['totalSpent'] ?? 0)}',
          icon: Icons.payments_outlined,
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55), // โปร่งแสง
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5), // ขอบขาวให้ดูเป็นกระจก
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // เอฟเฟกต์เบลอพื้นหลัง
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextGameCard() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(Icons.lock_outline, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'สมัครสมาชิกหรือเข้าสู่ระบบ\nเพื่อจองก๊วนและดูคิวตีแบดของคุณ',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF666666), fontSize: 16),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () => context.push('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('เข้าสู่ระบบ / สมัครสมาชิก', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      );
    }

    final nextGame = _dashboardData?['nextUpcomingSession'];

    if (nextGame == null) {
      // กรณีไม่มีก๊วนที่จองไว้
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'คุณยังไม่มีคิวตีแบดเร็วๆ นี้\nไปหาก๊วนสนุกๆ กันเลย!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF666666), fontSize: 16),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () => context.go('/search-user'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('ค้นหาก๊วน', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      );
    }

    // กรณีมีก๊วนที่กำลังจะถึง
    final formattedDateTime = formatSessionStart(
      nextGame['sessionStart'] ?? DateTime.now().toIso8601String(),
    );

    return GameCard(
      teamName: nextGame['groupName'] ?? 'N/A',
      imageUrl: nextGame['imageUrl'] ?? 'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
      day: formattedDateTime['day'] ?? 'Mon',
      date: '${nextGame['dayOfWeek']} ${nextGame['sessionDate']}'.trim(),
      time: '${nextGame['startTime']}-${nextGame['endTime']}',
      courtName: nextGame['courtName'] ?? 'N/A',
      location: nextGame['location'] ?? '-',
      price: nextGame['price'] ?? '-',
      shuttlecockInfo: nextGame['shuttlecockModelName'] ?? '-',
      shuttlecockBrand: nextGame['shuttlecockBrandName'] ?? '-',
      gameInfo: nextGame['gameTypeName'] ?? '-',
      currentPlayers: nextGame['currentParticipants'] ?? 0,
      maxPlayers: nextGame['maxParticipants'] ?? 0,
      organizerName: nextGame['organizerName'] ?? 'N/A',
      organizerImageUrl: nextGame['organizerImageUrl'] ?? 'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
      isInitiallyBookmarked: nextGame['isBookmarked'] ?? false,
      onCardTap: () => context.push('/game-player/${nextGame['sessionId']}'),
      onTapPlayers: () => context.push('/player-list/${nextGame['sessionId']}'),
    );
  }
}
