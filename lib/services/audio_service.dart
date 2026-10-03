/// Sound categories (section 40). Grouped the same way a future
/// `AudioManager` would mix/mute them independently (music, ambience, ui,
/// battle, dice, achievement, discovery).
enum SoundEvent {
  diceRoll,
  battleImpact,
  territoryConquered,
  cardDraw,
  achievementUnlocked,
  bibleDiscovery,
  uiTap,
}

/// Abstraction over audio playback. UI/animation code calls this and never
/// touches a concrete audio package directly, so Polish-phase work (real
/// sound assets, per-category volume, music/ambience loops) only needs a
/// new implementation here — never a change to call sites.
abstract class AudioService {
  void play(SoundEvent event);
}

/// No sound assets exist yet (section 40 is Polish-phase work) — this
/// keeps every call site already wired, silently, until real audio lands.
class NoOpAudioService implements AudioService {
  @override
  void play(SoundEvent event) {}
}
