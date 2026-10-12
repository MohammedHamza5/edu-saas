import 'dart:js_interop';

@JS('setVideoPlayerPointerEvents')
external void _setVideoPlayerPointerEventsJS(JSBoolean enabled);

@JS('window.addEventListener')
external void _addEventListener(JSString type, JSFunction listener);

@JS('window.removeEventListener')
external void _removeEventListener(JSString type, JSFunction listener);

JSFunction? _currentListener;

void setVideoPlayerPointerEvents(bool enabled) {
  try {
    _setVideoPlayerPointerEventsJS(enabled.toJS);
  } catch (_) {}
}

void registerCloseModalListener(void Function() onClose) {
  try {
    unregisterCloseModalListener();
    _currentListener = (() {
      onClose();
    }).toJS;
    _addEventListener('close-pdf-modal'.toJS, _currentListener!);
  } catch (_) {}
}

void unregisterCloseModalListener() {
  try {
    if (_currentListener != null) {
      _removeEventListener('close-pdf-modal'.toJS, _currentListener!);
      _currentListener = null;
    }
  } catch (_) {}
}
