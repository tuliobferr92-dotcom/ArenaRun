import 'package:flutter/material.dart';

import '../../game_engine/state/game_state.dart';
import 'map_painter.dart';

/// The protagonist of the screen (section 69). Wraps `MapPainter` with
/// pinch-zoom/pan (`InteractiveViewer`) and tap-to-select (section 53).
class MapView extends StatefulWidget {
  final GameState state;
  final String? selectedTerritoryId;
  final ValueChanged<String> onTerritoryTap;

  const MapView({
    super.key,
    required this.state,
    required this.selectedTerritoryId,
    required this.onTerritoryTap,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return InteractiveViewer(
        transformationController: _transformController,
        minScale: 0.8,
        maxScale: 4,
        child: GestureDetector(
          onTapUp: (details) {
            final id = MapPainter.territoryAt(widget.state, size, details.localPosition);
            if (id != null) widget.onTerritoryTap(id);
          },
          child: CustomPaint(
            size: size,
            painter: MapPainter(
              state: widget.state,
              selectedTerritoryId: widget.selectedTerritoryId,
            ),
          ),
        ),
      );
    });
  }
}
