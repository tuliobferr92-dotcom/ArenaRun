# REINOS — Tasks (Fase 1)

## Fundação
- [x] Analisar especificação completa e documentar decisões (ARCHITECTURE.md, GAME_RULES.md, ROADMAP.md, BIBLE_CONTENT_GUIDELINES.md)
- [x] `flutter create` + estrutura de pastas (`game_engine`, `data`, `content`, `services`, `animations`, `multiplayer`, `ui`)
- [x] Design system inicial (tokens de cor/spacing/tipografia)

## Domínio
- [x] `Territory`, `Region`, `HistoricalPeriod`, `GameMap`
- [x] `Player`, `TerritoryCard`, `Objective`
- [x] `RulesConfig` carregado de JSON

## Engine
- [x] `GameState` imutável + serialização
- [x] `GameAction` (sealed) — Place, Reinforce, Attack, MoveArmy, PlayCard, EndPhase/EndTurn
- [x] `GamePhase` state machine + validação de transições
- [x] `SeededRandom` determinístico
- [x] `BattleEngine` (dados, resolução, conquista)
- [x] `ReinforcementCalculator` (territórios + bônus de região)
- [x] `ObjectiveEngine` (controlTerritoryCount, controlRegions)
- [x] `BotStrategy` simples (sem trapaça de RNG)
- [x] `GameEngine` (reducer central ligando tudo)

## Mapa / Conteúdo
- [x] `data/maps/biblical_lands_v1.json` com subconjunto do vertical slice (16 territórios)
- [x] `data/rules/default_rules.json`
- [x] `ContentRepository` carregando assets

## UI
- [x] `MapPainter` (CustomPainter, layers separadas) + gestos (tap/zoom/pan)
- [x] HUD de partida (fase, reforços, jogador atual, botão avançar fase)
- [x] Tela Home mínima, Setup (escolher nº jogadores), Game, Game Over
- [x] Riverpod ligando `GameEngine` à UI (nenhuma regra em widget)

## Qualidade
- [x] Testes unitários do `game_engine` (reforços, adjacência, ataque inválido, dados, conquista, turnos, objetivos, vitória)
- [x] `flutter analyze` sem erros
- [x] `flutter test` passando
- [x] App buildando (`flutter build apk --debug` ou equivalente / `flutter run` smoke test)
- [x] Documentar o que funciona e o que ficou para a Fase 2

## Resultado da verificação (Fase 1)

- `flutter analyze` → **0 problemas**.
- `flutter test` → **114/114 testes passando** (reforços, RNG seedado, batalha/dados,
  validação de adjacência/ações inválidas, conquista, ciclo de turno completo,
  objetivos, eliminação/vitória por sobrevivência).
- **Simulação de partida completa** (`test/game_engine/simulation_test.dart`): 90 partidas
  simuladas (2/3/4 bots × 30 seeds) no mapa de produção real (`biblical_lands_v1.json`),
  cada bot jogando via `BotStrategy` do início ao fim sem intervenção humana. Todas as 90
  terminam em `GamePhase.gameOver` com um vencedor válido, sem soft-locks, sem exceções e
  sem duplicação de exércitos (`totalArmies` conservado). Esse é o teste mais forte de que
  o core loop funciona de fato — um teste unitário isolado pode passar mesmo que uma partida
  real trave ou nunca termine.
- `flutter build web --release` → **compila com sucesso** (usado como verificação de
  compilação de ponta a ponta; o alvo real do produto é iOS/Android — não há
  Android SDK, Xcode, Chrome ou GTK3-dev disponíveis neste ambiente headless para
  rodar em um emulador/dispositivo real ou mesmo abrir a build web em um navegador,
  já que o CDN do CanvasKit é bloqueado pela política de rede do sandbox). A build
  web real em um navegador com rede liberada, e a build mobile real, precisam ser
  validadas em um ambiente de desenvolvimento com Android SDK/Xcode.
- Um bug real foi encontrado e corrigido durante essa verificação: o `SeededRandom`
  original (splitmix64) usava literais de 64 bits que perdem precisão ao compilar
  para JavaScript; foi reescrito como `xorshift32` (apenas shifts/XOR), determinístico
  em qualquer backend (VM, AOT, JS/Wasm) — essencial para o requisito de replay
  determinístico entre plataformas (ARCHITECTURE.md seção 9).

## Fase 2 (parcial) — Save/Load + Debug Mode

