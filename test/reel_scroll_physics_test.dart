import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_television/features/feed/presentation/widgets/custom_scroll_physics.dart';

void main() {
  group('applyBoundaryConditions', () {
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 7200,
      pixels: 6400,
      viewportDimension: 800,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

    test('clamps any movement past the locked page', () {
      final physics = ReelScrollPhysics(lockedPage: () => 8);
      expect(physics.applyBoundaryConditions(metrics, 6500), 100);
      expect(physics.applyBoundaryConditions(metrics, 7200), 800);
    });

    test('leaves backward movement alone', () {
      final physics = ReelScrollPhysics(lockedPage: () => 8);
      expect(physics.applyBoundaryConditions(metrics, 6000), 0);
      expect(physics.applyBoundaryConditions(metrics, 0), 0);
    });

    test('is transparent once unlocked, without a new instance', () {
      int? locked = 8;
      final physics = ReelScrollPhysics(lockedPage: () => locked);
      expect(physics.applyBoundaryConditions(metrics, 6500), 100);
      locked = null;
      expect(physics.applyBoundaryConditions(metrics, 6500), 0);
    });
  });

  testWidgets('a fling past the locked page does not move; after unlock it does', (
    tester,
  ) async {
    int? locked = 2;
    final controller = PageController(initialPage: 2);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PageView.builder(
          controller: controller,
          scrollDirection: Axis.vertical,
          physics: ReelScrollPhysics(lockedPage: () => locked),
          itemCount: 5,
          itemBuilder: (_, i) => Center(child: Text('P$i')),
        ),
      ),
    );

    Future<void> fling(double dy) async {
      await tester.fling(find.byType(PageView), Offset(0, dy), 2000);
      await tester.pumpAndSettle();
    }

    await fling(-400);
    expect(controller.page, 2.0, reason: 'locked: the fling is absorbed');

    await fling(400);
    expect(controller.page, 1.0, reason: 'backward scroll always works');

    await fling(-400);
    expect(controller.page, 2.0);

    locked = null;
    await fling(-400);
    expect(controller.page, 3.0, reason: 'unlocked: the fling moves on');
  });
}
