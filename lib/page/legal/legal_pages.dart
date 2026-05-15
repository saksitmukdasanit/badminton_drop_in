import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/loading_image_network.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// **TODO ก่อนปล่อย Store**: ข้อความใน Privacy Policy / Terms ด้านล่างเป็น TEMPLATE
/// ทีมงานต้องตรวจกับ legal team และอัปเดตให้สอดคล้องกับการดำเนินงานจริง
/// (โดยเฉพาะ: ผู้ควบคุมข้อมูล, สิทธิ์ตาม PDPA, ระยะเวลาเก็บข้อมูล, นโยบายคืนเงิน)

const String _kSupportEmail = 'support@dropinbad.com';
const String _kAppVersion = '1.0.0';
const String _kCompanyName = 'Drop In Bad';
const String _kEffectiveDate = '6 พฤษภาคม 2569';

class _CmsLegalContent {
  final String appLogoUrl;
  final String appName;
  final String appVersion;
  final String supportEmail;
  final String description;
  final String privacyPolicy;
  final String termsAndConditions;
  final String policyUrl;
  final String termsUrl;
  final DateTime? contentUpdatedAtUtc;

  const _CmsLegalContent({
    required this.appLogoUrl,
    required this.appName,
    required this.appVersion,
    required this.supportEmail,
    required this.description,
    required this.privacyPolicy,
    required this.termsAndConditions,
    required this.policyUrl,
    required this.termsUrl,
    this.contentUpdatedAtUtc,
  });

  static Future<_CmsLegalContent> fetch() async {
    final res = await ApiProvider().get('/public/app-content/profile-about');
    final data = (res is Map && res['data'] is Map) ? (res['data'] as Map) : const {};
    final rawUpdated = data['updatedAtUtc'] ?? data['UpdatedAtUtc'];
    DateTime? updated;
    if (rawUpdated != null) {
      updated = DateTime.tryParse(rawUpdated.toString());
    }
    return _CmsLegalContent(
      appLogoUrl: (data['appLogoUrl'] ?? data['AppLogoUrl'] ?? '').toString().trim(),
      appName: (data['appName'] ?? data['AppName'] ?? '').toString(),
      appVersion: (data['appVersion'] ?? data['AppVersion'] ?? '').toString(),
      supportEmail: (data['supportEmail'] ?? data['SupportEmail'] ?? '').toString(),
      description: (data['description'] ?? data['Description'] ?? '').toString(),
      privacyPolicy: (data['privacyPolicy'] ?? data['PrivacyPolicy'] ?? '').toString(),
      termsAndConditions: (data['termsAndConditions'] ?? data['TermsAndConditions'] ?? '').toString(),
      policyUrl: (data['policyUrl'] ?? data['PolicyUrl'] ?? '').toString().trim(),
      termsUrl: (data['termsUrl'] ?? data['TermsUrl'] ?? '').toString().trim(),
      contentUpdatedAtUtc: updated,
    );
  }
}

