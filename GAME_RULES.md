# REINOS — Regras de Jogo (Fase 1 / Core Loop)

Estas regras cobrem a primeira versão jogável. Valores numéricos vêm de `RulesConfig`
(`data/rules/default_rules.json`) e podem ser rebalanceados sem alterar código.

## Setup
1. Mapa simplificado é dividido entre os jogadores (distribuição alternada de territórios).
2. Cada território começa com 1 exército.
3. Cada jogador recebe um objetivo secreto (`ObjectiveEngine.assign`).
4. `INITIAL_PLACEMENT`: jogadores distribuem exércitos extras iniciais, um por vez, em território próprio.

## Turno de um jogador

### Fase 1 — Reforços (`REINFORCEMENT`)
Reforços = `max(minReinforcements, floor(territoriesControlled / territoriesPerReinforcement)) + bônus de região`.
Bônus de região: `regionControlBonus[regionId]` para cada região inteiramente controlada pelo jogador.
O jogador distribui os reforços entre territórios próprios antes de avançar de fase.

### Fase 2 — Ataque (`ATTACK` / `BATTLE`)
- Território de origem deve ter `armyCount > 1` e ser adjacente a um território inimigo.
- Jogador escolhe quantidade de tropas atacantes (1 a `min(armyCount-1, maxDiceAttacker)`).
- `BattleEngine.resolve(attackerDice, defenderDice, seed)`:
  - Atacante rola até `maxDiceAttacker` dados (limitado pelas tropas enviadas).
  - Defensor rola até `maxDiceDefender` dados (limitado pelas tropas defensoras).
  - Dados ordenados decrescentemente e comparados par a par; maior vence; empate favorece defensor.
  - Perdas aplicadas imediatamente a ambos territórios.
- Se defensor chega a 0 exércitos: território é conquistado (`CONQUEST`), ownership transferido,
  parte das tropas atacantes move para o território conquistado (mínimo = tropas que venceram a rodada final).
- Jogador pode continuar atacando enquanto tiver tropas e territórios adjacentes elegíveis, ou declarar fim da fase.

### Fase 3 — Movimentação (`FORTIFICATION`)
- Uma movimentação de tropas entre dois territórios próprios conectados (adjacentes nesta fase 1;
  movimentação por cadeia de territórios próprios é extensão futura) por turno.
- Território de origem deve manter no mínimo 1 exército.

### Fase 4 — Finalização (`CARD_REWARD` / `TURN_END`)
- Se o jogador conquistou **ao menos um território** neste turno, recebe 1 `TerritoryCard` do topo do deck.
- Checagem de condição de vitória (`ObjectiveEngine.isComplete`) e de eliminação.
- Passa a vez ao próximo jogador vivo.

## Cartas territoriais e troca de combinações
- O baralho tem 1 carta por território (símbolo `shield`/`flame`/`scroll`, cíclico) + 2 cartas
  coringa (`wildcard`). Raridade (`common`/`rare`/`legendary`) é puramente cosmética — nunca altera
  o valor da troca.
- Trocas só podem acontecer **na fase de Reforços**, antes ou depois de distribuir os reforços
  recebidos por território (seção 19/20 do briefing).
- Uma troca sempre envolve **exatamente 3 cartas**. É válida se os símbolos não-coringa entre as 3
  forem **todos iguais** (trinca) ou **todos diferentes** (conjunto); coringas preenchem a lacuna
  para qualquer um dos dois casos. Duas iguais + uma diferente, sem coringa, é a única combinação
  invál­ida.
- A recompensa escala a cada troca **da partida inteira** (não por jogador), via
  `RulesConfig.cardTradeInSequence` (padrão: 4, 6, 8, 10, 12, 15) e, a partir daí,
  `cardTradeInIncrementAfterSequence` (padrão: +5) por troca adicional — nada hardcoded no engine.
- O bot troca automaticamente qualquer combinação válida que tiver em mãos, assim que possível.

## Eliminação e vitória
- Jogador sem territórios é eliminado; suas cartas voltam ao fundo do deck.
- Vitória por: objetivo secreto completo, OU único jogador restante no mapa (fallback de dominação total).

## Objetivos secretos
Todos os 5 tipos da seção 18 estão implementados:
- `controlTerritoryCount(n)`: controlar N territórios simultaneamente.
- `controlRegions([ids])`: controlar todas as regiões listadas por completo.
- `controlSpecificTerritories([ids])`: controlar uma lista explícita de territórios.
- `eliminatePlayer(targetPlayerId)`: eliminar um rival específico (sempre atribuído com um id
  concreto na criação da partida — nunca fica "em aberto"; eliminar qualquer rival não conta).
