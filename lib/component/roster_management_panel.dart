import 'package:flutter/material.dart';
import 'package:badminton/model/player.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/add_guest_dialog.dart';
import 'package:badminton/component/manage_game_models.dart';

class RosterManagementPanel extends StatefulWidget {
  final String sessionId;
  final List<Player> players; 
  final VoidCallback onClose;
  final double courtFee;
  final double shuttleFee;
  final VoidCallback? onPlayerAdded;
  final int maxParticipants;
  final int refreshKey;

  const RosterManagementPanel({
    super.key,
    required this.onClose,
    required this.sessionId,
    required this.players,
    this.courtFee = 0.0,
    this.shuttleFee = 0.0,
    this.onPlayerAdded,
    this.maxParticipants = 0,
    this.refreshKey = 0,
  });

  @override
  State<RosterManagementPanel> createState() => _RosterManagementPanelState();
}

class _RosterManagementPanelState extends State<RosterManagementPanel> with SingleTickerProviderStateMixin {
  late List<RosterPlayer> _rosterPlayers;
  final Set<int> _processingPlayerIds = {};
  List<dynamic> _skillLevels = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _rosterPlayers = [];
    _fetchRosterData();
    _fetchSkillLevels();
  }

  @override
  void didUpdateWidget(covariant RosterManagementPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshKey != oldWidget.refreshKey) {
      _fetchRosterData();
    }
  }

  Future<void> _fetchRosterData() async {
    try {
      final response = await ApiProvider().get('/gamesessions/${widget.sessionId}/roster');
      if (mounted && response['data'] is List) {
        setState(() {
          _rosterPlayers = (response['data'] as List)
              .asMap()
              .entries
              .map((e) => RosterPlayer.fromJson(e.value, e.key + 1))
              .toList();
        });
      }
    } catch (e) {}
  }

  Future<void> _checkInPlayer(RosterPlayer player) async {
    if (_processingPlayerIds.contains(player.participantId)) return;
    setState(() => _processingPlayerIds.add(player.participantId));
    try {
      await ApiProvider().post(
        '/gamesessions/${widget.sessionId}/checkin',
        data: {
          "participantId": player.participantId,
          "participantType": player.participantType,
          "scannedData": null,
        },
      );
      if (mounted) {
        setState(() => player.isChecked = true);
        showDialogMsg(
          context,
          title: 'สำเร็จ',
          subtitle: 'เช็คอิน ${player.nickname} สำเร็จ',
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
        widget.onPlayerAdded?.call();
      }
    } catch (e) {
      if (mounted) {
        showDialogMsg(
          context,
          title: 'เช็คอินล้มเหลว',
          subtitle: e.toString().replaceFirst('Exception: ', ''),
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    } finally {
      if (mounted) setState(() => _processingPlayerIds.remove(player.participantId));
    }
  }

  Future<void> _fetchSkillLevels() async {
    try {
      final response = await ApiProvider().get('/organizer/skill-levels');
      if (mounted && response['data'] is List) {
        setState(() {
          _skillLevels = (response['data'] as List).map((level) {
            return {"id": level['skillLevelId'], "name": level['levelName']};
          }).toList();
        });
      }
    } catch (e) {}
  }

  Future<void> _updatePlayerSkill(RosterPlayer player, int newSkillLevelId) async {
    final oldSkillLevel = player.skillLevel;
    setState(() => player.skillLevel = newSkillLevelId);
    try {
      await ApiProvider().put(
        '/participants/${player.participantType.toLowerCase()}/${player.participantId}/skill',
        data: {"skillLevelId": newSkillLevelId},
      );
      widget.onPlayerAdded?.call();
    } catch (e) {
      if (mounted) {
        setState(() => player.skillLevel = oldSkillLevel);
        showDialogMsg(
          context,
          title: 'อัปเดตระดับมือล้มเหลว',
          subtitle: e.toString().replaceFirst('Exception: ', ''),
          btnLeft: 'ตกลง',
          onConfirm: () {},
        );
      }
    }
  }

  Future<void> _showAddGuestDialog() async {
    final result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddGuestDialog(
          sessionId: int.tryParse(widget.sessionId) ?? 0,
          courtFee: widget.courtFee,
          shuttleFee: widget.shuttleFee,
        );
      },
    );
    if (result == true) {
      _fetchRosterData();
      widget.onPlayerAdded?.call();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 365,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('จัดการรายชื่อ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
                      ],
                    ),
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.teal,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.teal,
                      tabs: [
                        Tab(child: Text('ผู้เล่น (${_rosterPlayers.where((p) {
                          final orig = p.status > 10 ? p.status - 10 : p.status;
                          return orig == 1;
                        }).length}/${widget.maxParticipants})', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Tab(child: Text('สำรอง (${_rosterPlayers.where((p) {
                          final orig = p.status > 10 ? p.status - 10 : p.status;
                          return orig == 2;
                        }).length})', style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildPlayerTable(1), _buildPlayerTable(2)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showAddGuestDialog,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        child: const Text('เพิ่มผู้เล่น Walk In'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerTable(int statusFilter) {
    final filteredPlayers = _rosterPlayers.where((p) {
      final orig = p.status > 10 ? p.status - 10 : p.status;
      return orig == statusFilter;
    }).toList();
    if (filteredPlayers.isEmpty) return Center(child: Text(statusFilter == 1 ? 'ไม่มีผู้เล่นตัวจริง' : 'ไม่มีผู้เล่นสำรอง'));
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 10,
        horizontalMargin: 12,
        columns: const [DataColumn(label: Text('No')), DataColumn(label: Text('ชื่อ')), DataColumn(label: Text('เพศ')), DataColumn(label: Text('มือ')), DataColumn(label: Text('Check'))],
        rows: filteredPlayers.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final player = entry.value;
          
          int? currentSkill = player.skillLevel;
          bool skillExists = _skillLevels.any((s) => s['id'] == currentSkill);
          if (!skillExists) {
            currentSkill = null; // ป้องกันแครชถ้าระดับมือถูกซ่อนไปแล้ว
          }

          final isCheckedOut = player.status > 10;
          
          return DataRow(cells: [
            DataCell(Text('$index')),
            DataCell(
              SizedBox(
                width: 80, 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      player.nickname, 
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCheckedOut ? Colors.grey : Colors.black,
                        decoration: isCheckedOut ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (isCheckedOut)
                      const Text('จ่ายเงินแล้ว', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            ),
            DataCell(Text(player.gender)),
            DataCell(DropdownButton<int>(
              value: currentSkill, 
              isDense: true, 
              underline: const SizedBox(),
              items: _skillLevels.map((level) => DropdownMenuItem<int>(value: level['id'], child: Text(level['name'], style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: isCheckedOut ? null : (newValue) { if (newValue != null) _updatePlayerSkill(player, newValue); },
            )),
            DataCell(Checkbox(
              value: player.isChecked || isCheckedOut, 
              onChanged: (player.isChecked || isCheckedOut || _processingPlayerIds.contains(player.participantId)) 
                  ? null 
                  : (bool? newValue) { if (newValue == true) _checkInPlayer(player); }
            )),
          ]);
        }).toList(),
      ),
    );
  }
}