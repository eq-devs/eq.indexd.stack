/// Which transitioning page paints above the other.
///
/// With complementary fades, the top layer dominates the eye. Flutter `Stack`
/// (and ant's tab shell) paints in **child index order** — higher index on
/// top — so forward vs back switches are not symmetric.
enum IndexdPaintOrder {
  /// Incoming page paints above outgoing (Material-style arrive).
  incomingOnTop,

  /// Outgoing page paints above incoming (softer settle).
  outgoingOnTop,

  /// Same as Flutter `Stack`: lower index paints first, higher index on top.
  /// This is the [IndexdAnimationType.scaleIn] default (ant tab-shell parity).
  stack,
}
