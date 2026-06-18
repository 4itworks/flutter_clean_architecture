import 'dart:ui';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

/// A [Presenter] prepares data for the [Controller], listens to [UseCase], and
/// handles its creation and disposal. A [Presenter] should be aggregated inside
/// a [Controller]. Its dependencies are also provided by the [Controller]. Once the
/// [Controller] is disposed, it should also call [dispose()] of the [Presenter] in order
/// to dispose of the [UseCase]. The [Presenter] utilizes an [Observer] to listen to the
/// [UseCase]. However, it is a separate class since Dart does not yet support inner
/// or anonymous classes.
///
/// ### Lifecycle-safe callbacks
///
/// To prevent async callbacks from firing after the Presenter is disposed, use
/// [SafeVoidCallback] or [SafeCallback] with a getter/setter pattern:
///
/// ```dart
/// class LoginPresenter extends Presenter {
///   late final SafeVoidCallback _onComplete;
///   late final SafeCallback<dynamic> _onError;
///
///   Function? get onComplete => _onComplete;
///   set onComplete(Function? f) => _onComplete.callback = f as void Function()?;
///
///   Function? get onError => _onError;
///   set onError(Function? f) => _onError.callback = f as void Function(dynamic)?;
///
///   final LoginUseCase loginUseCase;
///
///   LoginPresenter(authenticationRepo)
///       : loginUseCase = LoginUseCase(authenticationRepo) {
///     _onComplete = SafeVoidCallback(this);
///     _onError = SafeCallback<dynamic>(this);
///   }
///
///   @override
///   void dispose() {
///     loginUseCase.dispose();
///     super.dispose(); // deactivates all SafeCallbacks
///   }
/// }
/// ```
///
/// Alternatively, use [Controller.guard] or [Controller.guarded] in the Controller
/// to wrap individual callbacks without changing the Presenter:
///
/// ```dart
/// // In Controller.initListeners():
/// presenter.onComplete = guard(() => refreshUI());
/// presenter.onError = guarded<dynamic>((e) => handleError(e));
/// ```
///
/// ### Legacy example (without SafeCallback)
///
/// The legacy pattern using plain [Function] fields is still supported:
///
/// ```dart
/// class LoginPresenter extends Presenter {
///   Function loginOnComplete;
///   Function loginOnError;
///   Function loginOnNext;
///
///   final LoginUseCase loginUseCase;
///
///   LoginPresenter(authenticationRepo)
///       : loginUseCase = LoginUseCase(authenticationRepo);
///
///   void login(String email, String password) {
///     loginUseCase.execute(
///         _LoginUseCaseObserver(this),
///         LoginUseCaseParams(email, password));
///   }
///
///   @override
///   void dispose() {
///     loginUseCase.dispose();
///     super.dispose();
///   }
/// }
///
/// class _LoginUseCaseObserver implements Observer<void> {
///   final LoginPresenter loginPresenter;
///   _LoginUseCaseObserver(this.loginPresenter);
///
///   void onNext(_) {}
///
///   void onComplete() {
///     assert(loginPresenter.loginOnComplete != null);
///     loginPresenter.loginOnComplete();
///   }
///
///   void onError(e) {
///     assert(loginPresenter.loginOnError != null);
///     loginPresenter.loginOnError(e);
///   }
/// }
/// ```
abstract class Presenter {
  bool _isDisposed = false;
  final List<_SafeCallbackBase> _registeredCallbacks = [];

  void _registerCallback(_SafeCallbackBase cb) {
    _registeredCallbacks.add(cb);
  }

  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final cb in _registeredCallbacks) {
      cb.deactivate();
    }
    _registeredCallbacks.clear();
  }

  /// Whether this presenter has been disposed.
  bool get isDisposed => _isDisposed;
}

abstract class _SafeCallbackBase {
  bool _active = true;
  static final Logger _logger = Logger('SafeCallback');

  void deactivate() => _active = false;
}

/// A callable void callback that automatically no-ops after its
/// [Presenter] is disposed. Assign callbacks via the [callback] setter.
///
/// The [SafeVoidCallback] registers itself with the [Presenter] on construction,
/// and is automatically deactivated when [Presenter.dispose] is called.
///
/// Usage in a Presenter subclass:
/// ```dart
/// class MyPresenter extends Presenter {
///   final _onComplete = SafeVoidCallback(this);
///   Function? get onComplete => _onComplete;
///   set onComplete(Function? f) => _onComplete.callback = f;
/// }
/// ```
class SafeVoidCallback extends _SafeCallbackBase {
  VoidCallback? _callback;

  SafeVoidCallback(Presenter p) {
    p._registerCallback(this);
  }

  void call([_]) {
    if (!_active) {
      _SafeCallbackBase._logger.warning(
          'SafeVoidCallback invoked after presenter was disposed. The callback was ignored.');
      return;
    }
    if (_callback != null) _callback!();
  }

  set callback(VoidCallback? cb) => _callback = cb;
}

/// A callable typed callback that automatically no-ops after its
/// [Presenter] is disposed. Assign callbacks via the [callback] setter.
///
/// The [SafeCallback] registers itself with the [Presenter] on construction,
/// and is automatically deactivated when [Presenter.dispose] is called.
///
/// Usage in a Presenter subclass:
/// ```dart
/// class MyPresenter extends Presenter {
///   final _onNext = SafeCallback<User>(this);
///   Function? get onNext => _onNext;
///   set onNext(Function? f) => _onNext.callback = f;
/// }
/// ```
class SafeCallback<T> extends _SafeCallbackBase {
  void Function(T)? _callback;

  SafeCallback(Presenter p) {
    p._registerCallback(this);
  }

  void call(T value) {
    if (!_active) {
      _SafeCallbackBase._logger.warning(
          'SafeCallback<$T> invoked after presenter was disposed. The callback was ignored.');
      return;
    }
    if (_callback != null) _callback!(value);
  }

  set callback(void Function(T)? cb) => _callback = cb;
}