- [x] Serialização JSON completa de `GameState` (`toJson`/`fromJson`), incluindo
  `Objective`, `TerritoryCard`, `Player`, `RulesConfig` e o estado exato do RNG
  (`SeededRandom.fromState`) — uma partida restaurada produz a mesma sequência de
  dados que teria produzido sem nunca ter sido salva.
- [x] `SaveGameService` (abstração) + `FileSaveGameService` (implementação em
  arquivo local via `path_provider`): salvar, carregar, listar, apagar.
- [x] Home: botão "CONTINUAR PARTIDA" mostra o save mais recente e carrega.
- [x] Tela de jogo: botão "Salvar e sair" no HUD.
- [x] Debug Mode (`kDebugMode` apenas — ausente de builds release): dar tropas,
  conquistar território instantaneamente, saltar fase, dar carta, completar
  objetivo (vencer), resetar partida.
- [x] Teste de round-trip de serialização + RNG restaurado continua a mesma
  sequência de dados do original.
- **Bug real encontrado e corrigido durante a verificação:** `Territory.fromJson`
  nunca lia `ownerId`/`armyCount` do JSON (só `toJson` os escrevia) — todo território
  restaurado de um save voltava sem dono. Só apareceu ao testar o round-trip
  completo, não nos testes unitários anteriores (que nunca serializavam territórios
  com `ownerId` já atribuído antes do bug existir).
- Suite completa: **116/116 testes passando**, `flutter analyze` limpo.

## Fase 2 (parcial) — Cartas territoriais + Animações de batalha

- [x] `CardRarity` (cosmético) + baralho com 2 coringas; `RulesConfig.cardTradeInSequence`
  (recompensa escalável, compartilhada entre jogadores) carregado de `default_rules.json`.
- [x] `PlayCardAction` no `GameEngine`: só na fase de Reforços, exatamente 3 cartas, valida
  trinca/conjunto com coringas preenchendo lacunas, aplica recompensa a `pendingReinforcements`.
- [x] UI: botão de cartas no HUD (badge com contagem), `CardHandSheet` para selecionar e trocar,
  erro do engine mostrado como snackbar em vez de falhar silenciosamente.
- [x] Bot troca cartas automaticamente (`BotStrategy.decideCardTradeIn`) — exercido pelos 90
  jogos simulados em `simulation_test.dart`, que continuam todos passando.
- [x] 8 testes de engine cobrindo combos válidos/inválidos, coringa, fase errada, nº errado de
  cartas e escalonamento de recompensa através de múltiplas trocas.
- [x] `BattleSequenceOverlay` (seção 15): ícone de dados girando → revelação dos dados →
  comparação par a par com cor (verde/vermelho) → resumo de perdas → faixa de conquista; haptics
  (`HapticFeedback`) e hooks de som (`AudioService`/`NoOpAudioService`, sem assets reais ainda).
  A engine nunca espera a animação — o resultado já está definitivo em `GameState` antes dela
  começar a tocar.
- [x] Pulso dourado no próprio mapa sobre o território recém-conquistado, após a overlay fechar.
- [x] 6 testes de widget cobrindo as fases da sequência, banner de conquista condicional, botão
  "Pular" e ordem dos eventos de som — com cuidado explícito para nunca deixar um `Timer`
  pendente (usar `Timer` cancelável em vez de uma cadeia de `Future.delayed`).
- Suite completa: **130/130 testes passando**, `flutter analyze` limpo, `flutter build web`
  compilando.

## Fase 2 (parcial) — Domínio Regional

- [x] `GameState.newlyDominatedRegionId` (transiente, mesmo padrão de `activeBattle`):
  `GameEngine` o define quando uma conquista completa o controle de uma região que o jogador
  ainda não controlava por completo, comparando posse antes/depois do ataque.
- [x] `MapPainter` destaca persistentemente, a cada frame, qualquer região atualmente controlada
  por um único jogador (recomputado a partir da posse real, sobrevive a save/load).
- [x] `RegionalDominanceBanner`: comemoração "👑 DOMÍNIO REGIONAL" com o bônus de reforço,
  auto-dispensável, mostrada após a overlay de batalha quando a conquista completa uma região.
- [x] 3 testes de engine (detecção, não repetir para região já controlada, sem falso positivo) +
  2 testes de widget (conteúdo, dismiss por toque).
- Suite completa: **135/135 testes passando**, analyzer limpo.

## Fase 3 — Objetivos completos + Bot avançado

