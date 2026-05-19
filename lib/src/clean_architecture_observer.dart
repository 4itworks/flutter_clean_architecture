import 'package:flutter_clean_architecture/flutter_clean_architecture.dart';

/// An observer for monitoring the global lifecycle of [Controller] and [UseCase].
abstract class CleanArchitectureObserver {
  const CleanArchitectureObserver();

  /// Called when a [Controller] is created.
  void onControllerCreated(Controller controller) {}

  /// Called when a [Controller] is disposed.
  void onControllerDisposed(Controller controller) {}

  /// Called when a [Controller] intercepts an error.
  void onControllerError(
      Controller controller, Object error, StackTrace? stackTrace) {}

  /// Called when a [UseCase] starts execution.
  void onUseCaseExecuted(UseCase useCase, dynamic params) {}

  /// Called when a [UseCase] emits a new value.
  void onUseCaseNext(UseCase useCase, dynamic next) {}

  /// Called when a [UseCase] emits an error.
  void onUseCaseError(UseCase useCase, dynamic error) {}

  /// Called when a [UseCase] completes its stream.
  void onUseCaseComplete(UseCase useCase) {}
}
