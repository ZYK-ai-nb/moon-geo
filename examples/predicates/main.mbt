///|
fn main {
  try {
    let a = @geo.Point::new(134217728.0, 134217729.0)
    let b = @geo.Point::new(134217729.0, 134217730.0)
    let c = @geo.Point::new(0.0, 0.0)
    let ordinary = (b.x() - a.x()) * (c.y() - a.y()) -
      (b.y() - a.y()) * (c.x() - a.x())
    // Use the same algebraic form as the cancellation fixture.
    let cancelled = a.x() * b.y() - a.y() * b.x()
    let report = @geo.orientation_report(a, b, c)
    assert_eq(cancelled, 0.0)
    assert_eq(report.orientation, @geo.CW)
    assert_eq(report.arithmetic, @geo.ExactDyadic)
    println("ordinary cross product at origin: \{cancelled}")
    println("translated ordinary determinant: \{ordinary}")
    println("exact sign: CW; arithmetic: ExactDyadic")
  } catch {
    error => abort("predicate example failed: \{error}")
  }
}
