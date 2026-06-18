import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_clean_architecture/flutter_clean_architecture.dart';

class TestPresenter extends Presenter {
  late final SafeVoidCallback onComplete;
  late final SafeCallback<String> onData;

  TestPresenter() {
    onComplete = SafeVoidCallback(this);
    onData = SafeCallback<String>(this);
  }
}

class NoSuperDisposePresenter extends Presenter {
  late final SafeVoidCallback onComplete;

  NoSuperDisposePresenter() {
    onComplete = SafeVoidCallback(this);
  }

  @override
  void dispose() {
    // Intentionally does NOT call super.dispose() — simulates buggy subclass
  }
}

class LifecycleTestController extends Controller {
  LifecycleTestController() : super();

  @override
  void initListeners() {}
}

void main() {
  group('SafeVoidCallback', () {
    test('invokes callback when presenter is active', () {
      final presenter = TestPresenter();
      int callCount = 0;
      presenter.onComplete.callback = () => callCount++;

      presenter.onComplete();
      expect(callCount, 1);
    });

    test('no-ops after presenter dispose', () {
      final presenter = TestPresenter();
      int callCount = 0;
      presenter.onComplete.callback = () => callCount++;

      presenter.onComplete();
      expect(callCount, 1);

      presenter.dispose();
      presenter.onComplete();
      expect(callCount, 1);
    });

    test('no-ops when callback is null', () {
      final presenter = TestPresenter();
      expect(() => presenter.onComplete(), returnsNormally);
    });

    test('accepts optional argument without crashing', () {
      final presenter = TestPresenter();
      int callCount = 0;
      presenter.onComplete.callback = () => callCount++;

      // Observer may pass an argument even when callback expects none
      presenter.onComplete('unexpected_arg');
      expect(callCount, 1);
    });
  });

  group('SafeCallback<T>', () {
    test('invokes typed callback when presenter is active', () {
      final presenter = TestPresenter();
      String? received;
      presenter.onData.callback = (s) => received = s;

      presenter.onData('hello');
      expect(received, 'hello');
    });

    test('no-ops after presenter dispose', () {
      final presenter = TestPresenter();
      String? received;
      presenter.onData.callback = (s) => received = s;

      presenter.onData('hello');
      expect(received, 'hello');

      presenter.dispose();
      presenter.onData('world');
      expect(received, 'hello');
    });

    test('no-ops when callback is null', () {
      final presenter = TestPresenter();
      expect(() => presenter.onData('test'), returnsNormally);
    });
  });

  group('Presenter lifecycle', () {
    test('isDisposed is false before dispose', () {
      final presenter = TestPresenter();
      expect(presenter.isDisposed, false);
    });

    test('isDisposed is true after dispose', () {
      final presenter = TestPresenter();
      presenter.dispose();
      expect(presenter.isDisposed, true);
    });

    test('dispose deactivates all registered callbacks', () {
      final presenter = TestPresenter();
      int completeCount = 0;
      int dataCount = 0;
      presenter.onComplete.callback = () => completeCount++;
      presenter.onData.callback = (_) => dataCount++;

      presenter.dispose();

      presenter.onComplete();
      presenter.onData('test');
      expect(completeCount, 0);
      expect(dataCount, 0);
    });

    test('double dispose is idempotent', () {
      final presenter = TestPresenter();
      int callCount = 0;
      presenter.onComplete.callback = () => callCount++;

      presenter.dispose();
      expect(presenter.isDisposed, true);

      // Second dispose should not throw
      expect(() => presenter.dispose(), returnsNormally);
      expect(presenter.isDisposed, true);
    });

    test('callbacks NOT deactivated when super.dispose() is omitted', () {
      final presenter = NoSuperDisposePresenter();
      int callCount = 0;
      presenter.onComplete.callback = () => callCount++;

      presenter.dispose(); // does NOT call super.dispose()

      // In debug mode, logging is emitted but callback still fires
      // because _active was never set to false
      presenter.onComplete();
      expect(callCount, 1);

      // isDisposed stays false because super.dispose() was not called
      expect(presenter.isDisposed, false);
    });
  });

  group('Controller guard/guarded', () {
    test('guard invokes callback when controller is mounted', () {
      final controller = LifecycleTestController();
      int callCount = 0;
      final guarded = controller.guard(() => callCount++);

      guarded();
      expect(callCount, 1);
    });

    test('guard skips callback after controller disposal', () {
      final controller = LifecycleTestController();
      int callCount = 0;
      final guarded = controller.guard(() => callCount++);
      controller.dispose();

      guarded();
      expect(callCount, 0);
    });

    test('guarded invokes typed callback when controller is mounted', () {
      final controller = LifecycleTestController();
      int sum = 0;
      final guarded = controller.guarded<int>((v) => sum += v);

      guarded(5);
      expect(sum, 5);
    });

    test('guarded skips typed callback after controller disposal', () {
      final controller = LifecycleTestController();
      int sum = 0;
      final guarded = controller.guarded<int>((v) => sum += v);
      controller.dispose();

      guarded(5);
      expect(sum, 0);
    });
  });

  group('getContext and getState after disposal', () {
    testWidgets('getContext asserts when controller is disposed',
        (WidgetTester tester) async {
      final controller = LifecycleTestController();
      final page = _TestPage(controller: controller);
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();

      // Context should be accessible while mounted
      expect(() => controller.getContext(), returnsNormally);

      // Remove from tree and dispose
      await tester.pumpWidget(Container());
      await tester.pump();

      // getContext should assert after disposal
      expect(() => controller.getContext(), throwsAssertionError);
    });

    testWidgets('getState asserts when controller is disposed',
        (WidgetTester tester) async {
      final controller = LifecycleTestController();
      final page = _TestPage(controller: controller);
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();

      expect(() => controller.getState(), returnsNormally);

      await tester.pumpWidget(Container());
      await tester.pump();

      expect(() => controller.getState(), throwsAssertionError);
    });
  });

  group('Widget-level integration', () {
    testWidgets('guard prevents crash when async callback fires after dispose',
        (WidgetTester tester) async {
      final controller = LifecycleTestController();
      final page = _TestPage(controller: controller);
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pump();

      // Simulate a callback wrapped with guard that would try to refreshUI
      final callback = controller.guard(() {
        controller.refreshUI();
      });

      // Remove page from tree (triggers deactivate + dispose)
      await tester.pumpWidget(Container());
      await tester.pump();

      // Callback fires after disposal — should silently no-op
      expect(() => callback(), returnsNormally);
    });
  });
}

class _TestPage extends FCAView {
  final LifecycleTestController controller;
  _TestPage({required this.controller});

  @override
  State<StatefulWidget> createState() => _TestState(controller);
}

class _TestState extends ViewState<_TestPage, LifecycleTestController> {
  _TestState(LifecycleTestController controller) : super(controller);

  @override
  Widget get view {
    return Scaffold(
      key: globalKey,
      body: const Text('Test'),
    );
  }
}
