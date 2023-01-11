library loading_value;

import 'package:meta/meta.dart';

typedef Canceller = void Function();

/// An utility for safely manipulating asynchronous data.
///
/// By using [LoadingValue], you are guaranteed that you cannot forget to
/// handle the loading/error state of an asynchronous operation.
///
/// It also expose some utilities to nicely convert an [LoadingValue] to
/// a different object.
/// For example, a Flutter Widget may use [when] to convert an [LoadingValue]
/// into either a progress indicator, an error screen, or to show the data:
///
/// ```dart
/// /// A provider that asynchronously expose the current user
/// final userProvider = StreamProvider<User>((_) async* {
///   // fetch the user
/// });
///
/// class Example extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final AsyncValue<User> user = ref.watch(userProvider);
///
///     return user.when(
///       loading: () => CircularProgressIndicator(),
///       error: (error, stack) => Text('Oops, something unexpected happened'),
///       data: (value) => Text('Hello ${user.name}'),
///     );
///   }
/// }
/// ```
///
/// If a consumer of an [LoadingValue] does not care about the loading/error
/// state, consider using [value] to read the state:
///
/// ```dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   // reads the data state directly – will be throw during loading/error states
///   final User user = ref.watch(userProvider).value;
///
///   return Text('Hello ${user.name}');
/// }
/// ```
@sealed
@immutable
abstract class LoadingValue<T> {
  /// Creates an [LoadingValue] with a data.
  ///
  /// The data can be `null`.
  // coverage:ignore-start
  const factory LoadingValue.data(T value) = LoadedData<T>;

  // coverage:ignore-end

  /// Creates an [LoadingValue] in loading state.
  ///
  /// Prefer always using this constructor with the `const` keyword.
  /// [progress] will be clamped between 0 and 1
  // coverage:ignore-start
  const factory LoadingValue.loading(
    double progress, {
    Canceller? canceller,
  }) = ValueLoading<T>;

  // coverage:ignore-end

  /// Creates an [LoadingValue] in error state.
  ///
  /// The parameter [error] cannot be `null`.
  // coverage:ignore-start
  const factory LoadingValue.error(Object error, {StackTrace? stackTrace}) =
      LoadingError<T>;

  // coverage:ignore-end

  /// Transforms a [Future] that may fail into something that is safe to read.
  ///
  /// This is useful to avoid having to do a tedious `try/catch`. Instead of:
  ///
  /// ```dart
  /// class MyNotifier extends StateNotifier<AsyncValue<MyData> {
  ///   MyNotifier(): super(const AsyncValue.loading()) {
  ///     _fetchData();
  ///   }
  ///
  ///   Future<void> _fetchData() async {
  ///     state = const AsyncValue.loading();
  ///     try {
  ///       final response = await dio.get('my_api/data');
  ///       final data = MyData.fromJson(response);
  ///       state = AsyncValue.data(data);
  ///     } catch (err, stack) {
  ///       state = AsyncValue.error(err, stack);
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// which is redundant as the application grows and we need more and more of this
  /// pattern – we can use [guardFuture] to simplify it:
  ///
  ///
  /// ```dart
  /// class MyNotifier extends StateNotifier<AsyncValue<MyData>> {
  ///   MyNotifier(): super(const AsyncValue.loading()) {
  ///     _fetchData();
  ///   }
  ///
  ///   Future<void> _fetchData() async {
  ///     state = const AsyncValue.loading();
  ///     // does the try/catch for us like previously
  ///     state = await AsyncValue.guard(() async {
  ///       final response = await dio.get('my_api/data');
  ///       return Data.fromJson(response);
  ///     });
  ///   }
  /// }
  /// ```
  static Future<LoadingValue<T>> guardFuture<T>(
      Future<T> Function() future) async {
    try {
      return LoadingValue.data(await future());
    } catch (err, stack) {
      return LoadingValue.error(err, stackTrace: stack);
    }
  }

