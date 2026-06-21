import 'daily_combo_dates.dart';

/// Registro de uma sequência encerrada ao quebrar e reiniciar o combo.
class DailyComboHistoryEntry {
  const DailyComboHistoryEntry({
    required this.streakLength,
    required this.startedOn,
    required this.endedOn,
    required this.restartedOn,
    this.id,
    this.synced = false,
  });

  final String? id;
  final int streakLength;
  final DateTime startedOn;
  final DateTime endedOn;
  final DateTime restartedOn;
  final bool synced;

  DailyComboHistoryEntry copyWith({
    String? id,
    int? streakLength,
    DateTime? startedOn,
    DateTime? endedOn,
    DateTime? restartedOn,
    bool? synced,
  }) {
    return DailyComboHistoryEntry(
      id: id ?? this.id,
      streakLength: streakLength ?? this.streakLength,
      startedOn: startedOn ?? this.startedOn,
      endedOn: endedOn ?? this.endedOn,
      restartedOn: restartedOn ?? this.restartedOn,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toLocalJson() => {
        if (id != null) 'id': id,
        'streak_length': streakLength,
        'started_on': DailyComboDates.formatYmd(startedOn),
        'ended_on': DailyComboDates.formatYmd(endedOn),
        'restarted_on': DailyComboDates.formatYmd(restartedOn),
        'synced': synced,
      };

  factory DailyComboHistoryEntry.fromLocalJson(Map<String, dynamic> json) {
    return DailyComboHistoryEntry(
      id: json['id'] as String?,
      streakLength: json['streak_length'] as int? ?? 0,
      startedOn: DailyComboDates.parseYmd(json['started_on'] as String?) ??
          DateTime.now(),
      endedOn: DailyComboDates.parseYmd(json['ended_on'] as String?) ??
          DateTime.now(),
      restartedOn:
          DailyComboDates.parseYmd(json['restarted_on'] as String?) ??
              DateTime.now(),
      synced: json['synced'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toSupabaseRow(String userId) => {
        if (id != null) 'id': id,
        'user_id': userId,
        'streak_length': streakLength,
        'started_on': DailyComboDates.formatYmd(startedOn),
        'ended_on': DailyComboDates.formatYmd(endedOn),
        'restarted_on': DailyComboDates.formatYmd(restartedOn),
      };
}
