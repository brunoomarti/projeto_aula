import 'extract_when_pt_br.dart';
import 'nlp_icon_palette.dart';

/// Ícone e cor inferidos a partir do texto bruto (digitação ou voz).
class InferTaskIconResult {
  const InferTaskIconResult({
    required this.iconKey,
    required this.backgroundArgb,
  });

  final String iconKey;
  final int backgroundArgb;
}

class _IconRule {
  const _IconRule({
    required this.iconKey,
    required this.pattern,
    this.weight = 2,
  });

  final String iconKey;
  final String pattern;
  final int weight;
}

/// Chave usada quando nenhum tema é reconhecido.
const kGenericTaskIconKey = 'task';

/// Ordem de desempate — categorias mais específicas primeiro.
const _kIconTieBreakOrder = [
  'health',
  'pets',
  'beauty',
  'clothing',
  'swimming',
  'ball_sports',
  'gym',
  'faith',
  'study',
  'travel',
  'repair',
  'leisure',
  'event',
  'work',
  'food',
  'shopping',
  'market',
  'people',
  'walk',
  'tree',
  'home',
  kGenericTaskIconKey,
];

/// Índices em [NlpIconPalette.backgroundArgbs] compatíveis com cada ícone.
const _kIconColorIndices = <String, List<int>>{
  'home': [0, 11],
  'gym': [1, 2],
  'ball_sports': [10, 5, 1],
  'swimming': [8, 5, 10],
  'market': [1, 2, 3],
  'shopping': [1, 2, 3],
  'food': [3, 6, 9],
  'people': [0, 5, 10],
  'tree': [1, 2, 8],
  'walk': [1, 8, 2],
  'work': [5, 10, 0],
  'study': [5, 10, 0],
  'health': [4, 7, 8],
  'pets': [6, 9, 3],
  'travel': [5, 8, 10],
  'event': [3, 7, 10],
  'leisure': [8, 3, 10],
  'repair': [6, 9, 4],
  'clothing': [7, 0, 11],
  'beauty': [7, 4, 0],
  'faith': [10, 0, 5],
  kGenericTaskIconKey: [11, 0],
};