Future<bool> _tryOpenExternalUrl(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  try {
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
  return false;
}

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  late Future<_CmsLegalContent> _future;

  @override
  void initState() {
    super.initState();
    _future = _CmsLegalContent.fetch();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CmsLegalContent>(
      future: _future,
      builder: (context, snapshot) {
        final cms = snapshot.data;
        final supportEmail = (cms?.supportEmail.isNotEmpty ?? false) ? cms!.supportEmail : _kSupportEmail;
        final remoteBody = cms?.privacyPolicy ?? '';
        final sections = remoteBody.isNotEmpty
            ? [_LegalSection(heading: 'นโยบายความเป็นส่วนตัว', body: remoteBody)]
            : [
        _LegalSection(
          heading: '1. ข้อมูลที่เราเก็บ',
          body:
              '$_kCompanyName เก็บข้อมูลส่วนบุคคลของคุณดังนี้: ชื่อ-สกุล, ชื่อเล่น, เบอร์โทรศัพท์, อีเมล, รูปโปรไฟล์, '
              'เบอร์ติดต่อฉุกเฉิน, ข้อมูลบัญชีธนาคาร (สำหรับการถอนเงิน), ระดับฝีมือแบดมินตัน, '
              'ประวัติการจอง/เข้าร่วมก๊วน, และข้อมูลตำแหน่งโดยประมาณ (เพื่อค้นหาก๊วนใกล้คุณ).',
        ),
        _LegalSection(
          heading: '2. วัตถุประสงค์ของการเก็บข้อมูล',
          body:
              'เราใช้ข้อมูลของคุณเพื่อ: ดำเนินการลงทะเบียนและยืนยันตัวตน, ประมวลผลการจองและชำระเงิน, '
              'แจ้งเตือนเกี่ยวกับก๊วน/การชำระเงิน, แสดงข้อมูลให้ผู้จัดและผู้เล่นคนอื่นเท่าที่จำเป็น, '
              'และปรับปรุงคุณภาพการให้บริการ.',
        ),
        _LegalSection(
          heading: '3. การเปิดเผยข้อมูลกับบุคคลภายนอก',
          body:
              'เราอาจเปิดเผยข้อมูลให้ผู้ให้บริการที่เกี่ยวข้อง: Xendit (ระบบชำระเงิน), Firebase (Push Notification), '
              'Google Maps (ค้นหาสถานที่), SMSMKT (ส่ง OTP). บุคคลเหล่านี้เข้าถึงข้อมูลเฉพาะที่จำเป็นต่อการให้บริการเท่านั้น '
              'และผูกพันตามนโยบายความเป็นส่วนตัวของตน.',
        ),
        _LegalSection(
          heading: '4. ระยะเวลาเก็บข้อมูล',
          body:
              'เราเก็บข้อมูลของคุณตราบเท่าที่บัญชียังเปิดใช้งานอยู่. หากคุณลบบัญชี ข้อมูลจะถูกลบหรือลบล้างใน 30 วัน '
              'ยกเว้นข้อมูลที่ต้องเก็บตามกฎหมาย (เช่น ใบเสร็จการชำระเงิน) จะเก็บไว้ตามระยะเวลาที่กฎหมายกำหนด.',
        ),
        _LegalSection(
          heading: '5. สิทธิ์ของคุณ (ตาม PDPA)',
          body:
              'คุณมีสิทธิ์ขอเข้าถึง, แก้ไข, ลบ, หรือคัดลอกข้อมูลของคุณ. สามารถลบบัญชีและข้อมูลทั้งหมดได้จาก '
              'เมนู โปรไฟล์ → ลบบัญชี. หากต้องการความช่วยเหลือเพิ่มเติม กรุณาติดต่อ $_kSupportEmail',
        ),
        _LegalSection(
          heading: '6. ความปลอดภัย',
          body:
              'เราใช้การเข้ารหัสข้อมูลที่ละเอียดอ่อน (รหัสผ่านเก็บด้วย BCrypt, การส่งข้อมูลผ่าน HTTPS) '
              'อย่างไรก็ตาม ไม่มีระบบใดที่ปลอดภัย 100% หากเกิดการรั่วไหลของข้อมูลที่ส่งผลกระทบต่อคุณ '
              'เราจะแจ้งให้ทราบโดยเร็วที่สุด.',
        ),
        _LegalSection(
          heading: '7. การติดต่อเรา',
          body: 'หากมีข้อสงสัยเกี่ยวกับนโยบายนี้ กรุณาติดต่อ:\nอีเมล: $supportEmail',
        ),
      ];
        return _LegalScaffold(
          title: 'นโยบายความเป็นส่วนตัว',
          sections: sections,
        );
      },
    );
  }
}

class TermsOfServicePage extends StatefulWidget {
  const TermsOfServicePage({super.key});

  @override
  State<TermsOfServicePage> createState() => _TermsOfServicePageState();
}

class _TermsOfServicePageState extends State<TermsOfServicePage> {
  late Future<_CmsLegalContent> _future;