  // private mapper, so thast classes inheriting AsyncValue can specify their own
  // `map` method with different parameters.
  R _map<R>({
    required R Function(LoadedData<T> data) data,
    required R Function(LoadingError<T> error) error,
    required R Function(ValueLoading<T> loading) loading,
  });
}

/// Creates an [LoadingValue] with a data.
///
/// The data can be `null`.
class LoadedData<T> implements LoadingValue<T> {
  /// Creates an [LoadingValue] with a data.
  ///
  /// The data can be `null`.
  const LoadedData(this.value);

  /// The value currently exposed.
  final T value;

  @override
  R _map<R>({
    required R Function(LoadedData<T> data) data,
    required R Function(LoadingError<T> error) error,
    required R Function(ValueLoading<T> loading) loading,
  }) {
    return data(this);
  }

  @override
  String toString() {
    return 'AsyncData<$T>(value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return runtimeType == other.runtimeType &&
        other is LoadedData<T> &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);
}

/// An extension that adds methods like [when] to an [LoadingValue].
extension LoadingValueX<T> on LoadingValue<T> {
  /// Upcast [LoadingValue] into an [LoadedData], or return null if the [LoadingValue]
  /// is in loading/error state.
  @Deprecated('use `asData` instead')
  LoadedData<T>? get data => asData;

  /// Upcast [LoadingValue] into an [LoadedData], or return null if the [LoadingValue]
  /// is in loading/error state.
  LoadedData<T>? get asData {
    return _map(
      data: (d) => d,
      error: (e) => null,
      loading: (l) => null,
    );
  }

  /// Attempts to synchronously.
  ///
  /// On error, this will rethrow the error.
  /// If loading, will return `null`.
  /// Otherwise will return the data.
  T? get value {
    return _map(
      data: (d) => d.value,
      // ignore: only_throw_errors
      error: (e) => throw e.error,
      loading: (l) => null,
    );
  }

  /// Shorthand for [when] to handle only the `data` case.
  ///
  /// For loading/error cases, creates a new [LoadingValue] with the corresponding
  /// generic type while preserving the error/stacktrace.
  LoadingValue<R> whenData<R>(R Function(T value) cb) {
    return _map(
      data: (d) {
        try {
          return LoadingValue.data(cb(d.value));
        } catch (err, stack) {
          return LoadingValue.error(err, stackTrace: stack);
        }
      },
      error: (e) => LoadingError(e.error, stackTrace: e.stackTrace),
      loading: (l) => ValueLoading<R>(l.progress),
    );
  }

  /// Switch-case over the state of the [LoadingValue] while purposefully not handling
  /// some cases.
  ///
  /// If [LoadingValue] was in a case that is not handled, will return [orElse].
  R maybeWhen<R>({
    R Function(T data)? data,
    R Function(Object error, StackTrace? stackTrace)? error,
    R Function(double progress)? loading,
    required R Function() orElse,
  }) {
    return _map(
      data: (d) {
        if (data != null) return data(d.value);
        return orElse();
      },
      error: (e) {
        if (error != null) return error(e.error, e.stackTrace);
        return orElse();
      },
      loading: (l) {
        if (loading != null) return loading(l.progress);
        return orElse();
      },
    );
  }

