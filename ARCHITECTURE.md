# REINOS — Arquitetura Técnica

## 1. Decisão de Stack

**Framework: Flutter (Dart) + CustomPainter para o mapa.**

Análise feita antes de escrever código, conforme pedido:

| Necessidade | Solução escolhida | Por quê |
|---|---|---|
| Mapa interativo (zoom/pan/tap, centenas de elementos) | `CustomPainter` + `Matrix4`/`InteractiveViewer` próprio | Territórios de REINOS são polígonos estáticos com poucas centenas de vértices totais, não uma cena de física. `CustomPainter` com `RepaintBoundary` por layer resolve isso em 60fps sem motor de jogo. |
| Animações (bandeiras, tropas, cartas, partículas simples) | `AnimationController` + `Tween` + `CustomPainter`; `Lottie`/`Rive` para ilustrações complexas (brasões, logo) | Lottie/Rive cobrem arte animada feita por designers; não precisamos de física de partículas pesada. |
| Dados 3D | `CustomPainter` com projeção isométrica simples (matriz 2D) ou pacote leve de partículas (`flutter_confetti`-like caseiro) | Não há necessidade de engine 3D real para dados de tabuleiro; um efeito 2.5D é suficiente e muito mais leve. |
| Drag & drop, gestos | `GestureDetector`/`Listener` nativos do Flutter | Suficiente; não precisa de física de corpo rígido. |
| Multiplayer futuro | Camada de `GameAction` serializável + engine pura em Dart, desacoplada de UI | Permite rodar a mesma engine no cliente e, futuramente, em um servidor Dart (ou via WebSocket relay) sem reescrever regras. |

**Conclusão:** Flutter puro é suficiente. **Não introduzimos Flame** nesta fase — ele é pensado para game loops de sprites/física contínua (plataforma, tiles, colisão), que não é o nosso caso (jogo de tabuleiro por turnos). Se no futuro quisermos efeitos de partícula muito mais ricos (ex: fogo, areia animada em larga escala), podemos adicionar Flame **apenas na camada de efeitos visuais**, nunca na engine de regras. Revisaremos essa decisão ao final da Fase "Polish".

Pacotes de terceiros usados nesta fundação (todos populares, mantidos, sem assets protegidos):
- `flutter_riverpod` — gerenciamento de estado (GameState como fonte única da verdade, fora dos widgets).
- `freezed` + `json_serializable` — modelos imutáveis e serialização (save game, replay de ações).
- `uuid` — ids de entidades.

## 2. Separação de Camadas (pastas)

```
lib/
  game_engine/        # Núcleo puro Dart, sem Flutter, sem UI. Regras do jogo.
    domain/            # Entidades: Territory, Region, GameMap, Player, Card, Objective...
    state/             # GameState, GamePhase (state machine), GameAction
    engine/            # GameEngine (reducer), ReinforcementCalculator, BattleEngine, 
                        # ObjectiveEngine, BotStrategy, RulesConfig
    rng/               # SeededRandom determinístico (dice rolls replayáveis)
  data/                 # Fontes de conteúdo: maps/*.json, cards/*.json, bible content repository
  content/              # ContentRepository (abstração sobre data/), BibleChallengeEngine
  services/             # AudioService, HapticsService, AnalyticsService, SaveGameService (abstrações)
  animations/           # Controllers e specs de animação de batalha/conquista/descoberta
  multiplayer/          # Interfaces (ActionLog, NetworkTransport) — stubs por agora
  ui/
    design_system/       # tokens: cores, spacing, tipografia, radius
    screens/              # home, setup, game, game_over
    widgets/              # MapView (CustomPainter), HUD, dialogs
  app.dart / main.dart
test/
  game_engine/           # testes unitários da engine (prioridade máxima)
```

Regra inegociável: **nenhuma regra de jogo vive em um widget.** Widgets apenas leem `GameState` (via Riverpod) e despacham `GameAction` para o `GameEngine`. O `GameEngine` é testável sem Flutter (`dart test`, sem dependência de `flutter_test` nesse pacote).

## 3. Entidades principais (Fase 1 — subconjunto necessário, extensível)

- `Territory { id, name, regionId, polygon, centroid, neighbors[], ownerId?, armyCount, biblicalReferences[], historicalPeriodId, description }`
- `Region { id, name, territoryIds[], controlBonus }`
- `HistoricalPeriod { id, name, description }` — permite múltiplos mapas/períodos no futuro sem reescrever `Territory`.
- `GameMap { id, name, periodId, territories: Map<id,Territory>, regions: Map<id,Region> }`
- `Player { id, displayName, color, isBot, botDifficulty?, territoryIds[], cardIds[], objectiveId, wisdomPoints, xp, connectionStatus }`
- `TerritoryCard { id, territoryId, symbol, rarity }` (versão Fase 1; metadados bíblicos completos entram na Fase de conteúdo)
- `Objective` (tipos: `controlTerritoryCount`, `controlRegions`, `controlSpecificTerritories`, `eliminatePlayer`, `hybrid`)

Todos os modelos são **imutáveis** (`freezed`), com `copyWith` — nunca mutação direta, essencial para replay/undo/multiplayer futuro.

## 4. GameState (fonte única da verdade)

