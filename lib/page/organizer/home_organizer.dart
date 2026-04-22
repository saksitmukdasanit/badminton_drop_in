import 'dart:ui';
import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/loading_image_network.dart';
import 'package:badminton/component/game_card.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomeOrganizerPage extends StatefulWidget {
  const HomeOrganizerPage({super.key});

  @override
  State<HomeOrganizerPage> createState() => _HomeOrganizerPageState();
}

class _HomeOrganizerPageState extends State<HomeOrganizerPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final response = await ApiProvider().get('/organizer/dashboard');
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
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // ทะลุใต้ MenuBar
      appBar: const AppBarHome(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0)], // ธีมฝั่งผู้จัด (ดูทางการและสะอาด)
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: ListView(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    left: 20,
                    right: 20,
                    bottom: 120, // เผื่อระยะ MenuBar
                  ),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('ภาพรวมการจัดก๊วน'),
                    const SizedBox(height: 15),
                    _buildStatsGrid(),
                    const SizedBox(height: 30),
                    _buildSectionTitle('ก๊วนที่กำลังจะถึง'),
                    const SizedBox(height: 15),
                    _buildNextGameCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final profile = _dashboardData?['profile'] ?? {};
    final nickname = profile['nickname'] ?? 'ผู้จัด';
    final photoUrl = profile['profilePhotoUrl'];
    final status = profile['status'] ?? 0;

    String statusText = 'รอดำเนินการ';
    Color statusColor = Colors.orange;
    if (status == 1) {
      statusText = 'อนุมัติแล้ว (Verified)';
      statusColor = Colors.green;
    } else if (status == 2) {
      statusText = 'ไม่อนุมัติ';
      statusColor = Colors.red;
    } else if (status == 3) {
      statusText = 'ระงับการใช้งาน';
      statusColor = Colors.grey;
    }

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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
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
    final screenWidth = MediaQuery.of(context).size.width;

    // ปรับเปลี่ยนจำนวนคอลัมน์และสัดส่วนให้รองรับ iPad
    int crossAxisCount = 2;
    double childAspectRatio = 1.25;
    if (screenWidth > 800) {
      crossAxisCount = 4;
      childAspectRatio = 1.4;
    } else if (screenWidth > 600) {
      crossAxisCount = 4;
      childAspectRatio = 1.1;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatCard(
          title: 'จัดก๊วนแล้ว',
          value: '${stats['totalSessionsHosted'] ?? 0} ครั้ง',
          icon: Icons.stadium_outlined,
          color: Colors.blue,
        ),
        _buildStatCard(
          title: 'ผู้เข้าร่วมทั้งหมด',
          value: '${stats['totalPlayersJoined'] ?? 0} คน',
          icon: Icons.groups_outlined,
          color: Colors.orange,
        ),
        _buildStatCard(
          title: 'ผู้ติดตามคุณ',
          value: '${stats['followersCount'] ?? 0} คน',
          icon: Icons.star_border,
          color: Colors.purple,
        ),
        _buildStatCard(
          title: 'รายได้สุทธิ',
          value: '฿${currencyFormat.format(stats['totalNetIncome'] ?? 0)}',
          icon: Icons.payments_outlined,
          color: Colors.green,
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
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
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
    final nextGame = _dashboardData?['nextUpcomingSession'];
    final profileStatus = _dashboardData?['profile']?['status'] ?? 0;

    if (profileStatus == 0) {
      return _buildEmptyStateCard(
        icon: Icons.hourglass_empty_rounded,
        message: 'บัญชีผู้จัดของคุณอยู่ระหว่างการตรวจสอบ\nกรุณารอการอนุมัติเพื่อเริ่มสร้างก๊วน',
        buttonText: null,
      );
    }

    if (nextGame == null) {
      return _buildEmptyStateCard(
        icon: Icons.event_available,
        message: 'คุณยังไม่มีก๊วนที่กำลังจะเปิดเร็วๆ นี้\nมาสร้างก๊วนใหม่กันเลย!',
        buttonText: 'สร้างก๊วนใหม่',
        onButtonPressed: () => context.go('/new-game'),
      );
    }

    final formattedDateTime = formatSessionStart(
      nextGame['sessionStart'] ?? DateTime.now().toIso8601String(),
    );
    final int sessionId = nextGame['sessionId'];
    final int status = nextGame['status'] ?? 1;

    return GameCard(
      teamName: nextGame['groupName'] ?? 'ไม่ระบุชื่อก๊วน',
      imageUrl: nextGame['imageUrl'] ?? 'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
      day: formattedDateTime['day'] ?? 'Mon',
      date: '${nextGame['dayOfWeek']} ${nextGame['sessionDate']}'.trim(),
      time: '${nextGame['startTime']}-${nextGame['endTime']}',
      courtName: nextGame['courtName'] ?? 'ไม่ระบุสนาม',
      location: nextGame['location'] ?? '-',
      price: 'สนาม ${nextGame['courtFeePerPerson'] ?? nextGame['courtFee'] ?? '-'} บ.\nลูก ${(nextGame['costingMethod'] == 2) ? 'เหมาจ่าย' : '${nextGame['shuttlecockFeePerPerson'] ?? nextGame['shuttlecockFee'] ?? '-'} บ.'}',
      shuttlecockInfo: nextGame['shuttlecockModelName'] ?? '-',
      shuttlecockBrand: nextGame['shuttlecockBrandName'] ?? '-',
      gameInfo: nextGame['gameTypeName'] ?? '-',
      currentPlayers: nextGame['currentParticipants'] ?? 0,
      maxPlayers: nextGame['maxParticipants'] ?? 0,
      organizerName: nextGame['organizerName'] ?? 'N/A',
      organizerImageUrl: nextGame['organizerImageUrl'] ?? 'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
      isInitiallyBookmarked: nextGame['isBookmarked'] ?? false,
      onCardTap: () {
        if (status == 2) {
          context.push('/manage-game/$sessionId');
        } else {
          showDialogMsg(
            context,
            title: 'แจ้งเตือน',
            subtitle: 'ก๊วนยังไม่เริ่มการแข่งขัน\nกรุณาไปที่เมนู "จัดการ" เพื่อเปิดก๊วนก่อน',
            btnLeft: 'ตกลง',
            onConfirm: () {},
          );
        }
      },
      onTapPlayers: () => context.push('/player-list/$sessionId'),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String message,
    required String? buttonText,
    VoidCallback? onButtonPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 50, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF666666), fontSize: 16),
          ),
          if (buttonText != null) ...[
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(buttonText, style: const TextStyle(color: Colors.white)),
            )
          ]
        ],
      ),
    );
  }
}
