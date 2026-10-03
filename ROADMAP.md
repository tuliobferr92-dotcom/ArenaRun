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

## Fase 6 — Multiplayer (núcleo implementado)
- [x] `game_engine` extraído para pacote Dart puro (`packages/reinos_engine`), compartilhado entre
  app e servidor.
- [x] `GameAction.toJson()`/`gameActionFromJson` — serialização completa das 8 ações, base do
  protocolo de rede e do action log.
- [x] Servidor WebSocket autoritativo (`server/`) — cria salas por código, aplica toda ação via o
  mesmo `GameEngine.apply`, conduz bots sozinho, rejeita ação em nome de outro jogador.
- [x] `NetworkClient` (app) + modo online do `GameController` — mesma API pública dos dois modos
  (local e online), `GameScreen` não precisa saber qual está ativo.
- [x] UI online mínima: criar sala (gera código) / entrar com código — MVP de 2 assentos fixos.
- [x] Deploy: Dockerfile (AOT) + instruções Fly.io/Render/Railway/VPS.
- [ ] Reconexão após queda de conexão (snapshot + replay de `actionHistory` já é possível, falta
  o fluxo de UI de "reconectando...").
- [ ] Mais de 2 assentos / bots em salas online (a engine já suporta N jogadores; falta só o lobby).
- [ ] Modo Igreja (salas privadas com contexto de congregação), ranking, torneios.

## Mapas futuros (arquitetura já suporta, conteúdo entra por fase)
Terras Bíblicas (Fase 1-2) · Reinos de Israel · Impérios · Novo Testamento · Viagens de Paulo · Êxodo.

## Fora de escopo agora (explicitamente adiado)
Economia/monetização, conquistas extensas, todos os mapas, conteúdo bíblico extenso, mais de 2
assentos em salas online, reconexão automática — todos modelados na arquitetura, nenhum
implementado em profundidade ainda. (Multiplayer online básico saiu desta lista — ver Fase 6.)
