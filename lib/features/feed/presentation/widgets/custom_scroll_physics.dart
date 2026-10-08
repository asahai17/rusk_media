import 'package:flutter/widgets.dart';

// Smooth page-snap physics with paywall lock.
// Extends PageScrollPhysics (Flutter's built-in page snapping) for correct
// one-page-per-swipe behavior. No custom spring — uses Flutter's default
// which is already tuned for smooth, snappy page transitions.
class ReelScrollPhysics extends ScrollPhysics {
  final bool isLocked;
  final int lockedPageIndex;

  const ReelScrollPhysics({
    required this.isLocked,
    required this.lockedPageIndex,
    super.parent,
  });

  @override
  ReelScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReelScrollPhysics(
      isLocked: isLocked,
      lockedPageIndex: lockedPageIndex,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (isLocked) {
      final lockedExtent =
          lockedPageIndex.toDouble() * position.viewportDimension;
      if (value > lockedExtent) {
        return value - lockedExtent;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }
}
