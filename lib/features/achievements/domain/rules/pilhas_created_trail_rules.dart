import '../../../tasks/domain/pilha.dart';
import '../achievement_event.dart';
import '../achievement_trail_id.dart';

/// Trilha **Pilhas Criadas** — 1 ponto por pilha criada.
abstract final class PilhasCreatedTrailRules {
  static String eventKeyForPilha(String pilhaId) =>
      'pilhas_created:pilha:$pilhaId';

  static AchievementEvent eventForNewPilha(Pilha pilha) {
    return AchievementEvent(
      trail: AchievementTrailId.pilhasCreated,
      eventKey: eventKeyForPilha(pilha.id),
    );
  }
}
