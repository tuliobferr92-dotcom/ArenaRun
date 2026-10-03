import 'content_review_status.dart';

enum ChallengeCategory {
  geography,
  characters,
  events,
  chronology,
  books,
  context,
  connections,
}

enum ChallengeDifficulty { beginner, intermediate, advanced, expert }

/// A single multiple-choice question (section 22). Deliberately tied to a
/// [territoryId] rather than to a free-floating quiz bank, so it only ever
/// surfaces at a meaningful moment (first discovery of that territory) —
/// never on every attack.
class BibleChallenge {
  final String id;
  final String territoryId;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final List<String> biblicalReferences;
  final ChallengeCategory category;
  final ChallengeDifficulty difficulty;
  final String? historicalNotes;
  final ContentReviewStatus reviewStatus;

  /// Who/what produced this item and when (section 23) — never shown to
  /// players, kept for editorial traceability.
  final Map<String, dynamic> sourceMetadata;

  const BibleChallenge({
    required this.id,
    required this.territoryId,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.biblicalReferences,
    required this.category,
    required this.difficulty,
    required this.reviewStatus,
    required this.sourceMetadata,
    this.historicalNotes,
  });

  factory BibleChallenge.fromJson(Map<String, dynamic> json) {
    return BibleChallenge(
      id: json['id'] as String,
      territoryId: json['territoryId'] as String,
      question: json['question'] as String,
      options: (json['options'] as List).cast<String>(),
      correctOptionIndex: json['correctOptionIndex'] as int,
      explanation: json['explanation'] as String,
      biblicalReferences: (json['biblicalReferences'] as List).cast<String>(),
      category: ChallengeCategory.values.byName(json['category'] as String),
      difficulty: ChallengeDifficulty.values.byName(json['difficulty'] as String),
      historicalNotes: json['historicalNotes'] as String?,
      reviewStatus: ContentReviewStatus.values.byName(json['reviewStatus'] as String),
      sourceMetadata: Map<String, dynamic>.from(json['sourceMetadata'] as Map? ?? {}),
    );
  }
}
