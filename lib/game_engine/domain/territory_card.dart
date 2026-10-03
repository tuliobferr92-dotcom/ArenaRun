enum CardSymbol { shield, flame, scroll, wildcard }

/// Territorial card (section 19). Full biblical metadata (artwork, rarity
/// tiers, educational content) is extended in a later phase — this is the
/// mechanical core needed for the card-trade-in loop.
class TerritoryCard {
  final String id;
  final String territoryId;
  final CardSymbol symbol;

  const TerritoryCard({
    required this.id,
    required this.territoryId,
    required this.symbol,
  });
}
