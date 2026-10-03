import 'package:flutter/material.dart';

import 'package:reinos_engine/game_engine/domain/event_card.dart';
import '../design_system/tokens.dart';

String _eventCardName(EventCardType type) {
  switch (type) {
    case EventCardType.reconstrucao:
      return 'Reconstrução';
    case EventCardType.sabedoria:
      return 'Sabedoria';
    case EventCardType.tempoDeFartura:
      return 'Tempo de Fartura';
  }
}

String _eventCardDescription(EventCardType type) {
  switch (type) {
    case EventCardType.reconstrucao:
      return 'Fortifica instantaneamente um território que você controla.';
    case EventCardType.sabedoria:
      return 'Concede reforços extras imediatos (só na fase de reforços).';
    case EventCardType.tempoDeFartura:
      return 'Compra uma carta territorial na hora, sem precisar conquistar.';
  }
}

IconData _eventCardIcon(EventCardType type) {
  switch (type) {
    case EventCardType.reconstrucao:
      return Icons.foundation;
    case EventCardType.sabedoria:
      return Icons.auto_stories;
    case EventCardType.tempoDeFartura:
      return Icons.agriculture;
  }
}

/// Lists the player's special event cards (section 20) and lets them play
/// one. `reconstrucao` needs a target territory the player already
/// controls — selected on the map beforehand — everything else can be
/// played immediately. Engine rejection messages (wrong phase, empty deck)
/// surface as a snackbar instead of failing silently.
class EventCardSheet extends StatelessWidget {
  final List<EventCard> eventCards;
  final String? selectedOwnTerritoryId;
  final void Function(String eventCardId, {String? targetTerritoryId}) onPlay;

  const EventCardSheet({
    super.key,
    required this.eventCards,
    required this.selectedOwnTerritoryId,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ReinosSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎁 Cartas Especiais', style: ReinosTypography.heading),
          const SizedBox(height: ReinosSpacing.sm),
          if (eventCards.isEmpty)
            Text(
              'Responda desafios bíblicos corretamente para ganhar cartas especiais.',
              style: ReinosTypography.body,
            )
          else
            ...eventCards.map((card) {
              final needsTarget = card.type == EventCardType.reconstrucao;
              final canPlay = !needsTarget || selectedOwnTerritoryId != null;
              return Card(
                color: ReinosColors.background,
                margin: const EdgeInsets.symmetric(vertical: ReinosSpacing.xs),
                child: ListTile(
                  leading: Icon(_eventCardIcon(card.type), color: ReinosColors.gold),
                  title: Text(_eventCardName(card.type)),
                  subtitle: Text(
                    needsTarget && selectedOwnTerritoryId == null
                        ? '${_eventCardDescription(card.type)} Selecione um território seu no mapa primeiro.'
                        : _eventCardDescription(card.type),
                    style: ReinosTypography.label,
                  ),
                  trailing: FilledButton(
                    onPressed: canPlay
                        ? () => onPlay(card.id, targetTerritoryId: selectedOwnTerritoryId)
                        : null,
                    child: const Text('Usar'),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
