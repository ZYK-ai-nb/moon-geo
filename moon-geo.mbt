///|
/// Validated planar coordinates use caller-chosen units, not longitude/latitude.
/// The coordinate limit keeps squared distances and bounding-box areas finite.
pub suberror GeoError {
  InvalidCoordinate
  InvalidBounds
  InvalidRing(String)
  InvalidPolygon(String)
  InvalidCapacity
  DuplicateId(Int32)
} derive(Debug)

///|
struct Point {
  x : Double
  y : Double
} derive(Debug, Eq)

///|
pub fn Point::new(x : Double, y : Double) -> Point raise GeoError {
  if x.is_nan() || y.is_nan() || x.abs() > 1.0e100 || y.abs() > 1.0e100 {
    raise InvalidCoordinate
  }
  { x, y, }
}

///|
pub fn Point::x(self : Point) -> Double {
  self.x
}

///|
pub fn Point::y(self : Point) -> Double {
  self.y
}

///|
struct Segment {
  start : Point
  end : Point
} derive(Debug, Eq)

///|
pub fn Segment::new(start : Point, end : Point) -> Segment {
  { start, end, }
}

///|
pub fn Segment::start(self : Segment) -> Point {
  self.start
}

///|
pub fn Segment::end(self : Segment) -> Point {
  self.end
}

///|
struct BBox {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
} derive(Debug, Eq)

///|
pub fn BBox::new(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> BBox raise GeoError {
  ignore(Point::new(min_x, min_y))
  ignore(Point::new(max_x, max_y))
  if min_x > max_x || min_y > max_y {
    raise InvalidBounds
  }
  { min_x, min_y, max_x, max_y, }
}

///|
pub fn BBox::min_x(self : BBox) -> Double {
  self.min_x
}

///|
pub fn BBox::min_y(self : BBox) -> Double {
  self.min_y
}

///|
pub fn BBox::max_x(self : BBox) -> Double {
  self.max_x
}

///|
pub fn BBox::max_y(self : BBox) -> Double {
  self.max_y
}

///|
pub fn BBox::contains(self : BBox, p : Point) -> Bool {
  p.x >= self.min_x &&
  p.x <= self.max_x &&
  p.y >= self.min_y &&
  p.y <= self.max_y
}

///|
pub fn BBox::intersects(self : BBox, other : BBox) -> Bool {
  self.min_x <= other.max_x &&
  other.min_x <= self.max_x &&
  self.min_y <= other.max_y &&
  other.min_y <= self.max_y
}

///|
pub fn BBox::union(self : BBox, other : BBox) -> BBox {
  {
    min_x: self.min_x.min(other.min_x),
    min_y: self.min_y.min(other.min_y),
    max_x: self.max_x.max(other.max_x),
    max_y: self.max_y.max(other.max_y),
  }
}

///|
pub fn BBox::area(self : BBox) -> Double {
  (self.max_x - self.min_x) * (self.max_y - self.min_y)
}

///|
fn points_bounds(points : Array[Point]) -> BBox {
  let first = points[0]
  let mut bounds = {
    min_x: first.x,
    min_y: first.y,
    max_x: first.x,
    max_y: first.y,
  }
  for p in points {
    bounds = bounds.union({ min_x: p.x, min_y: p.y, max_x: p.x, max_y: p.y, })
  }
  bounds
}

///|
pub(all) enum SegmentRelation {
  Disjoint
  Touch(Point)
  Cross
  Overlap(Segment)
} derive(Debug, Eq)

///|
pub fn point_on_segment(p : Point, segment : Segment) -> Bool {
  orientation(segment.start, segment.end, p) == Collinear &&
  p.x >= segment.start.x.min(segment.end.x) &&
  p.x <= segment.start.x.max(segment.end.x) &&
  p.y >= segment.start.y.min(segment.end.y) &&
  p.y <= segment.start.y.max(segment.end.y)
}

///|
fn point_compare(a : Point, b : Point) -> Int32 {
  let x = a.x.compare(b.x)
  if x != 0 {
    x
  } else {
    a.y.compare(b.y)
  }
}

///|
pub fn segment_relation(a : Segment, b : Segment) -> SegmentRelation {
  let a1 = orientation(a.start, a.end, b.start)
  let a2 = orientation(a.start, a.end, b.end)
  let b1 = orientation(b.start, b.end, a.start)
  let b2 = orientation(b.start, b.end, a.end)
  let touches : Array[Point] = []
  for p in [a.start, a.end, b.start, b.end] {
    if point_on_segment(p, a) && point_on_segment(p, b) && !touches.contains(p) {
      touches.push(p)
    }
  }
  if touches.length() > 1 {
    touches.sort_by(point_compare)
    return Overlap(Segment::new(touches[0], touches[touches.length() - 1]))
  }
  if touches.length() == 1 {
    return Touch(touches[0])
  }
  if a1 != Collinear &&
    a2 != Collinear &&
    a1 != a2 &&
    b1 != Collinear &&
    b2 != Collinear &&
    b1 != b2 {
    Cross
  } else {
    Disjoint
  }
}

///|
fn hypot(x : Double, y : Double) -> Double {
  let scale = x.abs().max(y.abs())
  if scale == 0.0 {
    0.0
  } else {
    let a = x / scale
    let b = y / scale
    scale * (a * a + b * b).sqrt()
  }
}

///|
pub fn point_segment_distance(p : Point, segment : Segment) -> Double {
  let dx = segment.end.x - segment.start.x
  let dy = segment.end.y - segment.start.y
  let scale = dx.abs().max(dy.abs())
  if scale == 0.0 {
    return hypot(p.x - segment.start.x, p.y - segment.start.y)
  }
  let ux = dx / scale
  let uy = dy / scale
  let vx = (p.x - segment.start.x) / scale
  let vy = (p.y - segment.start.y) / scale
  let t = ((vx * ux + vy * uy) / (ux * ux + uy * uy)).clamp(min=0.0, max=1.0)
  if t.is_nan() {
    return hypot(p.x - segment.start.x, p.y - segment.start.y)
  }
  hypot(p.x - (segment.start.x + t * dx), p.y - (segment.start.y + t * dy))
}

///|
pub fn segment_distance(a : Segment, b : Segment) -> Double {
  if segment_relation(a, b) != Disjoint {
    return 0.0
  }
  point_segment_distance(a.start, b)
  .min(point_segment_distance(a.end, b))
  .min(point_segment_distance(b.start, a))
  .min(point_segment_distance(b.end, a))
}

///|
/// The monotone-chain hull contains extreme vertices only, in CCW order.
pub fn convex_hull(input : Array[Point]) -> Array[Point] {
  let sorted = input.copy()
  sorted.sort_by(point_compare)
  let points : Array[Point] = []
  for p in sorted {
    if points.last() != Some(p) {
      points.push(p)
    }
  }
  if points.length() <= 2 {
    return points
  }
  let lower : Array[Point] = []
  let upper : Array[Point] = []
  for p in points {
    while lower.length() >= 2 &&
          orientation(lower[lower.length() - 2], lower[lower.length() - 1], p) !=
          CCW {
      ignore(lower.pop())
    }
    lower.push(p)
  }
  for i = points.length() - 1; i >= 0; i = i - 1 {
    let p = points[i]
    while upper.length() >= 2 &&
          orientation(upper[upper.length() - 2], upper[upper.length() - 1], p) !=
          CCW {
      ignore(upper.pop())
    }
    upper.push(p)
  }
  ignore(lower.pop())
  ignore(upper.pop())
  for p in upper {
    lower.push(p)
  }
  lower
}
