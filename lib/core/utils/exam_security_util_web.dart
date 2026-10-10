import 'dart:js_interop';

@JS('setExamInProgress')
external void _setExamInProgress(bool inProgress);

void setWebExamSecurityActive(bool active) {
  try {
    _setExamInProgress(active);
  } catch (_) {}
}
