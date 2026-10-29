///|
fn tp(x : Double, y : Double) -> Point raise GeoError {
  Point::new(x, y)
}

///|
fn square(x : Double, y : Double, size : Double) -> Array[Point] raise GeoError {
  [tp(x, y), tp(x + size, y), tp(x + size, y + size), tp(x, y + size)]
}

///|
fn rejected_point(x : Double, y : Double) -> Bool {
  try {
    ignore(Point::new(x, y))
    false
  } catch {
    _ => true
  }
}

///|
fn rejected_polygon(
  shell : Array[Point],
  holes~ : Array[Array[Point]] = [],
) -> Bool {
  try {
    ignore(Polygon::new(shell, holes~))
    false
  } catch {
    _ => true
  }
}

///|
test "coordinate magnitude limit" {
  assert_true(rejected_point(1.0e101, 0.0))
}

///|
test "NaN rejected" {
  assert_true(rejected_point(0.0 / 0.0, 0.0))
}

///|
test "infinity rejected" {
  assert_true(rejected_point(0.0, 1.0 / 0.0))
}

///|
test "signed zero accepted" {
  assert_eq(tp(-0.0, 0.0), tp(0.0, 0.0))
}

///|
test "inverted bbox rejected" {
  let rejected = try {
    ignore(BBox::new(1.0, 0.0, 0.0, 1.0))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "bbox touching counts" {
  assert_true(
    BBox::new(0.0, 0.0, 1.0, 1.0).intersects(BBox::new(1.0, 1.0, 2.0, 2.0)),
  )
}

///|
test "bbox union" {
  assert_eq(
    BBox::new(0.0, 0.0, 1.0, 1.0).union(BBox::new(-1.0, 0.5, 2.0, 3.0)),
    BBox::new(-1.0, 0.0, 2.0, 3.0),
  )
}

///|
test "orientation three states" {
  assert_eq(orientation(tp(0.0, 0.0), tp(1.0, 0.0), tp(0.0, 1.0)), CCW)
  assert_eq(orientation(tp(0.0, 0.0), tp(0.0, 1.0), tp(1.0, 0.0)), CW)
  assert_eq(orientation(tp(0.0, 0.0), tp(1.0, 1.0), tp(2.0, 2.0)), Collinear)
}

///|
test "ordinary determinant cancellation exact fallback" {
  let a = tp(134217728.0, 134217729.0)
  let b = tp(134217729.0, 134217730.0)
  let c = tp(0.0, 0.0)
  assert_eq((b.x - c.x) * (a.y - c.y) - (b.y - c.y) * (a.x - c.x), 0.0)
  assert_eq(orientation_report(a, b, c), {
    orientation: CW,
    arithmetic: ExactDyadic,
  })
}

///|
test "tiny noncollinear values are not snapped to collinear" {
  let report = orientation_report(
    tp(0.0, 0.0),
    tp(1.0e-200, 0.0),
    tp(0.0, 1.0e-200),
  )
  assert_eq(report.orientation, CCW)
  assert_eq(report.arithmetic, ExactDyadic)
}

///|
test "small normal triangle passes filter" {
  assert_eq(
    orientation_report(tp(0.0, 0.0), tp(1.0e-6, 0.0), tp(0.0, 1.0e-6)).orientation,
    CCW,
  )
}

///|
test "subnormal coordinates retain exact sign" {
  let s = 1UL.reinterpret_as_double()
  assert_eq(orientation(tp(0.0, 0.0), tp(s, 0.0), tp(0.0, s)), CCW)
}

///|
test "large finite coordinates exact collinearity" {
  assert_eq(
    orientation(tp(-1.0e100, -1.0e100), tp(0.0, 0.0), tp(1.0e100, 1.0e100)),
    Collinear,
  )
}

///|
test "repeated point is collinear" {
  assert_eq(orientation(tp(1.0, 2.0), tp(1.0, 2.0), tp(3.0, 4.0)), Collinear)
}

///|
test "ordinary orientation uses filtered path" {
  assert_eq(
    orientation_report(tp(0.0, 0.0), tp(1.0, 0.0), tp(0.0, 1.0)).arithmetic,
    Filtered,
  )
}

///|
test "proper segment cross" {
  assert_eq(
    segment_relation(
      Segment::new(tp(0.0, 0.0), tp(2.0, 2.0)),
      Segment::new(tp(0.0, 2.0), tp(2.0, 0.0)),
    ),
    Cross,
  )
}

///|
test "segment endpoint contact" {
  assert_eq(
    segment_relation(
      Segment::new(tp(0.0, 0.0), tp(1.0, 0.0)),
      Segment::new(tp(1.0, 0.0), tp(1.0, 1.0)),
    ),
    Touch(tp(1.0, 0.0)),
  )
}

///|
test "collinear segment overlap canonical endpoints" {
  assert_eq(
    segment_relation(
      Segment::new(tp(3.0, 0.0), tp(0.0, 0.0)),
      Segment::new(tp(1.0, 0.0), tp(4.0, 0.0)),
    ),
    Overlap(Segment::new(tp(1.0, 0.0), tp(3.0, 0.0))),
  )
}

///|
test "parallel disjoint segments" {
  assert_eq(
    segment_relation(
      Segment::new(tp(0.0, 0.0), tp(1.0, 0.0)),
      Segment::new(tp(0.0, 1.0), tp(1.0, 1.0)),
    ),
    Disjoint,
  )
}

///|
test "collinear disjoint segments" {
  assert_eq(
    segment_relation(
      Segment::new(tp(0.0, 0.0), tp(1.0, 0.0)),
      Segment::new(tp(2.0, 0.0), tp(3.0, 0.0)),
    ),
    Disjoint,
  )
}

///|
test "zero length segment on another" {
  assert_eq(
    segment_relation(
      Segment::new(tp(0.5, 0.0), tp(0.5, 0.0)),
      Segment::new(tp(0.0, 0.0), tp(1.0, 0.0)),
    ),
    Touch(tp(0.5, 0.0)),
  )
}

///|
test "two distinct zero length segments" {
  assert_eq(
    segment_relation(
      Segment::new(tp(0.0, 0.0), tp(0.0, 0.0)),
      Segment::new(tp(1.0, 1.0), tp(1.0, 1.0)),
    ),
    Disjoint,
  )
}

///|
test "two equal zero length segments" {
  assert_eq(
    segment_relation(
      Segment::new(tp(1.0, 1.0), tp(1.0, 1.0)),
      Segment::new(tp(1.0, 1.0), tp(1.0, 1.0)),
    ),
    Touch(tp(1.0, 1.0)),
  )
}

///|
test "point distance projection" {
  assert_eq(
    point_segment_distance(
      tp(1.0, 2.0),
      Segment::new(tp(0.0, 0.0), tp(2.0, 0.0)),
    ),
    2.0,
  )
}

///|
test "point distance outside endpoint" {
  assert_eq(
    point_segment_distance(
      tp(5.0, 4.0),
      Segment::new(tp(0.0, 0.0), tp(2.0, 0.0)),
    ),
    5.0,
  )
}

///|
test "point distance zero segment" {
  assert_eq(
    point_segment_distance(
      tp(3.0, 4.0),
      Segment::new(tp(0.0, 0.0), tp(0.0, 0.0)),
    ),
    5.0,
  )
}

///|
test "intersecting segment distance is zero" {
  assert_eq(
    segment_distance(
      Segment::new(tp(0.0, 0.0), tp(1.0, 1.0)),
      Segment::new(tp(1.0, 0.0), tp(0.0, 1.0)),
    ),
    0.0,
  )
}

///|
test "parallel segment distance" {
  assert_eq(
    segment_distance(
      Segment::new(tp(0.0, 0.0), tp(1.0, 0.0)),
      Segment::new(tp(0.0, 2.0), tp(1.0, 2.0)),
    ),
    2.0,
  )
}

///|
test "unit square area and centroid" {
  let polygon = Polygon::new(square(0.0, 0.0, 1.0))
  assert_eq(polygon.area(), 1.0)
  assert_eq(polygon.centroid(), Some(tp(0.5, 0.5)))
}

///|
test "unit square three locations" {
  let polygon = Polygon::new(square(0.0, 0.0, 1.0))
  assert_eq(polygon.locate(tp(0.5, 0.5)).location, Inside)
  assert_eq(polygon.locate(tp(1.0, 1.0)).location, OnBoundary)
  assert_eq(polygon.locate(tp(2.0, 2.0)).location, Outside)
}

///|
test "boundary witness can be independently checked" {
  let polygon = Polygon::new(square(0.0, 0.0, 1.0))
  let point = tp(1.0, 0.25)
  guard polygon.locate(point).boundary is Some(witness) else {
    fail("missing witness")
  }
  assert_eq(witness.ring, 0)
  assert_eq(witness.edge, 1)
  assert_true(point_on_segment(point, witness.segment))
}

///|
test "explicitly closed ring normalized" {
  let input = square(0.0, 0.0, 1.0)
  input.push(input[0])
  assert_eq(Polygon::new(input).shell().length(), 4)
}

///|
test "ring input and accessor are defensive copies" {
  let input = square(0.0, 0.0, 1.0)
  let polygon = Polygon::new(input)
  input.clear()
  polygon.shell().clear()
  assert_eq(polygon.area(), 1.0)
}

///|
test "hole removes area and excludes center" {
  let polygon = Polygon::new(square(0.0, 0.0, 10.0), holes=[
    square(2.0, 2.0, 2.0),
  ])
  assert_eq(polygon.area(), 96.0)
  assert_eq(polygon.locate(tp(3.0, 3.0)).location, Outside)
  assert_eq(polygon.locate(tp(1.0, 1.0)).location, Inside)
}

///|
test "hole boundary report" {
  let polygon = Polygon::new(square(0.0, 0.0, 10.0), holes=[
    square(2.0, 2.0, 2.0),
  ])
  let report = polygon.locate(tp(2.0, 3.0))
  assert_eq(report.location, OnBoundary)
  guard report.boundary is Some(witness) else { fail("missing hole witness") }
  assert_eq(witness.ring, 1)
}

///|
test "symmetric hole centroid" {
  assert_eq(
    Polygon::new(square(0.0, 0.0, 10.0), holes=[square(4.0, 4.0, 2.0)]).centroid(),
    Some(tp(5.0, 5.0)),
  )
}

///|
test "winding order does not change shell semantics" {
  let input = square(0.0, 0.0, 2.0)
  input.rev_in_place()
  let polygon = Polygon::new(input)
  assert_eq(polygon.area(), 4.0)
  assert_eq(polygon.locate(tp(1.0, 1.0), rule=NonZero).location, Inside)
}

///|
test "concave bbox false positive is outside" {
  let polygon = Polygon::new([
    tp(0.0, 0.0),
    tp(4.0, 0.0),
    tp(4.0, 1.0),
    tp(1.0, 1.0),
    tp(1.0, 4.0),
    tp(0.0, 4.0),
  ])
  assert_true(polygon.bounds().contains(tp(2.0, 2.0)))
  assert_eq(polygon.locate(tp(2.0, 2.0)).location, Outside)
}

///|
test "empty polygon rejected" {
  assert_true(rejected_polygon([]))
}

///|
test "line polygon rejected" {
  assert_true(rejected_polygon([tp(0.0, 0.0), tp(1.0, 0.0), tp(2.0, 0.0)]))
}

///|
test "self intersecting polygon rejected" {
  assert_true(
    rejected_polygon([tp(0.0, 0.0), tp(2.0, 2.0), tp(0.0, 2.0), tp(2.0, 0.0)]),
  )
}

///|
test "consecutive duplicate rejected" {
  assert_true(
    rejected_polygon([tp(0.0, 0.0), tp(1.0, 0.0), tp(1.0, 0.0), tp(0.0, 1.0)]),
  )
}

///|
test "hole outside shell rejected" {
  assert_true(
    rejected_polygon(square(0.0, 0.0, 4.0), holes=[square(5.0, 5.0, 1.0)]),
  )
}

///|
test "touching hole rejected" {
  assert_true(
    rejected_polygon(square(0.0, 0.0, 4.0), holes=[square(0.0, 1.0, 1.0)]),
  )
}

///|
test "overlapping holes rejected" {
  assert_true(
    rejected_polygon(square(0.0, 0.0, 10.0), holes=[
      square(1.0, 1.0, 3.0),
      square(2.0, 2.0, 3.0),
    ]),
  )
}

///|
test "nested holes rejected" {
  assert_true(
    rejected_polygon(square(0.0, 0.0, 10.0), holes=[
      square(1.0, 1.0, 6.0),
      square(2.0, 2.0, 1.0),
    ]),
  )
}

///|
test "tiny polygon topology survives area underflow" {
  let polygon = Polygon::new(square(0.0, 0.0, 1.0e-200))
  assert_eq(polygon.area(), 0.0)
  assert_eq(polygon.centroid(), None)
  assert_eq(polygon.locate(tp(5.0e-201, 5.0e-201)).location, Inside)
}

///|
test "specific symmetric bowtie algebraic area zero" {
  assert_eq(
    signed_area([tp(0.0, 0.0), tp(2.0, 2.0), tp(0.0, 2.0), tp(2.0, 0.0)]),
    0.0,
  )
}

///|
test "unequal lobes algebraic area need not be zero" {
  assert_eq(
    signed_area([tp(0.0, 0.0), tp(2.0, 3.0), tp(0.0, 3.0), tp(4.0, 0.0)]),
    -3.0,
  )
}

///|
test "empty area zero" {
  assert_eq(signed_area([]), 0.0)
}

///|
test "empty hull" {
  assert_eq(convex_hull([]), [])
}

///|
test "collinear hull is two extremes" {
  assert_eq(convex_hull([tp(1.0, 0.0), tp(0.0, 0.0), tp(2.0, 0.0)]), [
    tp(0.0, 0.0),
    tp(2.0, 0.0),
  ])
}

///|
test "duplicate hull singleton" {
  assert_eq(convex_hull([tp(1.0, 1.0), tp(1.0, 1.0)]), [tp(1.0, 1.0)])
}

///|
test "hull excludes interior points" {
  let points = square(0.0, 0.0, 2.0)
  points.push(tp(1.0, 1.0))
  assert_eq(convex_hull(points), square(0.0, 0.0, 2.0))
}

///|
test "separated multipolygon" {
  assert_true(
    MultiPolygon::new([
      Polygon::new(square(0.0, 0.0, 1.0)),
      Polygon::new(square(2.0, 0.0, 1.0)),
    ]).bounds()
    is Some(_),
  )
}

///|
test "touching multipolygon rejected" {
  let rejected = try {
    ignore(
      MultiPolygon::new([
        Polygon::new(square(0.0, 0.0, 1.0)),
        Polygon::new(square(1.0, 0.0, 1.0)),
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "empty multipolygon has no bounds" {
  assert_eq(MultiPolygon::new([]).bounds(), None)
}

///|
test "asymmetric hole centroid matches analytic value" {
  let polygon = Polygon::new(square(0.0, 0.0, 10.0), holes=[
    square(2.0, 2.0, 2.0),
  ])
  guard polygon.centroid() is Some(center) else { fail("missing centroid") }
  assert_true((center.x() - 61.0 / 12.0).abs() < 1.0e-12)
  assert_true((center.y() - 61.0 / 12.0).abs() < 1.0e-12)
}

///|
test "hole input and accessor are defensive copies" {
  let hole = square(2.0, 2.0, 2.0)
  let polygon = Polygon::new(square(0.0, 0.0, 10.0), holes=[hole])
  hole.clear()
  polygon.holes()[0].clear()
  assert_eq(polygon.locate(tp(3.0, 3.0)).location, Outside)
}

///|
test "multipolygon island inside a hole is valid" {
  let outer = Polygon::new(square(0.0, 0.0, 10.0), holes=[square(2.0, 2.0, 6.0)])
  let island = Polygon::new(square(3.0, 3.0, 1.0))
  assert_eq(MultiPolygon::new([outer, island]).polygons().length(), 2)
}

///|
test "overlapping multipolygon rejected" {
  let rejected = try {
    ignore(
      MultiPolygon::new([
        Polygon::new(square(0.0, 0.0, 3.0)),
        Polygon::new(square(2.0, 2.0, 3.0)),
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "large coordinate distance remains finite" {
  let distance = point_segment_distance(
    tp(1.0e100, 1.0e100),
    Segment::new(tp(0.0, 0.0), tp(1.0e100, 0.0)),
  )
  assert_eq(distance, 1.0e100)
}
