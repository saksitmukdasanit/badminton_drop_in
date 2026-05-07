import 'package:badminton/component/app_bar.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// หน้ารายการ template สร้างก๊วนประจำสัปดาห์
class RecurringTemplatesListPage extends StatefulWidget {
  const RecurringTemplatesListPage({super.key});

  @override
  State<RecurringTemplatesListPage> createState() =>
      _RecurringTemplatesListPageState();
}

class _RecurringTemplatesListPageState
    extends State<RecurringTemplatesListPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiProvider().get('/organizer/recurring-templates');
      if (!mounted) return;
      List<dynamic> list = [];
      if (res is Map && res['data'] is List) {
        list = res['data'] as List;
      }
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _setActive(int id, bool active) async {
    try {
      await ApiProvider()
          .patch('/organizer/recurring-templates/$id/active', data: {
        'isActive': active,
      });
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _delete(int id, String title) async {
    showDialogMsg(
      context,
      title: 'ปิดการใช้งาน',
      subtitle: 'ต้องการปิดการใช้งาน template\n"$title"\nใช่หรือไม่?',
      btnLeft: 'ยกเลิก',
      btnRight: 'ปิดการใช้งาน',
      btnRightBackColor: Colors.red,
      btnRightForeColor: Colors.white,
      isWarning: true,
      onConfirm: () {},
      onConfirmRight: () async {
        try {
          await ApiProvider().delete('/organizer/recurring-templates/$id');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ปิดการใช้งานแล้ว')),
            );
            await _load();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('$e')));
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final double fabBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      appBar: AppBarSubMain(title: 'ก๊วนประจำสัปดาห์', isBack: true),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabBottom),
        child: FloatingActionButton(
          backgroundColor: primary,
          onPressed: () async {
            final r = await context.push('/recurring-template-form');
            if (r == true && mounted) _load();
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD5DCF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: const [
                              SizedBox(height: 80),
                              Text(
                                'ยังไม่มีรูปแบบก๊วนประจำ — แตะ + เพื่อเพิ่ม\n'
                                'ระบบจะสร้างก๊วนล่วงหน้า ~14 วันตามวันที่เลือก',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount = 1;
                              double childAspectRatio = 1.45;
                              if (constraints.maxWidth >= 1000) {
                                crossAxisCount = 3;
                                childAspectRatio = 1.02;
                              } else if (constraints.maxWidth >= 600) {
                                crossAxisCount = 2;
                                childAspectRatio = 1.12;
                              }

                              return GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 100),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: childAspectRatio,
                                ),
                                itemCount: _items.length,
                                itemBuilder: (context, index) {
                                  final row = Map<String, dynamic>.from(
                                    _items[index] as Map,
                                  );
                                  final id = row['recurringTemplateId'] as int? ??
                                      row['recurring_template_id'] as int? ??
                                      0;
                                  final title =
                                      '${row['groupName'] ?? row['group_name'] ?? 'ก๊วน'}';
                                  final venue =
                                      '${row['venueName'] ?? row['venue_name'] ?? '-'}';
                                  final mask =
                                      (row['daysOfWeekMask'] ?? row['days_of_week_mask'] ?? 0) as num;
                                  final active =
                                      row['isActive'] ?? row['is_active'] ?? true;
                                  final st =
                                      '${row['startTime'] ?? row['start_time'] ?? ''}';
                                  final et =
                                      '${row['endTime'] ?? row['end_time'] ?? ''}';
                                  final gameType =
                                      '${row['gameTypeName'] ?? row['game_type_name'] ?? ''}';
                                  final maxSlots =
                                      (row['maxParticipants'] ?? row['max_participants'] ?? 0).toString();
                                  final courtFee =
                                      (row['courtFeePerPerson'] ?? row['court_fee_per_person'] ?? '').toString();
                                  final shuttleFee =
                                      (row['shuttlecockFeePerPerson'] ?? row['shuttlecock_fee_per_person'] ?? '').toString();
                                  final brand =
                                      '${row['shuttlecockBrandName'] ?? row['shuttlecock_brand_name'] ?? ''}';
                                  final model =
                                      '${row['shuttlecockModelName'] ?? row['shuttlecock_model_name'] ?? ''}';
                                  final facilities =
                                      (row['facilityNames'] ?? row['facility_names'] ?? '') as String;

                                  return Card(
                                    clipBehavior: Clip.antiAlias,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: InkWell(
                                      onTap: () async {
                                        final r = await context.push(
                                          '/recurring-template-form',
                                          extra: {'id': id},
                                        );
                                        if (r == true && mounted) _load();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        title,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.location_on,
                                                            size: 14,
                                                            color:
                                                                Colors.black54,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              venue,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'เปิดใช้',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                    Switch(
                                                      value: active == true,
                                                      onChanged: (v) =>
                                                          _setActive(id, v),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            _WeekdayPills(mask.toInt()),
                                            const SizedBox(height: 8),
                                            Expanded(
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                            Icons.access_time,
                                                            size: 14,
                                                            color: Colors
                                                                .black54),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          '$st–$et น.',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .black87,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        if (gameType
                                                            .isNotEmpty)
                                                          Expanded(
                                                            child: Text(
                                                              gameType,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .black54,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                            Icons.people,
                                                            size: 14,
                                                            color: Colors
                                                                .black54),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          'เปิดรับ $maxSlots ที่นั่ง',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .black87,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .stadium_outlined,
                                                            size: 14,
                                                            color: Colors
                                                                .black54),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          courtFee.isEmpty
                                                              ? 'ค่าสนาม -'
                                                              : 'ค่าสนาม $courtFee บ./คน',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .black87,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        const Icon(
                                                            Icons.sports_tennis,
                                                            size: 14,
                                                            color: Colors
                                                                .black54),
                                                        const SizedBox(
                                                            width: 4),
                                                        Text(
                                                          shuttleFee.isEmpty
                                                              ? 'ค่าลูก -'
                                                              : 'ค่าลูก $shuttleFee บ./คน',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .black87,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    if (brand.isNotEmpty ||
                                                        model.isNotEmpty) ...[
                                                      Row(
                                                        children: [
                                                          const Icon(
                                                              Icons
                                                                  .sports_tennis,
                                                              size: 14,
                                                              color: Colors
                                                                  .black54),
                                                          const SizedBox(
                                                              width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              '$brand $model'
                                                                  .trim(),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                    ],
                                                    if (facilities.isNotEmpty)
                                                      _FacilitiesRow(
                                                          facilities),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                TextButton(
                                                  onPressed: () async {
                                                    final r =
                                                        await context.push(
                                                      '/recurring-template-form',
                                                      extra: {'id': id},
                                                    );
                                                    if (r == true &&
                                                        mounted) {
                                                      _load();
                                                    }
                                                  },
                                                  child: Text('แก้ไข',
                                                      style: TextStyle(
                                                          color: primary)),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      _delete(id, title),
                                                  child: const Text('ปิด',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.red)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}

class _WeekdayPills extends StatelessWidget {
  final int mask;
  const _WeekdayPills(this.mask);

  @override
  Widget build(BuildContext context) {
    const labels = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    final colors = [
      Colors.yellow.shade600,
      Colors.pink.shade400,
      Colors.green.shade500,
      Colors.orange.shade500,
      Colors.blue.shade500,
      Colors.purple.shade500,
      Colors.red.shade500,
    ];

    final chips = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final selected = (mask & (1 << i)) != 0;
      final bg = selected ? colors[i] : Colors.grey.shade200;
      final fg = selected ? Colors.white : Colors.grey.shade600;
      chips.add(Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          labels[i],
          style: TextStyle(
            fontSize: 10,
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }
}

class _FacilitiesRow extends StatelessWidget {
  final String namesCsv;
  const _FacilitiesRow(this.namesCsv);

  @override
  Widget build(BuildContext context) {
    final parts = namesCsv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    IconData iconFor(String name) {
      final n = name.toLowerCase();
      if (n.contains('ที่จอด') || n.contains('parking')) {
        return Icons.local_parking;
      }
      if (n.contains('แอร์') || n.contains('air')) {
        return Icons.ac_unit;
      }
      if (n.contains('ห้องน้ำ') || n.contains('shower') || n.contains('น้ำ')) {
        return Icons.shower;
      }
      if (n.contains('อาหาร') || n.contains('drink') || n.contains('ร้าน')) {
        return Icons.restaurant;
      }
      return Icons.check_circle_outline;
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: parts.map((p) {
        return Chip(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          labelPadding: const EdgeInsets.only(right: 4),
          avatar: Icon(iconFor(p), size: 14),
          label: Text(
            p,
            style: const TextStyle(fontSize: 10),
          ),
        );
      }).toList(),
    );
  }
}