  @override
  void initState() {
    super.initState();
    _future = _CmsLegalContent.fetch();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CmsLegalContent>(
      future: _future,
      builder: (context, snapshot) {
        final cms = snapshot.data;
        final supportEmail = (cms?.supportEmail.isNotEmpty ?? false) ? cms!.supportEmail : _kSupportEmail;
        final remoteBody = cms?.termsAndConditions ?? '';
        final sections = remoteBody.isNotEmpty
            ? [_LegalSection(heading: 'ข้อกำหนดและเงื่อนไขการใช้งาน', body: remoteBody)]
            : [
        _LegalSection(
          heading: '1. การยอมรับข้อกำหนด',
          body:
              'การใช้งานแอปพลิเคชัน $_kCompanyName หมายถึงคุณยอมรับและตกลงปฏิบัติตามข้อกำหนดนี้. '
              'หากไม่ยอมรับ กรุณาหยุดใช้งานแอปพลิเคชัน.',
        ),
        _LegalSection(
          heading: '2. คุณสมบัติของผู้ใช้',
          body:
              'ผู้ใช้ต้องมีอายุไม่ต่ำกว่า 13 ปี (หรือได้รับความยินยอมจากผู้ปกครอง) และมีเบอร์โทรศัพท์ที่ใช้งานได้จริง.',
        ),
        _LegalSection(
          heading: '3. บทบาทของผู้จัด (Organizer)',
          body:
              'ผู้จัดมีหน้าที่: จัดเตรียมสนาม, รับชำระเงิน, จัดคู่ผู้เล่น, และดูแลความปลอดภัยภายในก๊วน. '
              'ผู้จัดต้องไม่จัดก๊วนที่ผิดกฎหมาย และต้องคืนเงินตามนโยบายเมื่อยกเลิกก๊วน.',
        ),
        _LegalSection(
          heading: '4. บทบาทของผู้เล่น (Player)',
          body:
              'ผู้เล่นต้องมาตรงเวลา, ปฏิบัติตามกฎของสนาม, ชำระเงินตามจริง, และไม่ก่อกวนผู้อื่น. '
              'หากเจอพฤติกรรมไม่เหมาะสม สามารถรายงานได้จากปุ่ม "รายงาน" ในโปรไฟล์ผู้ใช้.',
        ),
        _LegalSection(
          heading: '5. การชำระเงินและคืนเงิน',
          body:
              'การจองที่ชำระเงินผ่าน Wallet หรือ QR Code มีค่าธรรมเนียมบริการ 10 บาทต่อรายการ. '
              'หากผู้จัดยกเลิกก๊วน เราจะคืนเงินเต็มจำนวน (รวมค่าธรรมเนียม) ภายใน 7 วันทำการ. '
              'หากผู้เล่นยกเลิกการจองเอง การคืนเงินขึ้นอยู่กับนโยบายของผู้จัดแต่ละราย.',
        ),
        _LegalSection(
          heading: '6. พฤติกรรมที่ต้องห้าม',
          body:
              '- ใช้แอปเพื่อกิจกรรมที่ผิดกฎหมาย\n'
              '- คุกคาม ข่มขู่ หรือเลือกปฏิบัติต่อผู้อื่น\n'
              '- ปลอมแปลงตัวตน หรือใช้บัญชีของผู้อื่น\n'
              '- พยายามเข้าถึงระบบโดยไม่ได้รับอนุญาต\n'
              'การละเมิดอาจส่งผลให้บัญชีถูกระงับโดยไม่ต้องแจ้งล่วงหน้า.',
        ),
        _LegalSection(
          heading: '7. ทรัพย์สินทางปัญญา',
          body:
              'แอป, โลโก้, การออกแบบ, และเนื้อหาทั้งหมดเป็นทรัพย์สินของ $_kCompanyName. '
              'ห้ามคัดลอก แจกจ่าย หรือดัดแปลงโดยไม่ได้รับอนุญาตเป็นลายลักษณ์อักษร.',
        ),
        _LegalSection(
          heading: '8. ข้อจำกัดความรับผิด',
          body:
              '$_kCompanyName ทำหน้าที่เป็นผู้ให้บริการแพลตฟอร์มเชื่อมระหว่างผู้จัดและผู้เล่นเท่านั้น. '
              'เราไม่รับผิดชอบต่อความเสียหาย หรืออุบัติเหตุที่เกิดขึ้นภายในก๊วน. '
              'ผู้ใช้ต้องดูแลตัวเองและทำประกันภัยตามดุลยพินิจ.',
        ),
        _LegalSection(
          heading: '9. การเปลี่ยนแปลงข้อกำหนด',
          body:
              'เราอาจปรับปรุงข้อกำหนดนี้ตามความเหมาะสม หากมีการเปลี่ยนแปลงสำคัญ '
              'เราจะแจ้งผู้ใช้ผ่านแอปอย่างน้อย 7 วันก่อนมีผลบังคับใช้.',
        ),
        _LegalSection(
          heading: '10. การติดต่อ',
          body: 'หากมีข้อสงสัยหรือข้อพิพาท กรุณาติดต่อ:\nอีเมล: $supportEmail',
        ),
      ];
        return _LegalScaffold(
          title: 'ข้อกำหนดและเงื่อนไขการใช้งาน',
          sections: sections,
        );
      },
    );
  }
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late Future<_CmsLegalContent> _future;

  @override
  void initState() {
    super.initState();
    _future = _CmsLegalContent.fetch();
  }

  String _shortUpdatedLabel(DateTime? utc) {
    if (utc == null) return '';
    final l = utc.toLocal();
    final d = l.day.toString().padLeft(2, '0');
    final m = l.month.toString().padLeft(2, '0');
    final h = l.hour.toString().padLeft(2, '0');
    final min = l.minute.toString().padLeft(2, '0');
    return '$d/$m/${l.year} $h:$min';
  }

