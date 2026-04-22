import 'package:badminton/shared/function.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DetailsCard extends StatelessWidget {
  final dynamic model;
  const DetailsCard({super.key, this.model});

  @override
  Widget build(BuildContext context) {
    final int totalParticipants = (model['participants'] as List?)?.length ?? 0;
    final int maxParticipants = model['maxParticipants'] ?? 0;
    final int reserveCount =
        totalParticipants > maxParticipants ? totalParticipants - maxParticipants : 0;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ไอคอนสิ่งอำนวยความสะดวก
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children:
                  (model['facilities'] as List<dynamic>?)
                      ?.map(
                        (facility) =>
                            _buildFacilityIcon(context, facility['iconUrl']),
                      )
                      .toList() ??
                  [],
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              context,
              Icons.payments_outlined,
              'ค่าสนาม ${(num.tryParse('${model['courtFeePerPerson']}') ?? 0).toStringAsFixed(0)} บาท/ชั่วโมง',
            ),
            _buildInfoRow(
              context,
              Icons.sell_outlined, // ใช้ไอคอนป้ายแท็กสินค้าเพื่อสื่อถึง แบรนด์/รุ่น/ราคา แทนลูกแบดมินตัน
              '${model['shuttlecockBrandName'] ?? '-'} ${model['shuttlecockModelName'] ?? ''} ${model['shuttlecockFeePerPerson'] != null ? '${(num.tryParse('${model['shuttlecockFeePerPerson']}') ?? 0).toStringAsFixed(0)} บาท/ลูก' : ''}'.trim(),
            ),
            _buildInfoRow(
              context,
              Icons.sports_tennis_outlined,
              '${model['gameTypeName'] ?? '-'}',
            ),
            _buildInfoRow(
              context,
              Icons.map_outlined,
              'สนามที่ ${model['courtNumbers'] ?? '-'}',
            ),
            _buildInfoRow(
              context,
              Icons.group_outlined,
              'ผู้เล่น ${model['currentParticipants'] ?? 0}/${model['maxParticipants'] ?? 0} คน   (สำรอง $reserveCount/10)',
              trailing: GestureDetector(
                onTap: () => context.push(
                  '/player-list/${model['gameSessionId'] ?? model['sessionId']}',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E9D7A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ดูผู้เล่น',
                    style: TextStyle(
                      color: Color(0xFF0E9D7A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),

            // --- ส่วนของ Note ---
            if (model['notes'] != null && model['notes'].toString().trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'หมายเหตุ: ${model['notes']}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),

            // รายละเอียดค่าใช้จ่ายและผู้เล่น
            const Divider(height: 32),
            // รายได้
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('รายได้', style: TextStyle(fontSize: 18)),
                Text(
                  '${(num.tryParse('${model['paidAmount'] ?? 0}') ?? 0).toStringAsFixed(0)}/${(num.tryParse('${model['totalIncome'] ?? 0}') ?? 0).toStringAsFixed(0)} บาท',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0E9D7A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper สำหรับสร้างไอคอน
  Widget _buildFacilityIcon(BuildContext context, String iconUrl) {
    return CircleAvatar(radius: 22, child: Image.network(iconUrl));
  }

  // Helper สำหรับสร้างแถวข้อมูลพร้อมไอคอน
  Widget _buildInfoRow(BuildContext context, IconData icon, String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0E9D7A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: getResponsiveFontSize(context, fontSize: 14),
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
