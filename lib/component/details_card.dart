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
            _buildText(
              context,
              'ค่าสนาม ${(num.tryParse('${model['courtFeePerPerson']}') ?? 0).toStringAsFixed(0)} บาท/ชั่วโมง',
            ),
            _buildText(
              context,
              '${model['shuttlecockBrandName'] ?? '-'} ${model['shuttlecockModelName'] ?? ''} ${model['shuttlecockFeePerPerson'] != null ? '${(num.tryParse('${model['shuttlecockFeePerPerson']}') ?? 0).toStringAsFixed(0)} บาท/ลูก' : ''}',
            ),
            _buildText(context, '${model['gameTypeName'] ?? '-'}'),
            _buildText(context, 'สนามที่ ${model['courtNumbers'] ?? '-'}'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildText(
                      context,
                      'ผู้เล่น ${model['currentParticipants'] ?? 0}/${model['maxParticipants'] ?? 0} คน',
                    ),
                    _buildText(context, 'สำรอง $reserveCount/10 คน'),
                  ],
                ),
                GestureDetector(
                  onTap: () => context.push(
                    '/player-list/${model['gameSessionId'] ?? model['sessionId']}',
                  ),
                  child: Text(
                    'ดูผู้เล่น',
                    style: TextStyle(
                      color: Colors.teal[600],
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            Text('note : ${model['notes'] ?? '-'}'),

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

  Widget _buildText(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: getResponsiveFontSize(context, fontSize: 14),
        fontWeight: FontWeight.w300,
      ),
    );
  }
}
