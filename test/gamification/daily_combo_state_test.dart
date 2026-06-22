import 'package:flutter_test/flutter_test.dart';

import 'package:tasker_project/features/gamification/domain/daily_combo_history_entry.dart';
import 'package:tasker_project/features/gamification/domain/daily_combo_state.dart';

void main() {
  test('serialização round-trip', () {
    final original = DailyComboState(
      currentStreak: 5,
      streakStartedOn: DateTime(2026, 6, 15),
      lastClearedOn: DateTime(2026, 6, 19),
      pendingArchiveLength: 2,
      pendingArchiveStartedOn: DateTime(2026, 6, 10),
      pendingArchiveBrokenOn: DateTime(2026, 6, 12),
      pendingHistory: [
        DailyComboHistoryEntry(
          streakLength: 2,
          startedOn: DateTime(2026, 6, 10),
          endedOn: DateTime(2026, 6, 12),
          restartedOn: DateTime(2026, 6, 13),
        ),
      ],
      synced: false,
    );

    final restored = DailyComboState.fromLocalJson(original.toLocalJson());

    expect(restored.currentStreak, 5);
    expect(restored.streakStartedOn, DateTime(2026, 6, 15));
    expect(restored.pendingHistory, hasLength(1));
    expect(restored.synced, isFalse);
  });

  test('copyWith limpa arquivo pendente', () {
    const state = DailyComboState(
      pendingArchiveLength: 3,
      pendingArchiveStartedOn: null,
    );

    final cleared = state.copyWith(clearPendingArchive: true);

    expect(cleared.pendingArchiveLength, isNull);
    expect(cleared.hasPendingArchive, isFalse);
  });
}
