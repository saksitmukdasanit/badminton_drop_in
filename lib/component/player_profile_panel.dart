import 'package:badminton/component/manage_game_models.dart';
import 'package:flutter/material.dart';
import 'package:badminton/model/player.dart';
import 'package:badminton/shared/api_provider.dart';
import 'package:badminton/component/dialog.dart';
import 'package:badminton/component/button.dart';

class PlayerProfilePanel extends StatefulWidget {
  final String sessionId;
  final List<dynamic> skillLevels;
  final Player? player;
  final VoidCallback onClose;
  final Function(Player) onShowExpenses;
  final bool isPaused;
  final VoidCallback? onTogglePause;
  final bool isEnded;
  final VoidCallback? onToggleEndGame;

  const PlayerProfilePanel({
    super.key,
    required this.skillLevels,
    required this.sessionId,
    this.player,
    required this.onClose,
    required this.onShowExpenses,
    this.isPaused = false,
    this.onTogglePause,
    this.isEnded = false,
    this.onToggleEndGame,
  });

  @override
  State<PlayerProfilePanel> createState() => _PlayerProfilePanelState();
}

class _PlayerProfilePanelState extends State<PlayerProfilePanel> {
  bool _isEmergencyContactVisible = false;
  late int _selectedSkillLevel;
  bool _isStatsLoading = true;
  PlayerStats? _playerStats;

  @override
  void initState() {
    super.initState();
    _selectedSkillLevel = widget.player?.skillLevelId ?? 1;
    if (widget.player != null) {
      _fetchPlayerStats();
    }
  }

