/// Perceived difficulty of a question assessed by the student in active recall
enum QuestionDifficultyRating {
  easy,   // سهل 🟢 - مراجعة بعد 6 أيام
  medium, // متوسط 🟡 - مراجعة بعد 3 أيام
  hard,   // صعب 🔴 - مراجعة غداً (يوم 1)
  ;

  int get intervalDays {
    switch (this) {
      case QuestionDifficultyRating.hard:
        return 1;
      case QuestionDifficultyRating.medium:
        return 3;
      case QuestionDifficultyRating.easy:
        return 6;
    }
  }

  String get value {
    switch (this) {
      case QuestionDifficultyRating.easy:
        return 'easy';
      case QuestionDifficultyRating.medium:
        return 'medium';
      case QuestionDifficultyRating.hard:
        return 'hard';
    }
  }

  static QuestionDifficultyRating? fromString(String? val) {
    if (val == null) return null;
    switch (val.toLowerCase()) {
      case 'easy':
        return QuestionDifficultyRating.easy;
      case 'medium':
        return QuestionDifficultyRating.medium;
      case 'hard':
        return QuestionDifficultyRating.hard;
      default:
        return null;
    }
  }
}
