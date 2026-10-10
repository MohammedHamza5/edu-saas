import 'exam_security_util_stub.dart'
    if (dart.library.js_interop) 'exam_security_util_web.dart';

/// Activates or deactivates browser-level lockdown for exams on Web.
/// On non-web platforms, this is a no-op as OS-level protections (FLAG_SECURE) apply.
void setExamSecurityActive(bool active) {
  setWebExamSecurityActive(active);
}
