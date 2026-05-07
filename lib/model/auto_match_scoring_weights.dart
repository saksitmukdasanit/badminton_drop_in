import 'dart:convert';

import 'package:badminton/shared/api_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors `AutoMatchScoringWeightsDto` ใน backend.
/// เปลี่ยนค่า default ให้ตรงกับฝั่ง backend เท่านั้น
class AutoMatchScoringWeights {
  static const int _kQueueDefault = 10;
  static const int _kTogetherPenaltyDefault = 40;
  static const int _kMixedOppositeDefault = 15;
  static const int _kMixedTeammateDefault = 20;
  static const int _kSameLevelDefault = 30;
  static const int _kTeamMateMulDefault = 2;
  static const int _kTeamOppMulDefault = 1;

  /// 0–100 น้ำหนักลำดับคิว (สูง = คนรอนานได้ก่อน)
  final int queuePositionMultiplier;

  /// 0–100 โทษซ้ำหน้า (สูง = หลีกเลี่ยงคนเคยลงด้วยกันแรงๆ)
  final int matchTogetherPenaltyPerOccurrence;

  /// 0–100 โหมดผสม คนที่ 2: คนละมือกับแกนหลัก
  final int mixedModeOppositeSkillMultiplier;

  /// 0–100 โหมดผสม คนที่ 3–4: ใกล้เคียงแกนหลัก/คู่
  final int mixedModeTeammateSkillMultiplier;

  /// 0–100 โหมดตามมือ: ใกล้เคียงแกนหลัก
  final int sameLevelSkillMultiplier;

  /// 0–10 ตอนแบ่งทีม: เคยเป็นคู่กัน
  final int teamFormationTeammateHistoryMultiplier;

  /// 0–10 ตอนแบ่งทีม: เคยเป็นคู่แข่งกัน
  final int teamFormationOpponentHistoryMultiplier;

  const AutoMatchScoringWeights({
    this.queuePositionMultiplier = _kQueueDefault,
    this.matchTogetherPenaltyPerOccurrence = _kTogetherPenaltyDefault,
    this.mixedModeOppositeSkillMultiplier = _kMixedOppositeDefault,
    this.mixedModeTeammateSkillMultiplier = _kMixedTeammateDefault,
    this.sameLevelSkillMultiplier = _kSameLevelDefault,
    this.teamFormationTeammateHistoryMultiplier = _kTeamMateMulDefault,
    this.teamFormationOpponentHistoryMultiplier = _kTeamOppMulDefault,
  });

  factory AutoMatchScoringWeights.defaults() => const AutoMatchScoringWeights();

  /// Preset: เน้นคิว — คนรอนานได้ก่อน, ลดน้ำหนักฝีมือ
  factory AutoMatchScoringWeights.presetQueueFirst() =>
      const AutoMatchScoringWeights(
        queuePositionMultiplier: 20,
        matchTogetherPenaltyPerOccurrence: 30,
        mixedModeOppositeSkillMultiplier: 8,
        mixedModeTeammateSkillMultiplier: 10,
        sameLevelSkillMultiplier: 15,
      );

  /// Preset: เน้นไม่ซ้ำหน้า — กระจายผู้เล่น
  factory AutoMatchScoringWeights.presetVariety() =>
      const AutoMatchScoringWeights(
        queuePositionMultiplier: 8,
        matchTogetherPenaltyPerOccurrence: 70,
        mixedModeOppositeSkillMultiplier: 15,
        mixedModeTeammateSkillMultiplier: 20,
        sameLevelSkillMultiplier: 25,
        teamFormationTeammateHistoryMultiplier: 4,
        teamFormationOpponentHistoryMultiplier: 2,
      );

  /// Preset: เน้นฝีมือสูสี
  factory AutoMatchScoringWeights.presetSkillBalanced() =>
      const AutoMatchScoringWeights(
        queuePositionMultiplier: 6,
        matchTogetherPenaltyPerOccurrence: 30,
        mixedModeOppositeSkillMultiplier: 25,
        mixedModeTeammateSkillMultiplier: 35,
        sameLevelSkillMultiplier: 50,
      );

  AutoMatchScoringWeights copyWith({
    int? queuePositionMultiplier,
    int? matchTogetherPenaltyPerOccurrence,
    int? mixedModeOppositeSkillMultiplier,
    int? mixedModeTeammateSkillMultiplier,
    int? sameLevelSkillMultiplier,
    int? teamFormationTeammateHistoryMultiplier,
    int? teamFormationOpponentHistoryMultiplier,
  }) {
    return AutoMatchScoringWeights(
      queuePositionMultiplier:
          queuePositionMultiplier ?? this.queuePositionMultiplier,
      matchTogetherPenaltyPerOccurrence: matchTogetherPenaltyPerOccurrence ??
          this.matchTogetherPenaltyPerOccurrence,
      mixedModeOppositeSkillMultiplier: mixedModeOppositeSkillMultiplier ??
          this.mixedModeOppositeSkillMultiplier,
      mixedModeTeammateSkillMultiplier: mixedModeTeammateSkillMultiplier ??
          this.mixedModeTeammateSkillMultiplier,
      sameLevelSkillMultiplier:
          sameLevelSkillMultiplier ?? this.sameLevelSkillMultiplier,
      teamFormationTeammateHistoryMultiplier:
          teamFormationTeammateHistoryMultiplier ??
              this.teamFormationTeammateHistoryMultiplier,
      teamFormationOpponentHistoryMultiplier:
          teamFormationOpponentHistoryMultiplier ??
              this.teamFormationOpponentHistoryMultiplier,
    );
  }