  Future<void> _openPrivacy(BuildContext context, _CmsLegalContent cms) async {
    if (cms.policyUrl.isNotEmpty) {
      final ok = await _tryOpenExternalUrl(cms.policyUrl);
      if (ok && context.mounted) return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
    );
  }

  Future<void> _openTerms(BuildContext context, _CmsLegalContent cms) async {
    if (cms.termsUrl.isNotEmpty) {
      final ok = await _tryOpenExternalUrl(cms.termsUrl);
      if (ok && context.mounted) return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
    );
  }

  Widget _buildLogoHeader(String logoUrl) {
    const size = 96.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.indigo.shade100),
        ),
        clipBehavior: Clip.antiAlias,
        child: logoUrl.isNotEmpty
            ? LoadingImageNetwork(
                logoUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : Icon(
                Icons.sports_tennis,
                size: 52,
                color: Colors.indigo.shade400,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CmsLegalContent>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: const AppBarSubMain(
              title: 'เกี่ยวกับ',
              isBack: true,
              showSettings: false,
              showNotification: false,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: const AppBarSubMain(
              title: 'เกี่ยวกับ',
              isBack: true,
              showSettings: false,
              showNotification: false,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('โหลดข้อมูลไม่สำเร็จ', style: TextStyle(color: Colors.grey[800])),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() => _future = _CmsLegalContent.fetch()),
                      child: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final cms = snapshot.data!;
        final appName = cms.appName.isNotEmpty ? cms.appName : _kCompanyName;
        final appVersion = cms.appVersion.isNotEmpty ? cms.appVersion : _kAppVersion;
        final supportEmail = cms.supportEmail.isNotEmpty ? cms.supportEmail : _kSupportEmail;
        final description = cms.description;
        final logoUrl = cms.appLogoUrl;
        final updatedLabel = _shortUpdatedLabel(cms.contentUpdatedAtUtc);

        return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppBarSubMain(
        title: 'เกี่ยวกับ',
        isBack: true,
        showSettings: false,
        showNotification: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildLogoHeader(logoUrl),
            const SizedBox(height: 16),
            Center(
              child: Text(
                appName,
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, fontSize: 22),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Center(
              child: Text(
                'เวอร์ชัน $appVersion',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            if (updatedLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'อัปเดตเนื้อหาเมื่อ: $updatedLabel',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                description,
                style: TextStyle(color: Colors.grey[800], height: 1.45, fontSize: 15),
              ),
            ],
            const SizedBox(height: 28),
            _buildRow(Icons.email_outlined, 'อีเมลฝ่ายสนับสนุน', supportEmail, () {
              launchUrl(Uri.parse('mailto:$supportEmail'));
            }),
            const Divider(),
            _buildRow(Icons.privacy_tip_outlined, 'นโยบายความเป็นส่วนตัว',
                cms.policyUrl.isNotEmpty ? cms.policyUrl : null, () => _openPrivacy(context, cms)),
            const Divider(),
            _buildRow(Icons.description_outlined, 'ข้อกำหนดและเงื่อนไข',
                cms.termsUrl.isNotEmpty ? cms.termsUrl : null, () => _openTerms(context, cms)),
            const SizedBox(height: 32),
            Center(
              child: Text(
                '© ${DateTime.now().year} $appName. All rights reserved.',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildRow(
    IconData icon,
    String title,
    String? trailing,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.indigo),
      title: Text(title),
      subtitle: (trailing != null && trailing.isNotEmpty) ? Text(trailing, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
      onLongPress: (trailing != null && trailing.isNotEmpty)
          ? () {
              Clipboard.setData(ClipboardData(text: trailing));
            }
          : null,
    );
  }
}

// --- Reusable widgets ---

class _LegalSection {
  final String heading;
  final String body;
  const _LegalSection({required this.heading, required this.body});
}

class _LegalScaffold extends StatelessWidget {
  final String title;
  final List<_LegalSection> sections;
  const _LegalScaffold({required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(
        title: title,
        isBack: true,
        showSettings: false,
        showNotification: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'มีผลใช้บังคับ: $_kEffectiveDate',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 16),
              ...sections.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.heading,
                        style: TextStyle(
                          fontSize: getResponsiveFontSize(context, fontSize: 16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.body,
                        style: TextStyle(
                          fontSize: getResponsiveFontSize(context, fontSize: 14),
                          height: 1.5,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