  @override
  void didUpdateWidget(covariant PlayerProfilePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player != oldWidget.player) {
      setState(() {
        _selectedSkillLevel = widget.player?.skillLevelId ?? 1;
        _isEmergencyContactVisible = false;
        _playerStats = null;
        _isStatsLoading = true;
      });
      if (widget.player != null) _fetchPlayerStats();
    }
  }

  Future<void> _fetchPlayerStats() async {
    if (widget.player == null) return;
    final parts = widget.player!.id.split('_');
    if (parts.length != 2) return;
    try {
      final response = await ApiProvider().get('/gamesessions/${widget.sessionId}/player-stats/${parts[0]}/${parts[1]}');
      if (mounted) {
        setState(() {
          _playerStats = PlayerStats.fromJson(response['data']);
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStatsLoading = false);
        final errStr = e.toString();
        if (!errStr.contains('401') && !errStr.contains('Invalid tokens')) {
          showDialogMsg(context, title: 'ไม่สามารถโหลดสถิติ', subtitle: errStr.replaceFirst('Exception: ', ''), btnLeft: 'ตกลง', onConfirm: () {});
        }
      }
    }
  }

  Future<void> _updateSkillLevel(int newSkillLevelId) async {
    if (widget.player == null) return;
    final parts = widget.player!.id.split('_');
    if (parts.length != 2) return;
    try {
      await ApiProvider().put('/participants/${parts[0].toLowerCase()}/${parts[1]}/skill', data: {"skillLevelId": newSkillLevelId});
      showDialogMsg(context, title: 'สำเร็จ', subtitle: 'อัปเดตระดับมือสำเร็จ', btnLeft: 'ตกลง', onConfirm: () {});
    } catch (e) {
      final errStr = e.toString();
      if (!errStr.contains('401') && !errStr.contains('Invalid tokens')) {
        showDialogMsg(context, title: 'อัปเดตระดับมือล้มเหลว', subtitle: errStr.replaceFirst('Exception: ', ''), btnLeft: 'ตกลง', onConfirm: () {});
      }
      setState(() => _selectedSkillLevel = widget.player?.skillLevelId ?? 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.player == null) return const SizedBox.shrink();
    final player = widget.player!;
    
    String? dropdownValue = _selectedSkillLevel.toString();
    if (!widget.skillLevels.any((s) => s['code'] == dropdownValue)) {
      dropdownValue = null; // ป้องกันแครชถ้าระดับมือถูกซ่อนไปแล้ว
    }
    
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 420,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (player.imageUrl != null && player.imageUrl!.isNotEmpty)
                      CircleAvatar(radius: 30, backgroundImage: NetworkImage(player.imageUrl!))
                    else
                      const CircleAvatar(radius: 30, child: Icon(Icons.person)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player.fullName ?? player.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                          Row(
                            children: [
                              const Text('ระดับมือ: ', style: TextStyle(fontSize: 14)),
                              DropdownButton<String>(
                                value: dropdownValue,
                                items: widget.skillLevels.map((skill) => DropdownMenuItem<String>(value: skill['code'], child: Text(skill['value'], style: const TextStyle(fontSize: 14)))).toList(),
                                onChanged: (String? newValue) { if (newValue != null) _updateSkillLevel(int.parse(newValue)); },
                              ),
                              const Spacer(),
                              IconButton(icon: const Icon(Icons.medical_services_outlined, color: Colors.red), onPressed: () => setState(() => _isEmergencyContactVisible = !_isEmergencyContactVisible)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isEmergencyContactVisible
                    ? Container(
                        key: const ValueKey('contact_visible'), width: double.infinity, color: Colors.red[100], padding: const EdgeInsets.all(12),
                        child: Text('ผู้ติดต่อฉุกเฉิน: ${player.emergencyContactName ?? ""} ${player.emergencyContactPhone ?? ""}', style: TextStyle(color: Colors.red[800])),
                      )
                    : const SizedBox.shrink(key: ValueKey('contact_hidden')),
              ),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    const TextSpan(text: 'เล่นไป: '),
                    TextSpan(text: '${_playerStats?.totalGamesPlayed ?? 0} เกม  ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const TextSpan(text: 'เวลาเล่นรวม: '),
                    TextSpan(text: '${_playerStats?.totalMinutesPlayed}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
              Expanded(
                child: _isStatsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Table(
                            border: TableBorder.all(color: Colors.grey.shade700, width: 1),
                            columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(2)},
                            children: [
                              buildRow(['เกมที่', 'สนาม', 'คู่', 'คู่แข่ง'], isHeader: true),
                              if (_playerStats?.matchHistory != null)
                                ..._playerStats!.matchHistory.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  MatchHistoryItem history = entry.value;
                                  return buildRow([(index + 1).toString(), history.courtNumber.toString(), history.teammate.nickname, history.opponents.map((op) => op.nickname).join(', ')]);
                                }).toList(),
                            ],
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 8, vertical: 16),
                        text: widget.isPaused ? 'ผู้เล่นกลับสู่เกม' : 'หยุดเกมส์ผู้เล่น',
                        backgroundColor: widget.isPaused ? const Color(0xFF0E9D7A) : const Color(0xFFFFFFFF),
                        foregroundColor: widget.isPaused ? Colors.white : const Color(0xFF0E9D7A),
                        side: const BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12, fontWeight: FontWeight.w600,
                        onPressed: widget.onTogglePause ?? () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 8, vertical: 16),
                        text: widget.isEnded ? 'กลับสู่เกมส์' : 'จบเกมส์ผู้เล่น',
                        backgroundColor: widget.isEnded ? Colors.red : const Color(0xFFFFFFFF),
                        foregroundColor: widget.isEnded ? Colors.white : const Color(0xFF0E9D7A),
                        side: const BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12, fontWeight: FontWeight.w600,
                        onPressed: () { if (widget.onToggleEndGame != null) { widget.onToggleEndGame!(); widget.onClose(); } },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomElevatedButton(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 8, vertical: 16),
                        text: 'ค่าใช้จ่าย', backgroundColor: Color(0xFF243F94), side: BorderSide(color: Color(0xFFB3B3C1)),
                        fontSize: 12, fontWeight: FontWeight.w600, icon: Icons.keyboard_arrow_down,
                        onPressed: () => widget.onShowExpenses(widget.player!),
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

  TableRow buildRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      children: cells.map((cell) => Padding(padding: const EdgeInsets.all(8.0), child: Text(cell, textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, fontSize: 16)))).toList(),
    );
  }
}