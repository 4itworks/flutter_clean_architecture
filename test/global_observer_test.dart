import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_clean_architecture/flutter_clean_architecture.dart';

void main() {
  group('Global Observer Tests', () {
    late TestObserver testObserver;

    setUp(() {
      testObserver = TestObserver();
      FlutterCleanArchitecture.observer = testObserver;
    });

    tearDown(() {
      FlutterCleanArchitecture.observer = null;
    });

    test('Controller creation and dispose lifecycle', () {
      expect(testObserver.createdControllers.length, 0);
      expect(testObserver.disposedControllers.length, 0);

      final controller = MockController();

      expect(testObserver.createdControllers.length, 1);
      expect(testObserver.createdControllers.first, controller);

      controller.dispose();

      expect(testObserver.disposedControllers.length, 1);
      expect(testObserver.disposedControllers.first, controller);
    });

    test('Controller default state snapshot and error handling', () {
      final controller = MockController();

      // Check default stateSnapshot
      expect(controller.getStateSnapshot(), const <String, dynamic>{});

      // Trigger error and check observer
      expect(testObserver.controllerErrorsEmitted.length, 0);
      final testError = Exception('Controller failed');
      final testStack = StackTrace.current;

      controller.triggerError(testError, testStack);

      expect(testObserver.controllerErrorsEmitted.length, 1);
      expect(testObserver.controllerErrorsEmitted.first.controller, controller);
      expect(testObserver.controllerErrorsEmitted.first.error, testError);
      expect(testObserver.controllerErrorsEmitted.first.stackTrace, testStack);
    });

    test('Controller runSafe success and error flows', () async {
      final controller = MockController();

      // Success flow
      final result =
          await controller.triggerRunSafe(() async => 'success_data');
      expect(result, 'success_data');
      expect(testObserver.controllerErrorsEmitted.length, 0);

      // Error flow
      final resultError = await controller.triggerRunSafe(() async {
        throw Exception('Safe failure');
      });
      expect(resultError, isNull);
      expect(testObserver.controllerErrorsEmitted.length, 1);
      expect(testObserver.controllerErrorsEmitted.first.controller, controller);
      expect(testObserver.controllerErrorsEmitted.first.error.toString(),
          contains('Safe failure'));
    });

    test('UseCase execute success flow', () async {
      final useCase = MockUseCase();
      final observer = MockObserver<int>();

      expect(testObserver.executedUseCases.length, 0);
      expect(testObserver.nextEmitted.length, 0);
      expect(testObserver.completedUseCases.length, 0);

      useCase.execute(observer, 'test-params');

      expect(testObserver.executedUseCases.length, 1);
      expect(testObserver.executedUseCases.first.useCase, useCase);
      expect(testObserver.executedUseCases.first.params, 'test-params');

      await Future.delayed(Duration(milliseconds: 100));

      expect(testObserver.nextEmitted.length, 2);
      expect(testObserver.nextEmitted[0].value, 42);
      expect(testObserver.nextEmitted[1].value, 43);
      expect(testObserver.completedUseCases.length, 1);
      expect(testObserver.completedUseCases.first, useCase);
    });

    test('UseCase execute error flow', () async {
      final useCase = MockErrorUseCase();
      final observer = MockObserver<int>();

      expect(testObserver.executedUseCases.length, 0);
      expect(testObserver.errorsEmitted.length, 0);

      useCase.execute(observer, 'error-params');

      expect(testObserver.executedUseCases.length, 1);
      expect(testObserver.executedUseCases.first.useCase, useCase);
      expect(testObserver.executedUseCases.first.params, 'error-params');

      await Future.delayed(Duration(milliseconds: 100));

      expect(testObserver.errorsEmitted.length, 1);
      expect(testObserver.errorsEmitted.first.useCase, useCase);
      expect(testObserver.errorsEmitted.first.error, isA<Exception>());
    });
  });
}

class TestObserver extends CleanArchitectureObserver {
  final List<Controller> createdControllers = [];
  final List<Controller> disposedControllers = [];
  final List<({UseCase useCase, dynamic params})> executedUseCases = [];
  final List<({UseCase useCase, dynamic value})> nextEmitted = [];
  final List<({UseCase useCase, dynamic error})> errorsEmitted = [];
  final List<UseCase> completedUseCases = [];
  final List<({Controller controller, Object error, StackTrace? stackTrace})>
      controllerErrorsEmitted = [];

  @override
  void onControllerCreated(Controller controller) {
    createdControllers.add(controller);
  }

  @override
  void onControllerDisposed(Controller controller) {
    disposedControllers.add(controller);
  }

  @override
  void onControllerError(
      Controller controller, Object error, StackTrace? stackTrace) {
    controllerErrorsEmitted
        .add((controller: controller, error: error, stackTrace: stackTrace));
  }

  @override
  void onUseCaseExecuted(UseCase useCase, dynamic params) {
    executedUseCases.add((useCase: useCase, params: params));
  }

  @override
  void onUseCaseNext(UseCase useCase, dynamic next) {
    nextEmitted.add((useCase: useCase, value: next));
  }

  @override
  void onUseCaseError(UseCase useCase, dynamic error) {
    errorsEmitted.add((useCase: useCase, error: error));
  }

  @override
  void onUseCaseComplete(UseCase useCase) {
    completedUseCases.add(useCase);
  }
}

class MockController extends Controller {
  @override
  void initListeners() {}

  void triggerError(Object e, StackTrace s) => onError(e, s);

  Future<T?> triggerRunSafe<T>(Future<T> Function() action) => runSafe(action);
}

class MockUseCase extends UseCase<int, String> {
  @override
  Future<Stream<int?>> buildUseCaseStream(String? params) async {
    return Stream.fromIterable([42, 43]);
  }
}

class MockErrorUseCase extends UseCase<int, String> {
  @override
  Future<Stream<int?>> buildUseCaseStream(String? params) async {
    return Stream.error(Exception('Oops'));
  }
}

class MockObserver<T> extends Observer<T> {
  @override
  void onComplete() {}

  @override
  void onError(e) {}

  @override
  void onNext(T? response) {}
}
