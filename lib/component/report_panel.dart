import 'package:flutter/material.dart';
import 'package:badminton/shared/api_provider.dart';

class ReportPanel extends StatefulWidget {
  final String sessionId;
  final VoidCallback onClose;

  const ReportPanel({super.key, required this.sessionId, required this.onClose});

  @override
  State<ReportPanel> createState() => _ReportPanelState();
}

class _ReportPanelState extends State<ReportPanel> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await ApiProvider().get('/GameSessions/${widget.sessionId}/analytics');
      if (mounted) {
        setState(() {
          _data = response['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 400,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('รายงานผลการแข่งขัน', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
                  ],
                ),
              ),
              const Divider(),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_data == null)
                const Expanded(child: Center(child: Text('ไม่พบข้อมูล')))
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('เล่นไปแล้วทั้งหมด: ${_data!['totalGames']} เกม', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 16),
                      ...(_data!['matchHistory'] as List).reversed.map((m) => _buildMatchCard(m)).toList(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchCard(dynamic match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('สนาม ${match['courtNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                Text('เวลา: ${match['duration']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Divider(height: 12),
            Row(
              children: [
                Expanded(child: Text(match['teamA'] ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ),
                Expanded(child: Text(match['teamB'] ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}