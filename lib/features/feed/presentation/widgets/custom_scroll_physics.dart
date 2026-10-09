import 'package:flutter/widgets.dart';

/// Paywall lock physics. PageView wraps this in its own PageScrollPhysics,
/// so page snapping is Flutter's default; this layer only clamps forward
/// scroll at the locked page while leaving backward scroll untouched.
///
/// The locked page is read through [lockedPage] on every scroll update rather
/// than captured at construction: Scrollable keeps its ScrollPosition (and
/// the physics inside it) as long as the physics *type* is unchanged, so a
/// new instance with a different value would never take effect.
class ReelScrollPhysics extends ScrollPhysics {
  /// Page index the user may not scroll past, or null when nothing is locked.
  final int? Function() lockedPage;

  const ReelScrollPhysics({required this.lockedPage, super.parent});

  @override
  ReelScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReelScrollPhysics(
      lockedPage: lockedPage,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final locked = lockedPage();
    if (locked != null) {
      final lockedExtent = locked * position.viewportDimension;
      if (value > lockedExtent) {
        return value - lockedExtent;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }
}
