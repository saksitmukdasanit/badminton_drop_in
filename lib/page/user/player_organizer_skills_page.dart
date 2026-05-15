import 'package:badminton/component/dialog.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/shared/fullscreen_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// เปิด dialog เลือกผู้จัดที่ใช้แสดง "ระดับมือ" บนหน้าแรก (สอดคล้องกับ dialog อื่นในแอป)
Future<void> showPlayerOrganizerSkillsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (dialogContext) {
      final maxH = MediaQuery.sizeOf(dialogContext).height * 0.88;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: maxH),
          child: const PlayerOrganizerSkillsDialogBody(),
        ),
      );
    },
  );
}

class PlayerOrganizerSkillsDialogBody extends StatefulWidget {
  const PlayerOrganizerSkillsDialogBody({super.key});

  @override
  State<PlayerOrganizerSkillsDialogBody> createState() =>
      _PlayerOrganizerSkillsDialogBodyState();
}

class _PlayerOrganizerSkillsDialogBodyState extends State<PlayerOrganizerSkillsDialogBody> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  int? _selectedOrganizerIdForHome;
  bool _hasRows = false;

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
      final response = await ApiProvider().get('/player/dashboard/organizer-skills');
      final list = response['data'];
      if (list is! List) {
        throw Exception('ข้อมูลไม่ถูกต้อง');
      }
      final rows = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      int? preferred;
      for (final r in rows) {
        if (r['isPreferredForHome'] == true) {
          preferred = (r['organizerUserId'] as num?)?.toInt();
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _items = rows;
        _hasRows = rows.isNotEmpty;
        _selectedOrganizerIdForHome = preferred;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _applySelection(int? organizerUserId) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final response = await ApiProvider().put(
        '/player/dashboard/skill-display-organizer',
        data: {'organizerUserId': organizerUserId},
      );
      if (response['status'] != 200) {
        throw Exception(response['message'] ?? 'บันทึกไม่สำเร็จ');
      }
      if (!mounted) return;
      setState(() {
        _selectedOrganizerIdForHome = organizerUserId;
      });
      if (mounted) {
        await showDialogMsg(
          context,
          title: 'สำเร็จ',
          subtitle: 'บันทึกการแสดงระดับมือแล้ว',
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().replaceFirst('Exception: ', '');
        await showDialogMsg(
          context,
          title: 'เกิดข้อผิดพลาด',
          subtitle: errStr,
          isWarning: true,
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatUpdated(dynamic raw) {
    if (raw == null) return '—';
    DateTime? dt;
    if (raw is String) {
      dt = DateTime.tryParse(raw);
    }
    if (dt == null) return '—';
    final local = dt.toLocal();
    return DateFormat("d MMM yy HH:mm", 'th_TH').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('ระดับมือตามผู้จัด'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('ลองอีกครั้ง')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      'ระดับมือเป็นการประเมินของแต่ละผู้จัด ไม่ใช่คะแนนกลางของแอป '
                      'คุณเลือกได้ว่าจะให้หน้าแรกแสดงจากผู้จัดคนไหน หรือให้ระบบใช้การอัปเดตล่าสุดอัตโนมัติ',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_saving) const LinearProgressIndicator(minHeight: 2),
                    if (_saving) const SizedBox(height: 8),
                    Opacity(
                      opacity: !_hasRows ? 0.5 : 1,
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _selectedOrganizerIdForHome == null
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                : Colors.grey.shade300,
                          ),
                        ),
                        title: const Text(
                          'อัตโนมัติ (ใช้การประเมินล่าสุด)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'หน้าแรกจะตามวันที่อัปเดตล่าสุดจากผู้จัดใดก็ได้',
                        ),
                        trailing: _selectedOrganizerIdForHome == null
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : Icon(Icons.circle_outlined, color: Colors.grey.shade400),
                        selected: _selectedOrganizerIdForHome == null,
                        onTap: !_hasRows ? null : () => _applySelection(null),
                      ),
                    ),
                    const Divider(height: 24),
                    if (!_hasRows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'ยังไม่มีการประเมินระดับมือจากผู้จัด',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    else
                      ..._items.map((r) {
                        final orgId = (r['organizerUserId'] as num).toInt();
                        final nick = r['organizerNickname']?.toString() ?? '—';
                        final level = r['skillLevelName']?.toString() ?? '—';
                        final photo = r['organizerProfilePhotoUrl']?.toString();
                        final updated = _formatUpdated(r['updatedDateUtc']);
                        final selected = _selectedOrganizerIdForHome == orgId;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            leading: (photo != null && photo.isNotEmpty)
                                ? GestureDetector(
                                    onTap: () =>
                                        showFullscreenNetworkImage(context, photo),
                                    child: CircleAvatar(
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: NetworkImage(photo),
                                    ),
                                  )
                                : CircleAvatar(
                                    backgroundColor: Colors.grey.shade200,
                                    child: Text(
                                      nick.isNotEmpty ? nick.substring(0, 1) : '?',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                            title: Text(
                              nick,
                              style: TextStyle(
                                fontWeight:
                                    selected ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '$level · อัปเดต $updated',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: selected
                                ? Icon(Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary)
                                : Icon(Icons.circle_outlined,
                                    color: Colors.grey.shade400),
                            selected: selected,
                            onTap: () => _applySelection(orgId),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
