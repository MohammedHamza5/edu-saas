import 'package:flutter/material.dart';

/// Encapsulates all TextEditingControllers and keys for the exam creator form.
class CreateExamFormControllers {
  final formKey = GlobalKey<FormState>();
  final scrollController = ScrollController();
  final title = TextEditingController();
  final duration = TextEditingController(text: '60');
  final maxScore = TextEditingController(text: '20');
  final passingScore = TextEditingController(text: '12');
  final defaultPoints = TextEditingController(text: '5');

  List<TextEditingController> get allTextControllers => [
        title,
        duration,
        maxScore,
        passingScore,
        defaultPoints,
      ];

  void addAutoSaveListeners(VoidCallback listener) {
    for (final c in allTextControllers) {
      c.addListener(listener);
    }
  }

  void removeAutoSaveListeners(VoidCallback listener) {
    for (final c in allTextControllers) {
      c.removeListener(listener);
    }
  }

  void dispose() {
    for (final c in allTextControllers) {
      c.dispose();
    }
    scrollController.dispose();
  }
}

/// Encapsulates toggle flags and points configuration for the exam creator.
class CreateExamSettingsState {
  bool shuffle = true;
  bool showResult = true;
  bool allowRetake = false;
  bool isPublished = false;
  bool saveToQuestionBank = true;
  int defaultQuestionPoints = 5;
}
