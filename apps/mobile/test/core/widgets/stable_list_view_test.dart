import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planets_mobile/core/widgets/stable_list_view.dart';

void main() {
  testWidgets(
    'unchanged rows retain widgets; inserted rows retain visible anchor',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var ids = List<Object>.generate(100, (i) => i);
      late StateSetter update;
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return StableListView(
                  rowIds: ids,
                  rowValues: ids,
                  storageKey: 'owner-private',
                  itemBuilder: (context, index) {
                    builds++;
                    return SizedBox(
                      key: ValueKey('body-${ids[index]}'),
                      height: 60 + ((ids[index] as int) % 3) * 10,
                      child: Text('Row ${ids[index]}'),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -1400));
      await tester.pumpAndSettle();
      final anchor = List.generate(100, (i) => i).firstWhere(
        (i) =>
            find.byKey(ValueKey('body-$i')).hitTestable().evaluate().isNotEmpty,
      );
      final row = find.byKey(ValueKey('body-$anchor'));
      final y = tester.getTopLeft(row).dy;
      final before = builds;
      update(() => ids = [...ids]);
      await tester.pumpAndSettle();
      expect(builds, before);
      expect(tester.getTopLeft(row).dy, y);
      update(() => ids = [-3, -2, -1, ...ids]);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(row).dy, closeTo(y, 0.5));
      expect(tester.takeException(), isNull);
    },
  );
}