  /// Performs an action based on the state of the [LoadingValue].
  ///
  /// All cases are required, which allows returning a non-nullable value.
  R when<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace? stackTrace) error,
    required R Function(double progress) loading,
  }) {
    return _map(
      data: (d) => data(d.value),
      error: (e) => error(e.error, e.stackTrace),
      loading: (l) => loading(l.progress),
    );
  }

  /// Perform actions conditionally based on the state of the [LoadingValue].
  ///
  /// Returns null if [LoadingValue] was in a state that was not handled.
  ///
  /// This is similar to [maybeWhen] where `orElse` returns null.
  R? whenOrNull<R>({
    R Function(T data)? data,
    R Function(Object error, StackTrace? stackTrace)? error,
    R Function(double progress)? loading,
  }) {
    return _map(
      data: (d) => data?.call(d.value),
      error: (e) => error?.call(e.error, e.stackTrace),
      loading: (l) => loading?.call(l.progress),
    );
  }

  /// Perform some action based on the current state of the [LoadingValue].
  ///
  /// This allows reading the content of an [LoadingValue] in a type-safe way,
  /// without potentially ignoring to handle a case.
  R map<R>({
    required R Function(LoadedData<T> data) data,
    required R Function(LoadingError<T> error) error,
    required R Function(ValueLoading<T> loading) loading,
  }) {
    return _map(data: data, error: error, loading: loading);
  }

  /// Perform some actions based on the state of the [LoadingValue], or call orElse
  /// if the current state was not tested.
  R maybeMap<R>({
    R Function(LoadedData<T> data)? data,
    R Function(LoadingError<T> error)? error,
    R Function(ValueLoading<T> loading)? loading,
    required R Function() orElse,
  }) {
    return _map(
      data: (d) {
        if (data != null) return data(d);
        return orElse();
      },
      error: (d) {
        if (error != null) return error(d);
        return orElse();
      },
      loading: (d) {
        if (loading != null) return loading(d);
        return orElse();
      },
    );
  }

  /// Perform some actions based on the state of the [LoadingValue], or return null
  /// if the current state wasn't tested.
  R? mapOrNull<R>({
    R Function(LoadedData<T> data)? data,
    R Function(LoadingError<T> error)? error,
    R Function(ValueLoading<T> loading)? loading,
  }) {
    return _map(
      data: (d) => data?.call(d),
      error: (d) => error?.call(d),
      loading: (d) => loading?.call(d),
    );
  }
}

/// Creates an [LoadingValue] in loading state.
///
/// Prefer always using this constructor with the `const` keyword.
class ValueLoading<T> implements LoadingValue<T> {
  /// Creates an [LoadingValue] in loading state.
  /// [progress] will be clamped between 0 and 1
  /// Prefer always using this constructor with the `const` keyword.
  const ValueLoading(double progress, {this.canceller})
      : progress = progress > 1
            ? 1
            : progress < 0
                ? 0
                : progress;

  final double progress;

  /// An optional function to call if the loading should be cancelled.
  ///
  /// If this is null, the process that is emitting this [LoadingValue] is not
  /// cancellable.
  final Canceller? canceller;

  @override
  R _map<R>({
    required R Function(LoadedData<T> data) data,
    required R Function(LoadingError<T> error) error,
    required R Function(ValueLoading<T> loading) loading,
  }) {
    return loading(this);
  }

  @override
  String toString() {
    return 'ValueLoading<$T>($progress)';
  }

  @override
  bool operator ==(Object other) {
    return other is ValueLoading &&
        other.progress == progress &&
        other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => Object.hash(runtimeType, progress);
}

/// Creates an [LoadingValue] in error state.
///
/// The parameter [error] cannot be `null`.
class LoadingError<T> implements LoadingValue<T> {
  /// Creates an [LoadingValue] in error state.
  ///
  /// The parameter [error] cannot be `null`.
  const LoadingError(this.error, {this.stackTrace});

  /// The error.
  final Object error;

  /// The stacktrace of [error].
  final StackTrace? stackTrace;

  @override
  R _map<R>({
    required R Function(LoadedData<T> data) data,
    required R Function(LoadingError<T> error) error,
    required R Function(ValueLoading<T> loading) loading,
  }) {
    return error(this);
  }

  @override
  String toString() {
    return 'LoadingError<$T>(error: $error, stackTrace: $stackTrace)';
  }

  @override
  bool operator ==(Object other) {
    return runtimeType == other.runtimeType &&
        other is LoadingError<T> &&
        other.error == error &&
        other.stackTrace == stackTrace;
  }

  @override
  int get hashCode => Object.hash(runtimeType, error, stackTrace);
}
