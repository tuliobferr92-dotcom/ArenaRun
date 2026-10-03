/// Editorial pipeline state (BIBLE_CONTENT_GUIDELINES.md section 23).
/// `ContentRepository` only ever serves [published] items to the app.
enum ContentReviewStatus {
  /// A draft — from an AI or a human writer. Never shown to players.
  generated,

  /// A human editor has checked it for accuracy and neutrality, but it is
  /// not yet released.
  reviewed,

  /// Approved and versioned; the only state `ContentRepository` serves.
  published,
}
