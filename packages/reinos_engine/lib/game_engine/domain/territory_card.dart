enum CardSymbol { shield, flame, scroll, wildcard }

/// Deliberately cosmetic (section 19/68 — never gates power beyond the
/// trade-in reward table, which `RulesConfig` controls uniformly). Drives
/// only how a card is presented in the hand.
enum CardRarity { common, rare, legendary }

/// Territorial card (section 19). Biblical metadata (references, summary,
/// artwork) deliberately is *not* duplicated here — the card only stores
/// which [territoryId] it represents; the UI/Codex look that territory up
/// through `ContentRepository` for display, keeping a single source of
/// truth for biblical content (section 49).
class TerritoryCard {
  final String id;
  final String territoryId;
  final CardSymbol symbol;
  final CardRarity rarity;

  const TerritoryCard({
    required this.id,
    required this.territoryId,
    required this.symbol,
    this.rarity = CardRarity.common,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'territoryId': territoryId,
        'symbol': symbol.name,
        'rarity': rarity.name,
      };

  factory TerritoryCard.fromJson(Map<String, dynamic> json) {
    return TerritoryCard(
      id: json['id'] as String,
      territoryId: json['territoryId'] as String,
      symbol: CardSymbol.values.byName(json['symbol'] as String),
      rarity: json['rarity'] != null
          ? CardRarity.values.byName(json['rarity'] as String)
          : CardRarity.common,
    );
  }
}
