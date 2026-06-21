import 'achievement_medal.dart';
import 'achievement_trail.dart';
import 'achievement_trail_id.dart';
import 'achievement_trail_flags.dart';

/// Catálogo estático de trilhas e medalhas — fonte da verdade das regras de negócio.
abstract final class AchievementCatalog {
  static const trails = <AchievementTrail>[
    tasksCreatedTrail,
    magicInputTrail,
    daysCompletedTrail,
    taskAdvancesTrail,
    pilhasCreatedTrail,
    unfinishedTasksTrail,
    curiositiesTrail,
  ];

  /// Trilhas visíveis e ativas na UI / desbloqueio de medalhas.
  static List<AchievementTrail> get activeTrails => trails
      .where((trail) => AchievementTrailFlags.isEnabled(trail.id))
      .toList(growable: false);

  static final medalsById = {
    for (final trail in trails)
      for (final medal in trail.medals) medal.id: medal,
  };

  static final trailsById = {
    for (final trail in trails) trail.id: trail,
  };

  // ---------------------------------------------------------------------------
  // Tarefas Criadas — 1 ponto por tarefa criada (irreversível).
  // ---------------------------------------------------------------------------
  static const tasksCreatedTrail = AchievementTrail(
    id: AchievementTrailId.tasksCreated,
    title: 'Tarefas Criadas',
    summary:
        'Cada tarefa que você cria vale 1 ponto nesta trilha. '
        'Os pontos ficam com você para sempre — mesmo que edite, conclua '
        'ou exclua a tarefa depois.',
    medals: [
      AchievementMedal(
        id: 'tasks_created_1',
        trail: AchievementTrailId.tasksCreated,
        threshold: 1,
        title: 'Primeira Tarefa'
      ),
      AchievementMedal(
        id: 'tasks_created_10',
        trail: AchievementTrailId.tasksCreated,
        threshold: 10,
        title: 'Entusiasta das Tarefas'
      ),
      AchievementMedal(
        id: 'tasks_created_25',
        trail: AchievementTrailId.tasksCreated,
        threshold: 25,
        title: 'Organizador Iniciante'
      ),
      AchievementMedal(
        id: 'tasks_created_50',
        trail: AchievementTrailId.tasksCreated,
        threshold: 50,
        title: 'Planejador Dedicado'
      ),
      AchievementMedal(
        id: 'tasks_created_100',
        trail: AchievementTrailId.tasksCreated,
        threshold: 100,
        title: 'O Tarefador'
      ),
      AchievementMedal(
        id: 'tasks_created_250',
        trail: AchievementTrailId.tasksCreated,
        threshold: 250,
        title: 'Arquiteto das Tarefas'
      ),
      AchievementMedal(
        id: 'tasks_created_500',
        trail: AchievementTrailId.tasksCreated,
        threshold: 500,
        title: 'Mestre da Organização'
      ),
      AchievementMedal(
        id: 'tasks_created_1000',
        trail: AchievementTrailId.tasksCreated,
        threshold: 1000,
        title: 'Imperador das Tarefas'
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Tarefas Não Concluídas — no máximo 1 ponto por dia civil.
  //
  // Conta quando o dia vira e havia tarefa agendada para aquele dia ainda
  // pendente. Várias pendências no mesmo dia = 1 ponto só. Se a data da
  // tarefa for movida para um dia posterior antes da contabilização do dia,
  // essa tarefa é descartada daquele dia.
  // ---------------------------------------------------------------------------
  static const unfinishedTasksTrail = AchievementTrail(
    id: AchievementTrailId.unfinishedTasks,
    title: 'Tarefas Não Concluídas',
    summary:
        'Conta os dias em que você deixou tarefas pendentes para trás.',
    medals: [
      AchievementMedal(
        id: 'unfinished_1',
        trail: AchievementTrailId.unfinishedTasks,
        threshold: 1,
        title: 'Primeira Pendência'
      ),
      AchievementMedal(
        id: 'unfinished_5',
        trail: AchievementTrailId.unfinishedTasks,
        threshold: 5,
        title: 'Vou Ver Isso'
      ),
      AchievementMedal(
        id: 'unfinished_10',
        trail: AchievementTrailId.unfinishedTasks,
        threshold: 10,
        title: 'Colecionador de Afazeres'
      ),
      AchievementMedal(
        id: 'unfinished_20',
        trail: AchievementTrailId.unfinishedTasks,
        threshold: 20,
        title: 'Lista Crescente'
      ),
      AchievementMedal(
        id: 'unfinished_35',
        trail: AchievementTrailId.unfinishedTasks,
        threshold: 35,
        title: 'Acumulador de Tarefas'
      ),
      AchievementMedal(
        id: 'unfinished_50',
        trail: AchievementTrailId.unfinishedTasks,
        threshold: 50,
        title: 'Rei das Pendências'
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Adiantamentos de Tarefas — 1 ponto por adiantamento qualificado.
  //
  // A data deve avançar (nunca retroceder). A edição só conta se ocorrer
  // após 1 h da criação da tarefa.
  // ---------------------------------------------------------------------------
  static const taskAdvancesTrail = AchievementTrail(
    id: AchievementTrailId.taskAdvances,
    title: 'Adiantamentos de Tarefas',
    summary:
        'Ganhe pontos ao adiantar tarefas para dias futuros. Só contam '
        'adiantamentos feitos mais de 1 hora depois da criação da tarefa.',
    medals: [
      AchievementMedal(
        id: 'advance_1',
        trail: AchievementTrailId.taskAdvances,
        threshold: 1,
        title: 'Primeiro Adiamento'
      ),
      AchievementMedal(
        id: 'advance_10',
        trail: AchievementTrailId.taskAdvances,
        threshold: 10,
        title: 'Vou Fazer Depois'
      ),
      AchievementMedal(
        id: 'advance_25',
        trail: AchievementTrailId.taskAdvances,
        threshold: 25,
        title: 'Remarcador Iniciante'
      ),
      AchievementMedal(
        id: 'advance_50',
        trail: AchievementTrailId.taskAdvances,
        threshold: 50,
        title: 'Mestre do "Já Já"'
      ),
      AchievementMedal(
        id: 'advance_100',
        trail: AchievementTrailId.taskAdvances,
        threshold: 100,
        title: 'Especialista em Reagendamentos'
      ),
      AchievementMedal(
        id: 'advance_150',
        trail: AchievementTrailId.taskAdvances,
        threshold: 150,
        title: 'Especialista em Adiamentos'
      ),
      AchievementMedal(
        id: 'advance_250',
        trail: AchievementTrailId.taskAdvances,
        threshold: 250,
        title: 'Senhor do Amanhã'
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Dias Concluídos — 1 ponto por dia em que todas as tarefas foram concluídas.
  //
  // Avaliado às 23:50 do dia (não no momento em que a última tarefa é marcada).
  // ---------------------------------------------------------------------------
  static const daysCompletedTrail = AchievementTrail(
    id: AchievementTrailId.daysCompleted,
    title: 'Dias Concluídos',
    summary:
        'Recompensa os dias em que você conclui todas as tarefas agendadas. '
        'A verificação acontece ao final do dia.',
    medals: [
      AchievementMedal(
        id: 'days_completed_1',
        trail: AchievementTrailId.daysCompleted,
        threshold: 1,
        title: 'Primeiro Dia'
      ),
      AchievementMedal(
        id: 'days_completed_10',
        trail: AchievementTrailId.daysCompleted,
        threshold: 10,
        title: 'Executor Iniciante'
      ),
      AchievementMedal(
        id: 'days_completed_25',
        trail: AchievementTrailId.daysCompleted,
        threshold: 25,
        title: 'Caçador de Pendências'
      ),
      AchievementMedal(
        id: 'days_completed_50',
        trail: AchievementTrailId.daysCompleted,
        threshold: 50,
        title: 'Planejador Nato'
      ),
      AchievementMedal(
        id: 'days_completed_100',
        trail: AchievementTrailId.daysCompleted,
        threshold: 100,
        title: 'Domador de Afazeres'
      ),
      AchievementMedal(
        id: 'days_completed_250',
        trail: AchievementTrailId.daysCompleted,
        threshold: 250,
        title: 'Mestre da Consistência'
      ),
      AchievementMedal(
        id: 'days_completed_500',
        trail: AchievementTrailId.daysCompleted,
        threshold: 500,
        title: 'Lenda da Produtividade'
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Pilhas Criadas — 1 ponto por pilha criada.
  // ---------------------------------------------------------------------------
  static const pilhasCreatedTrail = AchievementTrail(
    id: AchievementTrailId.pilhasCreated,
    title: 'Pilhas Criadas',
    summary:
        'Empilhe suas tarefas para organizar melhor o dia e avançar nesta trilha.',
    medals: [
      AchievementMedal(
        id: 'pilha_1',
        trail: AchievementTrailId.pilhasCreated,
        threshold: 1,
        title: 'Primeira Pilha'
      ),
      AchievementMedal(
        id: 'pilha_5',
        trail: AchievementTrailId.pilhasCreated,
        threshold: 5,
        title: 'Empilhador Iniciante'
      ),
      AchievementMedal(
        id: 'pilha_10',
        trail: AchievementTrailId.pilhasCreated,
        threshold: 10,
        title: 'Organizador de Pilhas'
      ),
      AchievementMedal(
        id: 'pilha_25',
        trail: AchievementTrailId.pilhasCreated,
        threshold: 25,
        title: 'Empilhador Nato'
      ),
      AchievementMedal(
        id: 'pilha_50',
        trail: AchievementTrailId.pilhasCreated,
        threshold: 50,
        title: 'Máquina Empilhadora'
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Magic Input — 1 ponto por tarefa criada via entrada inteligente.
  // ---------------------------------------------------------------------------
  static const magicInputTrail = AchievementTrail(
    id: AchievementTrailId.magicInput,
    title: 'Magic Input',
    summary:
        'Use o Magic Input para criar tarefas falando ou digitando. Cada tarefa criada por esse atalho vale 1 ponto.',
    medals: [
      AchievementMedal(
        id: 'magic_1',
        trail: AchievementTrailId.magicInput,
        threshold: 1,
        title: 'Primeiro Comando'
      ),
      AchievementMedal(
        id: 'magic_5',
        trail: AchievementTrailId.magicInput,
        threshold: 5,
        title: 'Tradutor de Ideias'
      ),
      AchievementMedal(
        id: 'magic_10',
        trail: AchievementTrailId.magicInput,
        threshold: 10,
        title: 'Atalho Mental'
      ),
      AchievementMedal(
        id: 'magic_25',
        trail: AchievementTrailId.magicInput,
        threshold: 25,
        title: 'Domador de Comandos'
      ),
      AchievementMedal(
        id: 'magic_50',
        trail: AchievementTrailId.magicInput,
        threshold: 50,
        title: 'Mestre da Automação'
      ),
      AchievementMedal(
        id: 'magic_100',
        trail: AchievementTrailId.magicInput,
        threshold: 100,
        title: 'Orquestrador de Bots'
      ),
      AchievementMedal(
        id: 'magic_250',
        trail: AchievementTrailId.magicInput,
        threshold: 250,
        title: 'Oráculo das Tarefas'
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Conquistas lendárias — eventos raros e muito específicos (1 ponto cada).
  // ---------------------------------------------------------------------------
  static const curiositiesTrail = AchievementTrail(
    id: AchievementTrailId.curiosities,
    title: 'Conquistas lendárias',
    summary:
        'Medalhas para feitos muito específicos — cada uma exige um momento '
        'únimo, fora das trilhas comuns.',
    medals: [
      AchievementMedal(
        id: 'curiosity_flag_day',
        trail: AchievementTrailId.curiosities,
        threshold: 1,
        title: 'Ordem e progresso',
        customMilestoneLabel: 'Criar uma tarefa no dia da bandeira',
      ),
    ],
  );

  static List<AchievementMedal> medalsForTrail(AchievementTrailId trail) {
    return trailsById[trail]?.medals ?? const [];
  }

  static Set<String> unlockedMedalIds(Map<AchievementTrailId, int> points) {
    final unlocked = <String>{};
    for (final trail in trails) {
      if (!AchievementTrailFlags.isEnabled(trail.id)) continue;
      final score = points[trail.id] ?? 0;
      for (final medal in trail.medals) {
        if (score >= medal.threshold) {
          unlocked.add(medal.id);
        }
      }
    }
    return unlocked;
  }
}
