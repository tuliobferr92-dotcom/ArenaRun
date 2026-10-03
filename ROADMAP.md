# REINOS — Roadmap

Ordem de prioridade (seção 64 do briefing), sem pular etapas:

```
CORE GAME ENGINE → MAP ENGINE → TURN SYSTEM → BATTLE ENGINE → OBJECTIVES → CARDS
→ BOT → BIBLE KNOWLEDGE LAYER → POLISH → MULTIPLAYER
```

## Fase 1 — Fundação + Core Loop Jogável (ESTE ENTREGÁVEL)
- Projeto Flutter compilando, arquitetura de pastas, design system inicial.
- Modelos de domínio, `GameState`, `GameAction`, `GamePhase` (state machine).
- `GameEngine`, `BattleEngine` (RNG seedado), `ReinforcementCalculator`, `ObjectiveEngine` simples.
- Mapa simplificado (12-20 territórios, subconjunto do vertical slice), adjacency graph em JSON.
- UI: seleção de território, zoom/pan, 2-4 jogadores (humano + bot simples), HUD mínimo.
- Setup → posicionamento inicial → reforços → ataque → dados → conquista → movimentação → fim de turno.
- Condição de vitória simples (controlar N territórios) e fim de jogo.
- Testes unitários da engine, analyzer limpo, app executando.

## Fase 2 — Vertical Slice Polido
- Conjunto de territórios da seção 52 (16 cidades), validação histórica antes de tratar como mapa final.
- Cartas territoriais completas com metadados bíblicos, troca de combinações.
- Cartas de evento (Reconstrução, Sabedoria, Tempo de Fartura) com efeitos via `RulesConfig`.
- Animações de batalha completas (seção 15), domínio regional, pass-and-play.
- Save/load de partida, debug mode.

## Fase 3 — Bot Avançado + Objetivos completos
- `BotStrategy` avaliando fronteiras, risco, cartas, probabilidade (seção 38).
- Todos os tipos de objetivo (`controlSpecificTerritories`, `eliminatePlayer`, `hybrid`).
- Dificuldades (Fácil/Normal/Difícil/Especialista) via qualidade de decisão, nunca via RNG trapaceado.

## Fase 4 — Camada de Conhecimento Bíblico
- `BibleChallengeEngine`, Codex/Enciclopédia, Timeline, descoberta de território, Biblical Knowledge Score.
- Spaced repetition (`KnowledgeProfile`), conquistas (Achievement System), tela "Sua Jornada" pós-partida.
- Pipeline editorial `GENERATED_CONTENT → REVIEWED_CONTENT → PUBLISHED_CONTENT` operacional.

## Fase 5 — Polish
- Áudio (`AudioManager`), haptics, acessibilidade completa, localização PT/EN/ES, performance (60fps,
  layers separadas), design system completo, analytics (`AnalyticsService`).

## Fase 6 — Multiplayer
- Ações serializáveis já existentes desde a Fase 1 ganham transporte real (WebSocket), servidor
  autoritativo para dados/cartas/objetivos/vitória, reconexão com snapshot + replay de `actionHistory`.
- Modo Igreja (salas privadas), ranking, torneios.

## Mapas futuros (arquitetura já suporta, conteúdo entra por fase)
Terras Bíblicas (Fase 1-2) · Reinos de Israel · Impérios · Novo Testamento · Viagens de Paulo · Êxodo.

## Fora de escopo agora (explicitamente adiado)
Multiplayer online real, economia/monetização, conquistas extensas, todos os mapas, IA de bot avançada,
conteúdo bíblico extenso — todos modelados na arquitetura, nenhum implementado em profundidade na Fase 1.
