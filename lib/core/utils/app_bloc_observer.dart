import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/app_logger.dart';

/// 🧩 AppBlocObserver — Tracks ALL Cubit/Bloc transitions automatically
///
/// Registered once in main() via `Bloc.observer = const AppBlocObserver()`.
/// Intercepts:
///  - onCreate   → when a Cubit is instantiated
///  - onChange   → every state transition (old → new)
///  - onTransition → every Bloc event-driven transition
///  - onError    → any unhandled error inside a Cubit/Bloc
///  - onClose    → when a Cubit is disposed
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    AppLogger.b(
      'BlocObserver',
      'Created ${bloc.runtimeType}',
    );
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    AppLogger.b(
      bloc.runtimeType.toString(),
      'State changed',
      data: {
        'from': change.currentState.runtimeType.toString(),
        'to': change.nextState.runtimeType.toString(),
      },
    );
  }

  @override
  void onTransition(Bloc<dynamic, dynamic> bloc, Transition<dynamic, dynamic> transition) {
    super.onTransition(bloc, transition);
    AppLogger.b(
      bloc.runtimeType.toString(),
      'Event triggered transition',
      data: {
        'event': transition.event.runtimeType.toString(),
        'from': transition.currentState.runtimeType.toString(),
        'to': transition.nextState.runtimeType.toString(),
      },
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    AppLogger.e(
      bloc.runtimeType.toString(),
      '❌ Unhandled error in ${bloc.runtimeType}',
      error: error,
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    AppLogger.b(
      'BlocObserver',
      'Disposed ${bloc.runtimeType}',
    );
  }
}
