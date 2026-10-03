import 'package:reinos/game_engine/domain/game_map.dart';
import 'package:reinos/game_engine/domain/region.dart';
import 'package:reinos/game_engine/domain/rules_config.dart';
import 'package:reinos/game_engine/domain/territory.dart';
import 'package:reinos/game_engine/engine/game_engine.dart';
import 'package:reinos/game_engine/domain/player_color.dart';
import 'package:reinos/game_engine/state/game_state.dart';

/// Small synthetic 4-territory map used by engine tests: a linear chain
/// `t1 - t2 - t3 - t4`, split into two 2-territory regions. Kept separate
/// from `data/maps/*.json` so engine tests never depend on Flutter assets.
GameMap buildTestMap() {
  Territory t(String id, List<String> neighbors, String regionId) {
    return Territory(
      id: id,
      name: id,
      regionId: regionId,
      neighborIds: neighbors,
      polygon: const [Offset2D(0, 0), Offset2D(1, 0), Offset2D(1, 1), Offset2D(0, 1)],
      centroid: const Offset2D(0.5, 0.5),
      biblicalReferences: const [],
      historicalPeriodId: 'test',
      description: '',
    );
  }

  final territories = {
    't1': t('t1', ['t2'], 'regionA'),
    't2': t('t2', ['t1', 't3'], 'regionA'),
    't3': t('t3', ['t2', 't4'], 'regionB'),
    't4': t('t4', ['t3'], 'regionB'),
  };

  return GameMap(
    id: 'test_map',
    name: 'Test Map',
    periodId: 'test',
    regions: {
      'regionA': const Region(id: 'regionA', name: 'Region A', territoryIds: ['t1', 't2'], controlBonus: 2),
      'regionB': const Region(id: 'regionB', name: 'Region B', territoryIds: ['t3', 't4'], controlBonus: 2),
    },
    territories: territories,
  );
}

const testRules = RulesConfig(
  minReinforcements: 3,
  territoriesPerReinforcement: 3,
  maxDiceAttacker: 3,
  maxDiceDefender: 2,
  startingArmiesPerTerritory: 2,
  initialPlacementExtraArmies: 2,
  minTerritoriesForObjective: 3,
);

/// A freshly-created 2-player match on [buildTestMap], territories
/// distributed by [GameEngine.newMatch]'s deterministic shuffle.
GameState freshTestState({int seed = 42, int playerCount = 2}) {
  final configs = [
    for (var i = 0; i < playerCount; i++)
      PlayerConfig(id: 'p$i', displayName: 'Player $i', color: PlayerColor.values[i]),
  ];
  return GameEngine.newMatch(
    map: buildTestMap(),
    configs: configs,
    rules: testRules,
    seed: seed,
  );
}

/// Overrides ownership/army counts directly — bypasses engine mutation so
/// tests can set up arbitrary board positions without replaying actions.
GameState withOwnership(
  GameState state,
  Map<String, String?> owners,
  Map<String, int> armies,
) {
  final territories = Map.of(state.territories);
  for (final id in territories.keys.toList()) {
    final owner = owners.containsKey(id) ? owners[id] : territories[id]!.ownerId;
    final army = armies[id] ?? territories[id]!.armyCount;
    territories[id] = territories[id]!.copyWith(
      ownerId: owner,
      clearOwner: owner == null,
      armyCount: army,
    );
  }
  return state.copyWith(territories: territories);
}
