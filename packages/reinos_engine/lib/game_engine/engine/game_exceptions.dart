/// Thrown whenever a [GameAction] is attempted outside the phase/ownership
/// rules that allow it. Never fail silently — section 6/44.
class InvalidActionException implements Exception {
  final String reason;
  const InvalidActionException(this.reason);

  @override
  String toString() => 'InvalidActionException: $reason';
}