/// Regras por tema — padrões aplicados sobre texto normalizado ([normPT]).
const _kRules = <_IconRule>[
  // Casa / lar
  _IconRule(iconKey: 'home', pattern: r'\b(casa|lar|apartamento|apto|condominio)\b', weight: 3),
  _IconRule(iconKey: 'home', pattern: r'\b(faxina|aspirar|varrer|organizar\s+casa|arrumar\s+casa)\b', weight: 3),
  _IconRule(iconKey: 'home', pattern: r'\b(lavar\s+louca|louca|limpar\s+casa|limpeza\s+domestica)\b', weight: 3),
  _IconRule(iconKey: 'home', pattern: r'\b(mudanca|mudar\s+de\s+casa|portaria|chaves)\b', weight: 2),
  _IconRule(iconKey: 'home', pattern: r'\b(boleto\s+do\s+condominio|condominio)\b', weight: 2),

  // Academia / exercício
  _IconRule(iconKey: 'gym', pattern: r'\b(academia|gym|crossfit|pilates|yoga|musculacao)\b', weight: 3),
  _IconRule(iconKey: 'gym', pattern: r'\b(treino|treinar|malhar|exercicio|exercicios|halter|halteres)\b', weight: 2),
  _IconRule(iconKey: 'gym', pattern: r'\b(alongamento|funcional|spinning|bike\s+ergometrica)\b', weight: 2),

  // Esportes com bola
  _IconRule(iconKey: 'ball_sports', pattern: r'\b(futebol|futsal|soccer|pelada|rachao|rachão|partida\s+de\s+futebol)\b', weight: 4),
  _IconRule(iconKey: 'ball_sports', pattern: r'\b(basquete|basket|basketball|volei|vôlei|handebol|handball)\b', weight: 4),
  _IconRule(iconKey: 'ball_sports', pattern: r'\b(tenis|tênis|beach\s+tennis|pingue\s+pongue|ping\s*pong|tenis\s+de\s+mesa)\b', weight: 3),
  _IconRule(iconKey: 'ball_sports', pattern: r'\b(jogo\s+de\s+bola|esporte\s+com\s+bola|bater\s+bola|treino\s+de\s+(?:futebol|basquete|volei|vôlei|handebol|tenis|tênis))\b', weight: 4),

  // Shopping / compras gerais
  _IconRule(iconKey: 'shopping', pattern: r'\b(shopping|shoppings|mall|centro comercial|centro\s+de\s+compras)\b', weight: 3),
  _IconRule(iconKey: 'shopping', pattern: r'\b(ir\s+(?:ao|no|na|pro|pra|em)|passar\s+(?:no|na|pelo))\s+shopping\b', weight: 3),
  _IconRule(iconKey: 'shopping', pattern: r'\b(compras\s+no\s+shopping|comprar\s+roupa|lojas)\b', weight: 2),

  // Mercado / supermercado
  _IconRule(iconKey: 'market', pattern: r'\b(supermercado|mercado|feira|hortifruti|mercearia)\b', weight: 3),
  _IconRule(iconKey: 'market', pattern: r'\b(fazer\s+mercado|compras\s+do\s+mes|lista\s+de\s+compras)\b', weight: 3),
  _IconRule(iconKey: 'market', pattern: r'\b(comprar\s+presente|presente|gas\s+de\s+cozinha|botijao|botijao\s+de\s+gas)\b', weight: 2),
  _IconRule(iconKey: 'market', pattern: r'\b(comprar|compras|sacola|sacolas|carrinho)\b', weight: 1),

  // Comida / refeições
  _IconRule(iconKey: 'food', pattern: r'\b(restaurante|jantar|almoco|lanche|café da\s+manha|cafe\s+da\s+manha)\b', weight: 3),
  _IconRule(iconKey: 'food', pattern: r'\b(pizza|hamburguer|sushi|delivery|ifood|rappi|pedir\s+comida)\b', weight: 3),
  _IconRule(iconKey: 'food', pattern: r'\b(cozinhar|receita|assar|fazer\s+comida|refeicao|refeicoes)\b', weight: 2),
  _IconRule(iconKey: 'food', pattern: r'\b(padaria|acougue|açougue|sorvete|doceria|cafeteria)\b', weight: 2),
  _IconRule(iconKey: 'food', pattern: r'\b(comida|comer|jantar\s+com|almocar|café|cafe)\b', weight: 1),

  // Pessoas / social
  _IconRule(iconKey: 'people', pattern: r'\b(visitar\s+(pais|mae|pai|avo|avó|familia|família|amigos))\b', weight: 3),
  _IconRule(iconKey: 'people', pattern: r'\b(encontro|encontrar\s+com|familia|família|amigos|parentes)\b', weight: 2),
  _IconRule(iconKey: 'people', pattern: r'\b(churrasco|confraternizacao|jantar\s+com|almoco\s+com)\b', weight: 2),
  _IconRule(iconKey: 'people', pattern: r'\b(ligar\s+para|telefonar\s+para|mandar\s+mensagem\s+para)\b', weight: 1),

  // Natureza
  _IconRule(iconKey: 'tree', pattern: r'\b(parque|natureza|jardim|plantas|plantar|muda|mudas|horta)\b', weight: 3),
  _IconRule(iconKey: 'tree', pattern: r'\b(camping|acampar|trilha\s+ecologica|picnic|piquenique)\b', weight: 2),

  // Caminhada / passeio
  _IconRule(iconKey: 'walk', pattern: r'\b(caminhada|caminhar|passeio|passear|andar\s+no\s+parque)\b', weight: 3),
  _IconRule(iconKey: 'walk', pattern: r'\b(trilha|hiking|correr|corrida|jogging)\b', weight: 2),

  // Trabalho
  _IconRule(iconKey: 'work', pattern: r'\b(trabalho|escritorio|office|cliente|projeto|deadline)\b', weight: 3),
  _IconRule(iconKey: 'work', pattern: r'\b(reuniao|reunião|meeting|apresentacao|apresentação|relatorio|relatório)\b', weight: 3),
  _IconRule(iconKey: 'work', pattern: r'\b(entrega\s+do\s+cliente|enviar\s+relatorio|email\s+profissional|slack|discord)\b', weight: 2),
  _IconRule(iconKey: 'work', pattern: r'\b(backup\s+dos\s+arquivos|organizar\s+documentos|documentos\s+do\s+trabalho)\b', weight: 2),

  // Estudo
  _IconRule(iconKey: 'study', pattern: r'\b(estudar|estudo|prova|faculdade|universidade|escola|aula)\b', weight: 3),
  _IconRule(iconKey: 'study', pattern: r'\b(curso|ingles|inglês|concurso|redacao|redação|tcc|monografia)\b', weight: 3),

  // Natação
  _IconRule(iconKey: 'swimming', pattern: r'\b(natação|natacao|nadar|aula\s+de\s+natação|aula\s+de\s+natacao)\b', weight: 4),
  _IconRule(iconKey: 'swimming', pattern: r'\b(piscina|hidroginastica|hidroginástica|treino\s+de\s+natação|treino\s+de\s+natacao)\b', weight: 3),

  // Saúde
  _IconRule(iconKey: 'health', pattern: r'\b(dentista|medico|médico|hospital|clinica|clínica|consulta)\b', weight: 3),
  _IconRule(iconKey: 'health', pattern: r'\b(exame|farmacia|farmácia|remedio|remédio|vacina)\b', weight: 3),
  _IconRule(iconKey: 'health', pattern: r'\b(fisioterapia|psicologo|psicólogo|terapia|plano\s+de\s+saude)\b', weight: 2),
  _IconRule(iconKey: 'health', pattern: r'\b(agendar\s+exame|marcar\s+dentista|marcar\s+medico)\b', weight: 3),

  // Pets
  _IconRule(iconKey: 'pets', pattern: r'\b(pet|pets|cachorro|gato|veterinario|veterinário|vet)\b', weight: 3),
  _IconRule(iconKey: 'pets', pattern: r'\b(racao|ração|banho\s+e\s+tosa|passear\s+com\s+o\s+cachorro|passeio\s+com\s+o\s+cachorro)\b', weight: 3),

  // Viagem
  _IconRule(iconKey: 'travel', pattern: r'\b(viagem|voar|voo|passagem|aeroporto|hotel|mala)\b', weight: 3),
  _IconRule(iconKey: 'travel', pattern: r'\b(turismo|rodoviaria|onibus|ônibus|ferry|cruzeiro)\b', weight: 2),
  _IconRule(iconKey: 'travel', pattern: r'\b(comprar\s+passagens|reservar\s+hotel|check\s*in)\b', weight: 2),

  // Eventos (formais / programados)
  _IconRule(iconKey: 'event', pattern: r'\b(evento|show|teatro|concerto|espetaculo|espetáculo)\b', weight: 3),
  _IconRule(iconKey: 'event', pattern: r'\b(aniversario|aniversário|casamento|formatura|convenção|convencao)\b', weight: 3),
  _IconRule(iconKey: 'event', pattern: r'\b(ingresso|ingressos)\b', weight: 2),

  // Lazer — saídas, cinema, festas e tempo livre
  _IconRule(iconKey: 'leisure', pattern: r'\b(cinema|ir\s+ao\s+cinema|sessao\s+de\s+cinema|sessão\s+de\s+cinema|filme\s+no\s+cinema)\b', weight: 4),
  _IconRule(iconKey: 'leisure', pattern: r'\b(sair\s+com\s+amigos|saída\s+com\s+amigos|sair\s+a\s+noite|sair\s+hoje\s+a\s+noite|rol[eê]|night\s+out)\b', weight: 4),
  _IconRule(iconKey: 'leisure', pattern: r'\b(festa|balada|boate|bar|pub|boteco|happy\s+hour|drinks|cerveja\s+com\s+amigos)\b', weight: 3),
  _IconRule(iconKey: 'leisure', pattern: r'\b(lazer|tempo\s+livre|hobby|hobbies|descanso|descansar|relaxar)\b', weight: 3),
  _IconRule(iconKey: 'leisure', pattern: r'\b(videogame|video\s+game|jogar\s+online|playstation|xbox|nintendo|steam|fortnite|minecraft)\b', weight: 3),
  _IconRule(iconKey: 'leisure', pattern: r'\b(netflix|serie|série|maratonar|assistir\s+serie|assistir\s+série|streaming|disney\+|prime\s+video|hbo)\b', weight: 3),
  _IconRule(iconKey: 'leisure', pattern: r'\b(passear|dia\s+off|folga)\b', weight: 2),

  // Manutenção / conserto
  _IconRule(iconKey: 'repair', pattern: r'\b(conserto|consertar|manutencao|manutenção|reparo|reparar)\b', weight: 3),
  _IconRule(iconKey: 'repair', pattern: r'\b(revisao\s+do\s+carro|revisão\s+do\s+carro|mecanico|mecânico|oficina)\b', weight: 3),
  _IconRule(iconKey: 'repair', pattern: r'\b(encanador|eletricista|notebook\s+para\s+conserto|conserto\s+do\s+notebook)\b', weight: 3),
  _IconRule(iconKey: 'repair', pattern: r'\b(agendar\s+revisao|trocar\s+oleo|trocar\s+óleo|pneu|pneus)\b', weight: 2),

  // Roupa
  _IconRule(iconKey: 'clothing', pattern: r'\b(roupa|roupas|lavanderia|costura|alfaiate)\b', weight: 3),
  _IconRule(iconKey: 'clothing', pattern: r'\b(passar\s+roupa|dobrar\s+roupa|cabide|closet|guarda\s+roupa)\b', weight: 3),
  _IconRule(iconKey: 'clothing', pattern: r'\b(pegar\s+roupas|buscar\s+roupas|trocar\s+de\s+roupa)\b', weight: 2),

  // Beleza
  _IconRule(iconKey: 'beauty', pattern: r'\b(cabelo|cortar\s+cabelo|salao|salão|barbearia|barbeiro)\b', weight: 3),
  _IconRule(iconKey: 'beauty', pattern: r'\b(manicure|pedicure|spa|maquiagem|estetica|estética|depilar)\b', weight: 3),
  _IconRule(iconKey: 'beauty', pattern: r'\b(corte\s+de\s+cabelo|escova|progressiva|hidratacao\s+capilar)\b', weight: 2),

  // Fé / igreja / adoração
  _IconRule(iconKey: 'faith', pattern: r'\b(igreja|igrejas|culto|cultos|missa|missas)\b', weight: 3),
  _IconRule(iconKey: 'faith', pattern: r'\b(adoracao|adoração|louvor|louvores|culto\s+de\s+louvor)\b', weight: 3),
  _IconRule(iconKey: 'faith', pattern: r'\b(biblia|bíblia|estudo\s+biblico|estudo\s+bíblico|palavra\s+de\s+deus)\b', weight: 4),
  _IconRule(iconKey: 'faith', pattern: r'\b(oracao|oração|orar|rezar|intercessao|intercessão|jejum)\b', weight: 3),
  _IconRule(iconKey: 'faith', pattern: r'\b(batismo|comunhao|comunhão|escola\s+dominical|ebd)\b', weight: 3),
  _IconRule(iconKey: 'faith', pattern: r'\b(cristianismo|cristao|cristão|evangelho|seminario|seminário)\b', weight: 2),
  _IconRule(iconKey: 'faith', pattern: r'\b(jesus|cristo|deus|pastor|padre|bispo|diacono|diácono)\b', weight: 2),
  _IconRule(iconKey: 'faith', pattern: r'\b(célula|celula)\s+(da\s+)?igreja\b', weight: 3),
];