```dart
class GameState {
  final String gameId;
  final String mapId;
  final List<Player> players;
  final Map<String, Territory> territories; // territoryId -> Territory (ownerId, armyCount embutidos)
  final int currentPlayerIndex;
  final GamePhase phase;
  final int turnNumber;
  final List<TerritoryCard> deck;
  final List<TerritoryCard> discardPile;
  final BattleState? activeBattle;
  final int pendingReinforcements;
  final List<GameAction> actionHistory; // replay completo
  final int rngSeed; // estado do RNG determinístico
  final String? winnerId;
}
```

`GameState` é serializável (`toJson`/`fromJson`) → base do save game e de snapshots de reconexão.

## 5. GameAction (serializável, auditável)

Classe base `sealed class GameAction` (padrão Command), cada uma com `gameId, playerId, timestamp, sequenceNumber, payload`:

- `PlaceArmyAction` (setup/initial placement)
- `ReinforceAction`
- `AttackAction { fromTerritoryId, toTerritoryId, troopCount }`
- `RollDiceAction` (apenas usada internamente/replay; o resultado vem do `SeededRandom`, nunca do client em multiplayer futuro)
- `MoveArmyAction` (fortificação)
- `PlayCardAction`
- `EndPhaseAction` / `EndTurnAction`

Todas as ações passam por `GameEngine.apply(state, action) -> GameState` — função pura, testável, e a base para o action log / replay completo (requisito de multiplayer futuro e servidor autoritativo).

## 6. State Machine de partida

```
LOBBY -> SETUP -> INITIAL_PLACEMENT -> TURN_START -> REINFORCEMENT -> ATTACK -> (BATTLE <-> ATTACK)
   -> FORTIFICATION -> CARD_REWARD -> TURN_END -> (próximo jogador -> TURN_START | GAME_OVER)
```

Implementada como enum `GamePhase` + função `GameEngine.canTransition(phase, action)`; qualquer ação fora da fase permitida é rejeitada com erro tipado (`InvalidActionException`), nunca silenciosamente ignorada — fundamental para depuração e testes.

## 7. Formato de dados do mapa (JSON, fora do código)

`data/maps/biblical_lands_v1.json`:
```json
{
  "id": "biblical_lands_v1",
  "name": "Terras Bíblicas",
  "periodId": "patriarchs_conquest",
  "regions": [ { "id": "canaa", "name": "Canaã", "controlBonus": 3, "territoryIds": ["jerusalem","jerico", ...] } ],
  "territories": [
    {
      "id": "jerico", "name": "Jericó", "regionId": "canaa",
      "neighbors": ["jerusalem", "betel"],
      "polygon": [[x,y], ...], "centroid": [x,y],
      "biblicalReferences": ["Joshua 6"], "historicalPeriodId": "conquest"
    }
  ]
}
```
Carregado por `ContentRepository` (interface) → implementação Fase 1 lê de `assets/`; implementação futura pode ler de um backend/CMS sem tocar na engine.

## 8. RulesConfig (nada hardcoded)

```dart
class RulesConfig {
  final int minReinforcements;
  final int territoriesPerReinforcement;
  final Map<String, int> regionControlBonus; // override por mapa
  final int maxDiceAttacker;
  final int maxDiceDefender;
  final Map<CardComboType, int> cardTradeInValues;
  final Map<int, int> wisdomAbilityCosts;
}
```
Carregado de `data/rules/default_rules.json`. `GameEngine` recebe `RulesConfig` injetado — nunca lê constantes mágicas no meio da lógica.

## 9. Riscos técnicos identificados

1. **Performance do mapa com muitos territórios** — mitigar com `RepaintBoundary` por layer (terrain/territories/borders/ownership/armies/effects) e redesenho apenas da layer afetada.
2. **Determinismo do RNG entre client/servidor** — resolvido desde já com `SeededRandom` próprio (não usar `Random()` do Dart diretamente na engine).
3. **Conteúdo bíblico incorreto/teológico-sensível** — mitigado pela separação `GENERATED_CONTENT / REVIEWED_CONTENT / PUBLISHED_CONTENT` (ver `BIBLE_CONTENT_GUIDELINES.md`); nenhum conteúdo `GENERATED` chega ao jogador.
4. **Acoplamento UI↔regras** — mitigado por `game_engine` ser um pacote Dart puro (sem import de `package:flutter`), testável isoladamente.
5. **Escopo gigantesco da especificação** — mitigado pela priorização estrita (seção `TASKS.md`), entregando primeiro o *core loop* jogável antes de qualquer polish, bot avançado, multiplayer ou conteúdo bíblico extenso.
6. **Flutter SDK não pré-instalado no ambiente de build** — resolvido nesta sessão via clone do SDK (`stable` channel); deixar documentado para CI/outros ambientes.

## 10. Multiplayer / segurança futura (preparação, não implementação)

- Toda decisão de RNG, cartas e objetivos fica **dentro do `GameEngine`**, nunca no widget — pré-requisito para mover a autoridade para um servidor sem reescrever regras.
- `actionHistory` em `GameState` permite replay determinístico completo a partir do estado inicial + seed.
- Interfaces (`NetworkTransport`, `ActionLog`) ficam em `lib/multiplayer/` como contratos vazios nesta fase.
