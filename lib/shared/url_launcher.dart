import 'package:url_launcher/url_launcher.dart';

class UrlLauncherService {
  // ฟังก์ชันสำหรับโทรออก
  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $phoneNumber';
    }
  }

  // ฟังก์ชันสำหรับเปิด Facebook
  // facebookId คือ ID ของโปรไฟล์หรือเพจ
  // fallbackUrl คือ URL ที่จะเปิดในเบราว์เซอร์ถ้าไม่มีแอป
  static Future<void> launchFacebook(String profileUrl) async {
    final Uri launchUri = Uri.parse(profileUrl);
    // url_launcher จะพยายามเปิดในแอป Facebook ก่อนถ้าติดตั้งไว้
    // ถ้าไม่สำเร็จ จะเปิดในเบราว์เซอร์โดยอัตโนมัติ
    if (await canLaunchUrl(launchUri)) {
      // ตั้งค่า mode เป็น externalApplication เพื่อให้แน่ใจว่าเปิดนอกแอป
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $profileUrl';
    }
  }

  // ฟังก์ชันสำหรับเปิด LINE
  static Future<void> launchLine(String lineId) async {
    final String deepLink =
        'line://ti/p/@$lineId'; // Deep link for LINE Official Account or user
    final Uri launchUri = Uri.parse(deepLink);
    final Uri fallbackUri = Uri.parse('https://line.me/R/ti/p/@$lineId');

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      // ถ้าเปิดแอปไม่ได้ ให้เปิดในเบราว์เซอร์แทน
      await launchUrl(fallbackUri);
    }
  }

  static Future<void> openMapByQuery(String query) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }

  /// เปิด Google Maps เพื่อปักหมุดที่ Latitude และ Longitude ที่กำหนด
  static Future<void> openMapByLatLng(double latitude, double longitude) async {
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }
}
