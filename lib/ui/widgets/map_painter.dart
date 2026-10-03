import 'package:flutter/material.dart';

import '../../game_engine/domain/territory.dart';
import '../../game_engine/state/game_state.dart';
import '../design_system/tokens.dart';

/// Renders the map in separate layers (terrain/borders/ownership/armies) so
/// a single army-count change never forces a full-map rebuild — section 58.
/// Phase 1 keeps terrain/borders static and only re-paints ownership+armies
/// each state change, via `shouldRepaint`.
class MapPainter extends CustomPainter {
  final GameState state;
  final String? selectedTerritoryId;

  /// A territory that just changed hands, pulsing briefly as "special
  /// conquest" feedback (section 15/17), plus how far into that pulse
  /// animation (0..1, one full glow cycle) the current frame is.
  final String? pulsingTerritoryId;
  final double pulseValue;

  MapPainter({
    required this.state,
    required this.selectedTerritoryId,
    this.pulsingTerritoryId,
    this.pulseValue = 0,
  });

  static const double mapWidth = 1000;
  static const double mapHeight = 700;

  Offset _scale(Size size, double x, double y) {
    final sx = size.width / mapWidth;
    final sy = size.height / mapHeight;
    final s = sx < sy ? sx : sy;
    return Offset(x * s, y * s);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = ReinosColors.surface;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final dominatedTerritoryIds = _computeDominatedTerritoryIds();
    for (final territory in state.territories.values) {
      _paintTerritory(canvas, size, territory, dominatedTerritoryIds.contains(territory.id));
    }
  }

  /// Territories belonging to a region a single player fully controls
  /// (section 17 "Domínio Regional") — recomputed live from current
  /// ownership every paint, so the highlight always matches reality even
  /// after a save/load or a region changing hands.
  Set<String> _computeDominatedTerritoryIds() {
    final dominated = <String>{};
    for (final region in state.regions.values) {
      if (region.territoryIds.isEmpty) continue;
      final owner = state.territories[region.territoryIds.first]?.ownerId;
      if (owner == null) continue;
      final controlled =
          region.territoryIds.every((id) => state.territories[id]?.ownerId == owner);
      if (controlled) dominated.addAll(region.territoryIds);
    }
    return dominated;
  }

  void _paintTerritory(Canvas canvas, Size size, Territory territory, bool isDominated) {
    final path = Path();
    final points = territory.polygon.map((p) => _scale(size, p.dx, p.dy)).toList();
    path.addPolygon(points, true);

    final ownerColorIndex = _ownerColorIndex(territory.ownerId);
    final fillColor = ownerColorIndex != null
        ? ReinosColors.playerColors[ownerColorIndex].withValues(alpha: 0.75)
        : ReinosColors.bronze.withValues(alpha: 0.3);

    canvas.drawPath(path, Paint()..color = fillColor);

    final borderPaint = Paint()
      ..color = territory.id == selectedTerritoryId
          ? ReinosColors.gold
          : ReinosColors.parchment.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = territory.id == selectedTerritoryId ? 3 : 1.2;
    canvas.drawPath(path, borderPaint);

    if (isDominated) {
      canvas.drawPath(
        path,
        Paint()
          ..color = ReinosColors.gold.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    if (territory.id == pulsingTerritoryId) {
      final glowOpacity = (1 - (pulseValue - 0.5).abs() * 2).clamp(0.0, 1.0);
      canvas.drawPath(
        path,
        Paint()
          ..color = ReinosColors.gold.withValues(alpha: 0.9 * glowOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
    }

    final center = _scale(size, territory.centroid.dx, territory.centroid.dy);

    final namePainter = TextPainter(
      text: TextSpan(
        text: territory.name,
        style: const TextStyle(
          color: ReinosColors.parchment,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    namePainter.paint(canvas, Offset(center.dx - namePainter.width / 2, center.dy - 22));

    final armyPainter = TextPainter(
      text: TextSpan(
        text: '${territory.armyCount}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRadius = 12.0;
    canvas.drawCircle(center, badgeRadius, Paint()..color = Colors.black.withValues(alpha: 0.55));
    armyPainter.paint(
      canvas,
      Offset(center.dx - armyPainter.width / 2, center.dy - armyPainter.height / 2),
    );
  }

  int? _ownerColorIndex(String? ownerId) {
    if (ownerId == null) return null;
    final index = state.players.indexWhere((p) => p.id == ownerId);
    if (index < 0) return null;
    return index % ReinosColors.playerColors.length;
  }

  /// Hit-test in the same normalized coordinate space used for painting.
  static String? territoryAt(GameState state, Size size, Offset localPosition) {
    final sx = size.width / mapWidth;
    final sy = size.height / mapHeight;
    final s = sx < sy ? sx : sy;
    final mapX = localPosition.dx / s;
    final mapY = localPosition.dy / s;

    for (final territory in state.territories.values) {
      if (_pointInPolygon(mapX, mapY, territory.polygon)) {
        return territory.id;
      }
    }
    return null;
  }

  static bool _pointInPolygon(double x, double y, List<dynamic> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].dx, yi = polygon[i].dy;
      final xj = polygon[j].dx, yj = polygon[j].dy;
      final intersects = ((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.selectedTerritoryId != selectedTerritoryId ||
        oldDelegate.pulsingTerritoryId != pulsingTerritoryId ||
        oldDelegate.pulseValue != pulseValue;
  }
}
