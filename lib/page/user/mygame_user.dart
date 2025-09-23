import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/game_card2.dart';
import 'package:badminton/page/user/booking_confirm.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MyGameUserPage extends StatefulWidget {
  const MyGameUserPage({super.key});

  @override
  MyGameUserPageState createState() => MyGameUserPageState();
}

class MyGameUserPageState extends State<MyGameUserPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'เกมส์ของฉัน', isBack: false),
      body: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFCBF5EA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          children: [
            _buildPlaying(context, title: 'กำลังเล่น', index: 0),
            _buildPlaying(context, title: 'ก๊วนที่กำลังมาถึง', index: 1),
            _buildPlaying(context, title: 'รอคืนเงิน', index: 2),
          ],
        ),
      ),
    );
  }

  _buildPlaying(BuildContext context, {String title = '', int index = 0}) {
    final game = dataList[index];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: getResponsiveFontSize(context, fontSize: 20),
              ),
            ),
            Text(
              'ดูเพิ่มเติม',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                color: Color(0xFF393941),
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: GameCard2(
            teamName: game['teamName'],
            imageUrl: game['imageUrl'],
            day: game['day'],
            date: game['date'],
            time: game['time'],
            courtName: game['courtName'],
            location: game['location'],
            price: game['price'],
            shuttlecockInfo: game['shuttlecockInfo'],
            gameInfo: game['gameInfo'],
            currentPlayers: game['currentPlayers'],
            maxPlayers: game['maxPlayers'],
            organizerName: game['organizerName'],
            organizerImageUrl: game['organizerImageUrl'],
            isInitiallyBookmarked: game['isInitiallyBookmarked'],
            onCardTap: () {
              final bookingDetails = BookingDetails(
                code: '1',
                teamName: game['teamName'],
                imageUrl: game['imageUrl'],
                day: game['day'],
                date: game['date'],
                time: game['time'],
                courtName: game['courtName'],
                location: game['location'],
                price: game['price'],
                shuttlecockInfo: game['shuttlecockInfo'],
                gameInfo: game['gameInfo'],
                currentPlayers: game['currentPlayers'],
                maxPlayers: game['maxPlayers'],
                organizerName: game['organizerName'],
                organizerImageUrl: game['organizerImageUrl'],
                address: '123/456 สนามแบดมินตัน ABC, กรุงเทพ 10240',
                courtImageUrls: [
                  'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
                  'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
                  'https://gateway.we-builds.com/wb-document/images/banner/banner_251851442.png',
                  'https://gateway.we-builds.com/wb-document/images/banner/banner_251839026.png',
                ],
                status: 'W',
              );
              context.push('/booking-confirm-game', extra: bookingDetails);
            },
            onTapOrganizer: () => showUserProfileDialog(context),
            onTapPlayers: () =>
                context.push('/player-list/${game['teamName']}'),
          ),
        ),
      ],
    );
  }
}
