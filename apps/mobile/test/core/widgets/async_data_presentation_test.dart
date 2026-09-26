import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/async_data_presentation.dart';

void main() {
  test('different-target state is always loading', () {
    expect(
      classifyAsyncDataPresentation(
        belongsToTarget: false,
        hasData: true,
        isPending: false,
        hasFailed: true,
      ),
      AsyncDataPresentation.loading,
    );
  });

  test('same-target retained data wins during refresh or failure', () {
    for (final state in [
      (isPending: true, hasFailed: false),
      (isPending: false, hasFailed: true),
    ]) {
      expect(
        classifyAsyncDataPresentation(
          hasData: true,
          isPending: state.isPending,
          hasFailed: state.hasFailed,
        ),
        AsyncDataPresentation.content,
      );
    }
  });

  test('same-target null distinguishes pending, failure, and absence', () {
    expect(
      classifyAsyncDataPresentation(
        hasData: false,
        isPending: true,
        hasFailed: false,
      ),
      AsyncDataPresentation.loading,
    );
    expect(
      classifyAsyncDataPresentation(
        hasData: false,
        isPending: false,
        hasFailed: true,
      ),
      AsyncDataPresentation.failure,
    );
    expect(
      classifyAsyncDataPresentation(
        hasData: false,
        isPending: false,
        hasFailed: false,
      ),
      AsyncDataPresentation.absent,
    );
  });
}
