/// Full match state machine (section 12). The UI never branches on
/// anything but this enum + [GameEngine.legalActions]; all transition rules
/// live in `GameEngine`.
enum GamePhase {
  lobby,
  setup,
  initialPlacement,
  turnStart,
  reinforcement,
  attack,
  battle,
  conquest,
  fortification,
  cardReward,
  turnEnd,
  gameOver,
}
