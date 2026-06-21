import 'daily_combo_dates.dart';
import 'daily_combo_history_entry.dart';

/// Estado persistido do combo diário.
class DailyComboState {
  const DailyComboState({
    this.currentStreak = 0,
    this.streakStartedOn,
    this.lastClearedOn,
    this.pendingArchiveLength,
    this.pendingArchiveStartedOn,
    this.pendingArchiveBrokenOn,
    this.pendingHistory = const [],
    this.synced = true,
  });

  final int currentStreak;
  final DateTime? streakStartedOn;
  final DateTime? lastClearedOn;

  /// Sequência perdida aguardando reinício para gravar no histórico.
  final int? pendingArchiveLength;
  final DateTime? pendingArchiveStartedOn;
  final DateTime? pendingArchiveBrokenOn;

  final List<DailyComboHistoryEntry> pendingHistory;
  final bool synced;

  bool get hasPendingArchive => pendingArchiveLength != null;

  DailyComboState copyWith({
    int? currentStreak,
    DateTime? streakStartedOn,
    DateTime? lastClearedOn,
    int? pendingArchiveLength,
    DateTime? pendingArchiveStartedOn,
    DateTime? pendingArchiveBrokenOn,
    List<DailyComboHistoryEntry>? pendingHistory,
    bool? synced,
    bool clearPendingArchive = false,
  }) {
    return DailyComboState(
      currentStreak: currentStreak ?? this.currentStreak,
      streakStartedOn: streakStartedOn ?? this.streakStartedOn,
      lastClearedOn: lastClearedOn ?? this.lastClearedOn,
      pendingArchiveLength: clearPendingArchive
          ? null
          : (pendingArchiveLength ?? this.pendingArchiveLength),
      pendingArchiveStartedOn: clearPendingArchive
          ? null
          : (pendingArchiveStartedOn ?? this.pendingArchiveStartedOn),
      pendingArchiveBrokenOn: clearPendingArchive
          ? null
          : (pendingArchiveBrokenOn ?? this.pendingArchiveBrokenOn),
      pendingHistory: pendingHistory ?? this.pendingHistory,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toLocalJson() => {
        'current_streak': currentStreak,
        'streak_started_on': streakStartedOn != null
            ? DailyComboDates.formatYmd(streakStartedOn!)
            : null,
        'last_cleared_on': lastClearedOn != null
            ? DailyComboDates.formatYmd(lastClearedOn!)
            : null,
        'pending_archive_length': pendingArchiveLength,
        'pending_archive_started_on': pendingArchiveStartedOn != null
            ? DailyComboDates.formatYmd(pendingArchiveStartedOn!)
            : null,
        'pending_archive_broken_on': pendingArchiveBrokenOn != null
            ? DailyComboDates.formatYmd(pendingArchiveBrokenOn!)
            : null,
        'pending_history':
            pendingHistory.map((e) => e.toLocalJson()).toList(growable: false),
        'synced': synced,
      };

  factory DailyComboState.fromLocalJson(Map<String, dynamic> json) {
    final historyRaw = json['pending_history'];
    final history = <DailyComboHistoryEntry>[];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is Map) {
          history.add(
            DailyComboHistoryEntry.fromLocalJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return DailyComboState(
      currentStreak: json['current_streak'] as int? ?? 0,
      streakStartedOn:
          DailyComboDates.parseYmd(json['streak_started_on'] as String?),
      lastClearedOn:
          DailyComboDates.parseYmd(json['last_cleared_on'] as String?),
      pendingArchiveLength: json['pending_archive_length'] as int?,
      pendingArchiveStartedOn: DailyComboDates.parseYmd(
        json['pending_archive_started_on'] as String?,
      ),
      pendingArchiveBrokenOn: DailyComboDates.parseYmd(
        json['pending_archive_broken_on'] as String?,
      ),
      pendingHistory: history,
      synced: json['synced'] as bool? ?? true,
    );
  }
}
