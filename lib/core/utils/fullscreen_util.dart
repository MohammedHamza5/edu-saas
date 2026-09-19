import 'fullscreen_util_stub.dart'
    if (dart.library.js_interop) 'fullscreen_util_web.dart';

void requestToggleFullscreen() {
  toggleWebFullscreen();
}

bool checkIsFullscreen() {
  return isWebFullscreen();
}

void listenToFullscreenChange(void Function(bool isFullscreen) listener) {
  registerFullscreenListener(listener);
}

void removeFullscreenListener() {
  unregisterFullscreenListener();
}
