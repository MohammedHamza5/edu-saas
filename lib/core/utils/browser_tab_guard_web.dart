// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

html.EventListener? _beforeUnloadListener;

/// Attaches a browser beforeunload event listener to warn the user if they try to close or refresh the tab while uploading.
void enableTabCloseWarning(String message) {
  disableTabCloseWarning();
  _beforeUnloadListener = (html.Event event) {
    event.preventDefault();
    if (event is html.BeforeUnloadEvent) {
      event.returnValue = message;
    }
    return message;
  };
  html.window.addEventListener('beforeunload', _beforeUnloadListener);
}

/// Detaches the browser beforeunload listener once the upload finishes or is cancelled.
void disableTabCloseWarning() {
  if (_beforeUnloadListener != null) {
    html.window.removeEventListener('beforeunload', _beforeUnloadListener);
    _beforeUnloadListener = null;
  }
}
