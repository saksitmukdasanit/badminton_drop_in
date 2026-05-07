import 'package:badminton/model/auto_match_scoring_weights.dart';
import 'package:flutter/material.dart';

/// Bottom sheet ให้ผู้จัดปรับ weight ของระบบจัดคู่อัตโนมัติ
/// คืนค่าใหม่ผ่าน [Navigator.pop] เมื่อกด "บันทึก", หรือ null เมื่อยกเลิก
class AutoMatchSettingsSheet extends StatefulWidget {
  final AutoMatchScoringWeights initial;

  const AutoMatchSettingsSheet({super.key, required this.initial});

  static Future<AutoMatchScoringWeights?> show(
    BuildContext context, {
    required AutoMatchScoringWeights initial,
  }) {
    return showModalBottomSheet<AutoMatchScoringWeights>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      // RESPONSIVE: บนแท็บเล็บไม่ให้ sheet แผ่เต็มจอ
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AutoMatchSettingsSheet(initial: initial),
    );
  }

  @override
  State<AutoMatchSettingsSheet> createState() => _AutoMatchSettingsSheetState();
}

class _AutoMatchSettingsSheetState extends State<AutoMatchSettingsSheet> {
  late AutoMatchScoringWeights _w;

  @override
  void initState() {
    super.initState();
    _w = widget.initial;
  }

  void _applyPreset(AutoMatchScoringWeights preset) {
    setState(() => _w = preset);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollCtl) {
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView(
                    controller: scrollCtl,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    children: [
                      _buildPresets(),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'ลำดับคิว',
                        description:
                            'ยิ่งสูง คนที่รอนาน/เกมน้อยจะได้ลงก่อน (ค่าเริ่มต้น 10)',
                        children: [
                          _buildSlider(
                            label: 'น้ำหนักลำดับคิว',
                            value: _w.queuePositionMultiplier.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 100,
                            onChanged: (v) => setState(() => _w = _w.copyWith(
                                queuePositionMultiplier: v.round())),
                          ),
                        ],
                      ),
                      _buildSection(
                        title: 'ความหลากหลาย (ไม่ซ้ำหน้า)',
                        description:
                            'ยิ่งสูง ระบบจะหลีกเลี่ยงคนที่เคยลงเกมเดียวกันมาก่อน',
                        children: [
                          _buildSlider(
                            label: 'โทษซ้ำหน้าตอนคัดผู้เล่น',
                            value: _w.matchTogetherPenaltyPerOccurrence
                                .toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 100,
                            onChanged: (v) => setState(() => _w = _w.copyWith(
                                matchTogetherPenaltyPerOccurrence:
                                    v.round())),
                          ),
                          _buildSlider(
                            label: 'ตอนแบ่งทีม: เคยเป็นคู่กัน',
                            value: _w.teamFormationTeammateHistoryMultiplier
                                .toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            onChanged: (v) => setState(() => _w = _w.copyWith(
                                teamFormationTeammateHistoryMultiplier:
                                    v.round())),
                          ),
                          _buildSlider(
                            label: 'ตอนแบ่งทีม: เคยเป็นคู่แข่ง',
                            value: _w.teamFormationOpponentHistoryMultiplier
                                .toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            onChanged: (v) => setState(() => _w = _w.copyWith(
                                teamFormationOpponentHistoryMultiplier:
                                    v.round())),
                          ),
                        ],
                      ),
                      _buildSection(
                        title: 'ระดับฝีมือ',
                        description:
                            'ค่าน้ำหนักของระยะห่างระดับมือในแต่ละโหมด',
                        children: [
                          _buildSlider(
                            label: 'โหมดผสม: คนที่ 2 (ตรงข้ามแกนหลัก)',
                            value: _w.mixedModeOppositeSkillMultiplier
                                .toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 100,
                            onChanged: (v) => setState(() => _w = _w.copyWith(
                                mixedModeOppositeSkillMultiplier: v.round())),
                          ),
                          _buildSlider(
                            label: 'โหมดผสม: คู่ของแกนหลัก / คู่คนที่ 2',
                            value: _w.mixedModeTeammateSkillMultiplier
                                .toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 100,
                            onChanged: (v) => setState(() => _w = _w.copyWith(
                                mixedModeTeammateSkillMultiplier: v.round())),
                          ),
                          _buildSlider(
                            label: 'โหมดตามมือ: ใกล้เคียงแกนหลัก',
                            value: _w.sameLevelSkillMultiplier.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 100,
                            onChanged: (v) => setState(() => _w = _w.copyWith(
                                sameLevelSkillMultiplier: v.round())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildResetButton(),
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.indigo),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ตั้งค่าน้ำหนักการจัดคู่อัตโนมัติ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'ค่าที่ตั้งจะถูกใช้กับการจัดคู่ของก๊วนที่เปิดอยู่ครั้งถัดไป',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    final presets = <(String, AutoMatchScoringWeights, IconData)>[
      ('ค่าเริ่มต้น', AutoMatchScoringWeights.defaults(), Icons.refresh),
      (
        'เน้นคิว',
        AutoMatchScoringWeights.presetQueueFirst(),
        Icons.format_list_numbered
      ),
      ('ไม่ซ้ำหน้า', AutoMatchScoringWeights.presetVariety(), Icons.shuffle),
      (
        'ฝีมือสูสี',
        AutoMatchScoringWeights.presetSkillBalanced(),
        Icons.balance
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: presets.map((preset) {
          final isSelected = _w == preset.$2;
          return ChoiceChip(
            avatar: Icon(
              preset.$3,
              size: 16,
              color: isSelected ? Colors.white : Colors.indigo,
            ),
            label: Text(preset.$1),
            selected: isSelected,
            selectedColor: Colors.indigo,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.indigo,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) => _applyPreset(preset.$2),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.round().toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: Colors.indigo,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    if (_w.isDefault) return const SizedBox.shrink();
    return Center(
      child: TextButton.icon(
        onPressed: () =>
            setState(() => _w = AutoMatchScoringWeights.defaults()),
        icon: const Icon(Icons.restore, size: 18),
        label: const Text('คืนค่าเริ่มต้น'),
        style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('ยกเลิก'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(_w),
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
