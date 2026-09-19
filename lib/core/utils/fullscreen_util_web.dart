import 'dart:js_interop';

@JS('toggleAppFullscreen')
external bool _toggleAppFullscreen();

@JS('isAppFullscreen')
external bool _isAppFullscreen();

@JS('setFullscreenCallback')
external void _setFullscreenCallback(JSFunction? callback);

void toggleWebFullscreen() {
  try {
    _toggleAppFullscreen();
  } catch (_) {}
}

bool isWebFullscreen() {
  try {
    return _isAppFullscreen();
  } catch (_) {
    return false;
  }
}

void registerFullscreenListener(void Function(bool isFullscreen) listener) {
  try {
    _setFullscreenCallback(listener.toJS);
  } catch (_) {}
}

void unregisterFullscreenListener() {
  try {
    _setFullscreenCallback(null);
  } catch (_) {}
}
