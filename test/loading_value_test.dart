import 'package:flutter_test/flutter_test.dart';
import 'package:loading_value/loading_value.dart';

void main() {
  test('loading value functions retain progress value', () {
    const value = 0.5;
    const lv = LoadingValue.loading(value);
    expect(
      lv.map(data: (_) => null, error: (_) => null, loading: (l) => l.progress),
      value,
    );
    expect(
      lv.maybeMap(orElse: () => null, loading: (l) => l.progress),
      value,
    );
    expect(
      lv.when(data: (_) => null, error: (_, __) => null, loading: (p) => p),
      value,
    );
    expect(
      lv.maybeWhen(orElse: () => null, loading: (p) => p),
      value,
    );
  });

  test('loading value progress clamping', () {
    expect(const ValueLoading(-1).progress, 0);
    expect(const ValueLoading(4).progress, 1);
    expect(const ValueLoading(0.1).progress, 0.1);
    expect(const ValueLoading(0.9).progress, 0.9);
  });
}
