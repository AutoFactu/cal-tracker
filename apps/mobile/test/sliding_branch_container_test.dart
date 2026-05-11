import 'package:cal_tracker_mobile/ui/core/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('slides from the previous branch to the current branch',
      (tester) async {
    final branchKeys = [GlobalKey(), GlobalKey(), GlobalKey()];

    await tester.pumpWidget(_BranchHarness(
      currentIndex: 0,
      branchKeys: branchKeys,
    ));

    expect(find.text('Branch 0'), findsOneWidget);
    expect(find.text('Branch 1'), findsNothing);
    expect(find.text('Branch 1', skipOffstage: false), findsOneWidget);

    await tester.pumpWidget(_BranchHarness(
      currentIndex: 1,
      branchKeys: branchKeys,
    ));
    await tester.pump();

    expect(find.text('Branch 0'), findsOneWidget);
    expect(find.text('Branch 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(ImageFiltered), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(find.text('Branch 0'), findsNothing);
    expect(find.text('Branch 0', skipOffstage: false), findsOneWidget);
    expect(find.text('Branch 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _BranchHarness extends StatelessWidget {
  const _BranchHarness({
    required this.currentIndex,
    required this.branchKeys,
  });

  final int currentIndex;
  final List<GlobalKey> branchKeys;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SizedBox.expand(
        child: SlidingBranchContainer(
          currentIndex: currentIndex,
          children: [
            for (var index = 0; index < branchKeys.length; index++)
              KeyedSubtree(
                key: branchKeys[index],
                child: Center(child: Text('Branch $index')),
              ),
          ],
        ),
      ),
    );
  }
}