- `hybrid({conditions: [...]})`: **todas** as sub-condições devem valer simultaneamente — cada
  `condition` é `{type, params}` no mesmo formato de um objetivo normal, avaliada recursivamente.
- `GameEngine.newMatch` distribui os 5 tipos ciclicamente entre os jogadores para garantir
  variedade a cada partida.

## Cartas de evento (seção 20)
- Separadas das cartas territoriais. Não têm acquisição por conquista — são a recompensa por
  **responder corretamente** um desafio bíblico (liga mecanicamente o loop de aprendizado ao
  loop estratégico: GAME → CURIOSIDADE → DESCOBERTA → BÍBLIA → vantagem no jogo).
- Três tipos, efeitos configuráveis via `RulesConfig` (nunca hardcoded):
  - **Reconstrução** (tema: Neemias) — fortifica instantaneamente um território próprio
    (`+eventCardReconstrucaoBonus` exércitos). Exige escolher o território alvo.
  - **Sabedoria** (tema: Salomão) — concede `+eventCardSabedoriaBonus` reforços imediatos; só
    pode ser jogada durante a fase de Reforços.
  - **Tempo de Fartura** (tema: José) — compra uma carta territorial do topo do baralho na hora,
    sem precisar ter conquistado nada neste turno.
- Como em toda mecânica inspirada em temas bíblicos (ver `BIBLE_CONTENT_GUIDELINES.md` regra 3),
  o efeito de jogo nunca é apresentado como sendo literalmente o significado do texto.

## Domínio Regional (seção 17)
- O bônus de reforço por controlar uma região inteira (`Region.controlBonus`) já é recalculado
  a cada turno pelo `ReinforcementCalculator`, independente de qualquer flag — vale mesmo que o
  jogador tenha conquistado a região há vários turnos.
- Quando um ataque conquista o **último** território que faltava para completar o controle de
  uma região, o `GameEngine` marca `GameState.newlyDominatedRegionId` por uma única transição
  (como `activeBattle`, é só para a UI comemorar o momento — nunca re-sinaliza uma região que o
  jogador já controlava).
- O mapa também destaca de forma persistente, em todo frame, qualquer região atualmente
  controlada por um único jogador (recalculado ao vivo a partir da posse atual — sobrevive a
  save/load sem precisar de estado extra).

## Descoberta de territórios e desafios bíblicos (seções 22/24/30/31)
- Descoberta é de partida inteira, não por jogador: `GameState.discoveredTerritoryIds` registra
  todo território já conquistado alguma vez nesta partida. A primeira conquista de um território
  marca `newlyDiscoveredTerritoryId` por uma única transição (mesmo padrão transiente de
  `activeBattle`/`newlyDominatedRegionId`) — nunca re-dispara para o mesmo território.
- **Nunca uma pergunta por ataque.** O desafio bíblico só é oferecido no momento de descoberta, e
  é sempre opcional: "CONTINUAR JOGANDO" (padrão, sem fricção) ou "VER AGORA" (abre uma pergunta de
  múltipla escolha). Nenhuma ação de jogo depende da resposta.
- `AnswerChallengeAction` só registra que o jogador respondeu (certo ou errado) — o próprio
  `GameEngine` nunca julga a resposta; `BibleChallengeEngine.isCorrect` (camada de conteúdo) decide
  isso antes da ação ser despachada, mantendo `game_engine` livre de qualquer dependência de
  conteúdo bíblico.
- Cada jogador tem `answeredChallengeIds`/`correctChallengeAnswers`, usados na tela "Sua Jornada"
  pós-partida (territórios descobertos, desafios respondidos corretamente).

## Bot e dificuldade (seção 38)
- O bot nunca influencia o RNG dos dados — `BotStrategy` só decide **qual** ação pedir;
  `BattleEngine` sempre resolve os dados a partir do mesmo `SeededRandom` compartilhado.
- `BotDifficulty` (fácil/normal/difícil/especialista) muda a **qualidade da decisão**, nunca a sorte:
  - Vantagem numérica mínima para atacar: fácil aceita até desvantagem (-2), normal exige +1,
    difícil/especialista exigem +2.
  - Difícil/especialista evitam deixar o território de origem exposto a outros vizinhos inimigos
    depois do ataque (mede o "risco" comparando a guarnição restante com a soma das tropas
    inimigas vizinhas) — mas nunca recusam atacar para sempre: se o único ataque elegível for
    arriscado, atacam mesmo assim, para nunca travar a partida.
  - Reforços: fácil/normal reforçam a fronteira com menos tropas; difícil/especialista priorizam
    a fronteira com mais vizinhos inimigos (mais ameaçada), mesmo que tenha mais tropas.
  - O bot troca cartas territoriais automaticamente assim que tiver uma combinação válida.