- [x] `ObjectiveEngine` implementa os 5 tipos da seção 18: `eliminatePlayer` (alvo concreto
  atribuído na criação, nunca "qualquer rival") e `hybrid` (todas as sub-condições, avaliadas
  recursivamente). `GameEngine.newMatch` distribui os 5 tipos ciclicamente entre os jogadores.
- [x] `PlayerConfig`/`Player` carregam `BotDifficulty`; `SetupScreen` deixa escolher a
  dificuldade dos bots.
- [x] `BotStrategy` fica de fato mais forte com a dificuldade, sem nunca tocar no RNG: limiar de
  vantagem numérica para atacar (fácil aceita desvantagem, normal/difícil/especialista cada vez
  mais exigentes); difícil/especialista evitam deixar o território de origem exposto a outros
  vizinhos inimigos (mas nunca recusam o único ataque legal disponível — ver bug abaixo);
  reforços priorizam a fronteira mais ameaçada (mais vizinhos inimigos) em vez de só a mais fraca.
- [x] 16 testes novos (9 de objetivos + 7 de bot/dificuldade), incluindo um teste explícito que
  prova que nenhuma função do bot nunca altera `SeededRandom.state`.
- **Soft-lock real encontrado e corrigido pela própria simulação de 90 partidas:** a primeira
  versão do limiar "especialista" (margem ≥ 3) combinada com a verificação de risco fazia bots
  especialistas nunca atacarem em alguns tabuleiros equilibrados, travando a partida para sempre
  (nunca chegava a `gameOver` dentro do limite de ações do teste). Corrigido alinhando o limiar
  especialista ao de difícil (ambos ≥ 2, diferenciados pela avaliação de risco e priorização de
  reforço) e garantindo que a avaliação de risco **nunca** recuse o único ataque legal disponível
  — prefere seguro quando há opção, mas sempre age quando não há.
- Suite completa: **151/151 testes passando**, analyzer limpo, build web compilando.

## Fase 4 (parcial) — Camada de Conhecimento Bíblico

- [x] `BibleChallenge` (pergunta de múltipla escolha) + `ContentReviewStatus`
  (`generated`/`reviewed`/`published`) — `ContentRepository` só entrega itens `published`.
- [x] Primeiro lote real em `data/content/bible_challenges.json`: 18 perguntas cobrindo 16
  territórios, cada uma reusando uma referência já existente no mapa (nenhum fato novo
  inventado). Marcado honestamente como pendente de revisão humana
  (`sourceMetadata.humanReviewed: false`) — ver `BIBLE_CONTENT_GUIDELINES.md`.
- [x] `BibleChallengeEngine` (seleção pura: próximo desafio não respondido para um território).
- [x] `GameState.discoveredTerritoryIds` (partida inteira) + `newlyDiscoveredTerritoryId`
  (transiente, mesmo padrão de `newlyDominatedRegionId`), marcado pelo `GameEngine` na primeira
  conquista de cada território. `AnswerChallengeAction` registra a resposta sem o engine nunca
  julgar conteúdo bíblico — isso é decidido na camada de conteúdo antes da ação ser despachada.
- [x] UI: `DiscoveryBanner` (seção 30, "aprendizado invisível" — nunca força uma pergunta,
  sempre "continuar jogando" vs. "ver agora") + `BibleChallengeDialog` opcional encadeados após a
  animação de batalha e o banner de domínio regional, nessa ordem, nunca simultâneos.
- [x] "Sua Jornada" (seção 31) na tela de fim de jogo: turnos, territórios descobertos, desafios
  respondidos corretamente, lista dos territórios descobertos.
- [x] 19 testes novos (10 de engine/conteúdo + 3 de validação do JSON semente + 6 de widget).
- Suite completa: **170/170 testes passando**, analyzer limpo, build web compilando.

## Fora desta fase (ver ROADMAP.md)
- [ ] Cartas de evento (Reconstrução, Sabedoria, Tempo de Fartura)
- [ ] Codex/Enciclopédia completo, Timeline visual, Biblical Knowledge Score por categoria,
  spaced repetition (seções 25/28/32/33) — a base de dados e o pipeline editorial já existem;
  falta a UI de navegação e o cálculo de progresso por categoria.
- [ ] Revisão editorial humana real do lote de conteúdo bíblico (ver nota acima)
- [ ] Pass-and-play (ocultar informação privada ao trocar de jogador no mesmo aparelho)
- [ ] Multiplayer real, áudio real (assets), acessibilidade, localização
