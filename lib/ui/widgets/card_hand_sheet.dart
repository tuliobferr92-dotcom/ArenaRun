import 'package:flutter/material.dart';

import '../../game_engine/domain/territory_card.dart';
import '../design_system/tokens.dart';

IconData _symbolIcon(CardSymbol symbol) {
  switch (symbol) {
    case CardSymbol.shield:
      return Icons.shield;
    case CardSymbol.flame:
      return Icons.local_fire_department;
    case CardSymbol.scroll:
      return Icons.description;
    case CardSymbol.wildcard:
      return Icons.auto_awesome;
  }
}

Color _rarityColor(CardRarity rarity) {
  switch (rarity) {
    case CardRarity.common:
      return ReinosColors.bronze;
    case CardRarity.rare:
      return ReinosColors.gold;
    case CardRarity.legendary:
      return ReinosColors.accent;
  }
}

/// Lets the player review their hand and pick exactly 3 cards to trade in
/// (section 19). Combo validity is decided by `GameEngine` — this sheet
/// only enforces "pick 3" so the trade-in button enables, and surfaces the
/// engine's rejection message if the combo turns out invalid.
class CardHandSheet extends StatefulWidget {
  final List<TerritoryCard> cards;
  final String? tradeInError;
  final void Function(List<String> cardIds) onTradeIn;

  const CardHandSheet({
    super.key,
    required this.cards,
    required this.onTradeIn,
    this.tradeInError,
  });

  @override
  State<CardHandSheet> createState() => _CardHandSheetState();
}

class _CardHandSheetState extends State<CardHandSheet> {
  final Set<String> _selected = {};

  void _toggle(String cardId) {
    setState(() {
      if (_selected.contains(cardId)) {
        _selected.remove(cardId);
      } else if (_selected.length < 3) {
        _selected.add(cardId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ReinosSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📖 Suas Cartas Territoriais', style: ReinosTypography.heading),
          const SizedBox(height: ReinosSpacing.sm),
          Text(
            'Selecione 3 cartas para trocar por reforços (3 iguais, ou 3 símbolos diferentes).',
            style: ReinosTypography.label,
          ),
          const SizedBox(height: ReinosSpacing.md),
          if (widget.cards.isEmpty)
            Text('Nenhuma carta ainda.', style: ReinosTypography.body)
          else
            Wrap(
              spacing: ReinosSpacing.sm,
              runSpacing: ReinosSpacing.sm,
              children: widget.cards.map((card) {
                final isSelected = _selected.contains(card.id);
                return GestureDetector(
                  onTap: () => _toggle(card.id),
                  child: Container(
                    width: 72,
                    padding: const EdgeInsets.all(ReinosSpacing.sm),
                    decoration: BoxDecoration(
                      color: ReinosColors.background,
                      borderRadius: BorderRadius.circular(ReinosRadius.sm),
                      border: Border.all(
                        color: isSelected ? ReinosColors.gold : _rarityColor(card.rarity),
                        width: isSelected ? 3 : 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(_symbolIcon(card.symbol), color: _rarityColor(card.rarity)),
                        const SizedBox(height: 4),
                        Text(
                          card.territoryId.isEmpty ? 'Coringa' : card.territoryId,
                          style: ReinosTypography.label,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          if (widget.tradeInError != null) ...[
            const SizedBox(height: ReinosSpacing.sm),
            Text(widget.tradeInError!, style: const TextStyle(color: ReinosColors.danger)),
          ],
          const SizedBox(height: ReinosSpacing.md),
          FilledButton(
            onPressed: _selected.length == 3 ? () => widget.onTradeIn(_selected.toList()) : null,
            child: const Text('TROCAR POR REFORÇOS'),
          ),
        ],
      ),
    );
  }
}
