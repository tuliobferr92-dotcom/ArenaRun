import 'package:reinos_engine/game_engine/state/game_state.dart';

/// Pure gating logic for the pass-and-play interstitial (section 56),
/// pulled out of `GameScreen` so it's testable without pumping the whole
/// widget tree. True whenever more than one human shares this device and
/// the current player is a different human than the one who last
/// confirmed "ESTOU PRONTO".
bool needsPassAndPlay(GameState state, String? revealedPlayerId) {
  final humanCount = state.players.where((p) => !p.isBot).length;
  return humanCount > 1 &&
      !state.currentPlayer.isBot &&
      state.currentPlayer.id != revealedPlayerId;
}
