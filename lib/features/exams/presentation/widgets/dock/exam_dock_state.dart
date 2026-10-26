/// Represents the active tool tab displayed inside the SAT Utility Dock.
enum ExamDockTab {
  calculator,
  formulas,
  scratchpad;

  bool get isCalculator => this == ExamDockTab.calculator;
  bool get isFormulas => this == ExamDockTab.formulas;
  bool get isScratchpad => this == ExamDockTab.scratchpad;
}

/// Represents the display mode of the Exam Utility Dock.
enum ExamDockMode {
  /// The dock is anchored side-by-side with the question view (Zero Question Overlap).
  docked,

  /// The dock is detached into a floating, movable window on student preference.
  floating,

  /// The dock is collapsed/closed to provide full-width reading space.
  hidden;

  bool get isDocked => this == ExamDockMode.docked;
  bool get isFloating => this == ExamDockMode.floating;
  bool get isHidden => this == ExamDockMode.hidden;
  bool get isVisible => this != ExamDockMode.hidden;
}
