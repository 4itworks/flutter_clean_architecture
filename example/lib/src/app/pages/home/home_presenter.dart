import '../../../domain/usecases/get_user_usecase.dart';
import 'package:flutter_clean_architecture/flutter_clean_architecture.dart';

class HomePresenter extends Presenter {
  late final SafeCallback<dynamic> _getUserOnNext;
  late final SafeVoidCallback _getUserOnComplete;
  late final SafeCallback<dynamic> _getUserOnError;

  Function? get getUserOnNext => _getUserOnNext;
  set getUserOnNext(Function? f) =>
      _getUserOnNext.callback = f as void Function(dynamic)?;

  Function? get getUserOnComplete => _getUserOnComplete;
  set getUserOnComplete(Function? f) =>
      _getUserOnComplete.callback = f as void Function()?;

  Function? get getUserOnError => _getUserOnError;
  set getUserOnError(Function? f) =>
      _getUserOnError.callback = f as void Function(dynamic)?;

  final GetUserUseCase getUserUseCase;
  HomePresenter(usersRepo) : getUserUseCase = GetUserUseCase(usersRepo) {
    _getUserOnNext = SafeCallback<dynamic>(this);
    _getUserOnComplete = SafeVoidCallback(this);
    _getUserOnError = SafeCallback<dynamic>(this);
  }

  void getUser(String uid) {
    // execute getUseruserCase
    getUserUseCase.execute(
        _GetUserUseCaseObserver(this), GetUserUseCaseParams(uid));
  }

  @override
  void dispose() {
    getUserUseCase.dispose();
    super.dispose();
  }
}

class _GetUserUseCaseObserver extends Observer<GetUserUseCaseResponse> {
  final HomePresenter presenter;
  _GetUserUseCaseObserver(this.presenter);
  @override
  void onComplete() {
    assert(presenter.getUserOnComplete != null);
    presenter.getUserOnComplete?.call();
  }

  @override
  void onError(e) {
    assert(presenter.getUserOnError != null);
    presenter.getUserOnError?.call(e);
  }

  @override
  void onNext(response) {
    assert(presenter.getUserOnNext != null);
    presenter.getUserOnNext?.call(response?.user);
  }
}