int _pickColorArgb(String iconKey, String seed) {
  final indices = _kIconColorIndices[iconKey] ?? _kIconColorIndices[kGenericTaskIconKey]!;
  final idx = indices[seed.hashCode.abs() % indices.length];
  return NlpIconPalette.backgroundArgbs[idx];
}

int _tieBreakPriority(String iconKey) {
  final i = _kIconTieBreakOrder.indexOf(iconKey);
  return i >= 0 ? i : _kIconTieBreakOrder.length;
}

/// Infere ícone e cor a partir do transcript completo (antes da limpeza de título).
InferTaskIconResult inferTaskIconPTBR(String transcript) {
  final normalized = normPT(transcript);
  if (normalized.trim().isEmpty) {
    return InferTaskIconResult(
      iconKey: kGenericTaskIconKey,
      backgroundArgb: _pickColorArgb(kGenericTaskIconKey, transcript),
    );
  }

  final scores = <String, int>{};

  for (final rule in _kRules) {
    if (RegExp(rule.pattern).hasMatch(normalized)) {
      scores[rule.iconKey] = (scores[rule.iconKey] ?? 0) + rule.weight;
    }
  }

  if (scores.isEmpty) {
    return InferTaskIconResult(
      iconKey: kGenericTaskIconKey,
      backgroundArgb: _pickColorArgb(kGenericTaskIconKey, transcript),
    );
  }

  var bestKey = kGenericTaskIconKey;
  var bestScore = -1;
  var bestPriority = _kIconTieBreakOrder.length;

  for (final entry in scores.entries) {
    final priority = _tieBreakPriority(entry.key);
    if (entry.value > bestScore ||
        (entry.value == bestScore && priority < bestPriority)) {
      bestScore = entry.value;
      bestKey = entry.key;
      bestPriority = priority;
    }
  }

  return InferTaskIconResult(
    iconKey: bestKey,
    backgroundArgb: _pickColorArgb(bestKey, transcript),
  );
}
