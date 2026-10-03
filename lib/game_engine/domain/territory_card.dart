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

  Map<String, dynamic> toJson() => {
        'id': id,
        'territoryId': territoryId,
        'symbol': symbol.name,
      };

  factory TerritoryCard.fromJson(Map<String, dynamic> json) {
    return TerritoryCard(
      id: json['id'] as String,
      territoryId: json['territoryId'] as String,
      symbol: CardSymbol.values.byName(json['symbol'] as String),
    );
  }
}
