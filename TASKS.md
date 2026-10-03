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

## Fora desta fase (ver ROADMAP.md)
- [ ] Cartas de evento completas, troca de cartas territoriais
- [ ] Animações de batalha completas, domínio regional visual
- [ ] Biblical Knowledge layer, Codex, Timeline, challenges
- [ ] Pass-and-play (ocultar informação privada ao trocar de jogador no mesmo aparelho)
- [ ] Multiplayer real, áudio, haptics, acessibilidade, localização