  Map<String, dynamic> toJson() => {
        'queuePositionMultiplier': queuePositionMultiplier,
        'matchTogetherPenaltyPerOccurrence': matchTogetherPenaltyPerOccurrence,
        'mixedModeOppositeSkillMultiplier': mixedModeOppositeSkillMultiplier,
        'mixedModeTeammateSkillMultiplier': mixedModeTeammateSkillMultiplier,
        'sameLevelSkillMultiplier': sameLevelSkillMultiplier,
        'teamFormationTeammateHistoryMultiplier':
            teamFormationTeammateHistoryMultiplier,
        'teamFormationOpponentHistoryMultiplier':
            teamFormationOpponentHistoryMultiplier,
      };

  factory AutoMatchScoringWeights.fromJson(Map<String, dynamic> json) {
    int parse(String key, int fallback) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return AutoMatchScoringWeights(
      queuePositionMultiplier:
          parse('queuePositionMultiplier', _kQueueDefault),
      matchTogetherPenaltyPerOccurrence:
          parse('matchTogetherPenaltyPerOccurrence', _kTogetherPenaltyDefault),
      mixedModeOppositeSkillMultiplier:
          parse('mixedModeOppositeSkillMultiplier', _kMixedOppositeDefault),
      mixedModeTeammateSkillMultiplier:
          parse('mixedModeTeammateSkillMultiplier', _kMixedTeammateDefault),
      sameLevelSkillMultiplier:
          parse('sameLevelSkillMultiplier', _kSameLevelDefault),
      teamFormationTeammateHistoryMultiplier: parse(
          'teamFormationTeammateHistoryMultiplier', _kTeamMateMulDefault),
      teamFormationOpponentHistoryMultiplier:
          parse('teamFormationOpponentHistoryMultiplier', _kTeamOppMulDefault),
    );
  }

  bool get isDefault => this == AutoMatchScoringWeights.defaults();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AutoMatchScoringWeights &&
        other.queuePositionMultiplier == queuePositionMultiplier &&
        other.matchTogetherPenaltyPerOccurrence ==
            matchTogetherPenaltyPerOccurrence &&
        other.mixedModeOppositeSkillMultiplier ==
            mixedModeOppositeSkillMultiplier &&
        other.mixedModeTeammateSkillMultiplier ==
            mixedModeTeammateSkillMultiplier &&
        other.sameLevelSkillMultiplier == sameLevelSkillMultiplier &&
        other.teamFormationTeammateHistoryMultiplier ==
            teamFormationTeammateHistoryMultiplier &&
        other.teamFormationOpponentHistoryMultiplier ==
            teamFormationOpponentHistoryMultiplier;
  }

  @override
  int get hashCode => Object.hash(
        queuePositionMultiplier,
        matchTogetherPenaltyPerOccurrence,
        mixedModeOppositeSkillMultiplier,
        mixedModeTeammateSkillMultiplier,
        sameLevelSkillMultiplier,
        teamFormationTeammateHistoryMultiplier,
        teamFormationOpponentHistoryMultiplier,
      );

  // Persistence helpers (per-device, not per-session)
  static const String _prefsKey = 'autoMatchScoringWeights';

  static Future<AutoMatchScoringWeights> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return AutoMatchScoringWeights.defaults();
    }
    try {
      return AutoMatchScoringWeights.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return AutoMatchScoringWeights.defaults();
    }
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toJson()));
  }

  static Future<void> clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  // ---------------------------------------------------------------------------
  // Server persistence (per-organizer, sync ข้ามเครื่อง)
  // SharedPreferences ยังคงใช้เป็น offline cache ป้องกัน UI กระตุก
  // ---------------------------------------------------------------------------
  static const String _apiPath = '/organizer/auto-match-preset';

  /// โหลด preset จาก server — ถ้าล้มเหลว fallback เป็น cache จาก prefs
  static Future<AutoMatchScoringWeights> loadFromServer() async {
    try {
      final res = await ApiProvider().get(_apiPath);
      if (res['status'] == 200 && res['data'] is Map<String, dynamic>) {
        final w = AutoMatchScoringWeights.fromJson(
          res['data'] as Map<String, dynamic>,
        );
        await w.saveToPrefs();
        return w;
      }
    } catch (_) {
      // network/auth issue — ใช้ cache แทน
    }
    return loadFromPrefs();
  }

  /// บันทึก preset ขึ้น server (และ cache ลง prefs)
  Future<AutoMatchScoringWeights> saveToServer() async {
    try {
      final res = await ApiProvider().put(_apiPath, data: toJson());
      if (res['status'] == 200 && res['data'] is Map<String, dynamic>) {
        final w = AutoMatchScoringWeights.fromJson(
          res['data'] as Map<String, dynamic>,
        );
        await w.saveToPrefs();
        return w;
      }
    } catch (_) {
      // กรณี offline — บันทึกลง prefs แล้วค่อย sync ครั้งถัดไป
    }
    await saveToPrefs();
    return this;
  }

  /// รีเซ็ต preset กลับ default ทั้งบน server และ prefs
  static Future<AutoMatchScoringWeights> resetOnServer() async {
    try {
      await ApiProvider().delete(_apiPath);
    } catch (_) {
      // ignore — local prefs reset ก็พอแล้ว
    }
    await clearPrefs();
    return AutoMatchScoringWeights.defaults();
  }
}
