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
- Trocas de combinações de cartas (3 símbolos iguais ou 1 de cada) concedem reforços conforme
  `cardTradeInValues`, aplicáveis no início do próprio turno de reforços.
- Checagem de condição de vitória (`ObjectiveEngine.isComplete`) e de eliminação.
- Passa a vez ao próximo jogador vivo.

## Eliminação e vitória
- Jogador sem territórios é eliminado; suas cartas voltam ao fundo do deck.
- Vitória por: objetivo secreto completo, OU único jogador restante no mapa (fallback de dominação total).

## Objetivos secretos (Fase 1)
- `controlTerritoryCount(n)`: controlar N territórios simultaneamente.
- `controlRegions([ids])`: controlar todas as regiões listadas por completo.
- Extensões futuras (`controlSpecificTerritories`, `eliminatePlayer`, `hybrid`) já modeladas na engine,
  ativadas em fases posteriores.

## Bot (Fase 1)
Avalia, em ordem: progresso do próprio objetivo → fronteiras fracas do inimigo mais vulnerável →
ataque com vantagem numérica mínima configurável. O bot nunca influencia o RNG dos dados.
