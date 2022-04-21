A simple, declarative wrapper class for a value that is loading and will return a value at some point.
Similar to Rémi Rousselet's `AsyncValue` used in riverpod and flutter_hooks.

## Features

Use a single stream to easily represent all states that happen during loading:

```dart

Stream<LoadingValue<bool>> loadResult() async* {
  Stream<double> progressHandler = const Stream<double>();
  try {
    final result = someFunction(progressHandler);
    await for (final progress in progressHandler) {
      yield LoadingValue<bool>.loading(progress);
    }
    yield LoadingValue.data(await result);
  } catch (e, s) {
    yield LoadingValue<bool>.error(e, stackTrace: s);
  }
}

```
