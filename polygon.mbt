///|
pub(all) enum Location {
  Outside
  OnBoundary
  Inside
} derive(Debug, Eq)

///|
pub(all) enum FillRule {
  EvenOdd
  NonZero
} derive(Debug, Eq)

///|
/// Ring 0 is the shell; ring 1..n are holes. Edge indices refer to the
/// normalized, unclosed ring returned by Polygon::shell/holes.
pub(all) struct BoundaryWitness {
  ring : Int32
  edge : Int32
  segment : Segment
} derive(Debug, Eq)

///|
pub(all) struct LocationReport {
  location : Location
  boundary : BoundaryWitness?
} derive(Debug, Eq)

///|
struct Polygon {
  shell : Array[Point]
  holes : Array[Array[Point]]
  bounds : BBox
} derive(Debug)

///|
fn edge_at(ring : Array[Point], index : Int32) -> Segment {
  Segment::new(ring[index], ring[(index + 1) % ring.length()])
}

///|
fn normalize_ring(input : Array[Point]) -> Array[Point] raise GeoError {
  let ring = input.copy()
  if ring.length() > 1 && ring[0] == ring[ring.length() - 1] {
    ignore(ring.pop())
  }
  if ring.length() < 3 {
    raise InvalidRing("at least three vertices required")
  }
  let mut noncollinear = false
  for i in 0..<ring.length() {
    if ring[i] == ring[(i + 1) % ring.length()] {
      raise InvalidRing("zero-length edge")
    }
    if orientation(
        ring[i],
        ring[(i + 1) % ring.length()],
        ring[(i + 2) % ring.length()],
      ) !=
      Collinear {
      noncollinear = true
    }
    for j = i + 1; j < ring.length(); j = j + 1 {
      let adjacent = j == i + 1 || (i == 0 && j == ring.length() - 1)
      let relation = segment_relation(edge_at(ring, i), edge_at(ring, j))
      if adjacent {
        if relation is Overlap(_) {
          raise InvalidRing("adjacent edges overlap")
        }
      } else if relation != Disjoint {
        raise InvalidRing("self-intersection or repeated vertex")
      }
    }
  }
  if !noncollinear {
    raise InvalidRing("collinear ring")
  }
  ring
}

///|
fn ring_location(
  ring : Array[Point],
  p : Point,
  rule : FillRule,
) -> (Location, Int32?) {
  let mut winding = 0
  let mut odd = false
  for i in 0..<ring.length() {
    let a = ring[i]
    let b = ring[(i + 1) % ring.length()]
    if point_on_segment(p, Segment::new(a, b)) {
      return (OnBoundary, Some(i))
    }
    // Half-open Y intervals count a ray passing through a vertex only once.
    if a.y <= p.y && b.y > p.y && orientation(a, b, p) == CCW {
      winding = winding + 1
      odd = !odd
    } else if a.y > p.y && b.y <= p.y && orientation(a, b, p) == CW {
      winding = winding - 1
      odd = !odd
    }
  }
  let inside = match rule {
    EvenOdd => odd
    NonZero => winding != 0
  }
  (if inside { Inside } else { Outside }, None)
}

///|
fn rings_intersect(a : Array[Point], b : Array[Point]) -> Bool {
  for i in 0..<a.length() {
    for j in 0..<b.length() {
      if segment_relation(edge_at(a, i), edge_at(b, j)) != Disjoint {
        return true
      }
    }
  }
  false
}

///|
pub fn Polygon::new(
  shell : Array[Point],
  holes~ : Array[Array[Point]] = [],
) -> Polygon raise GeoError {
  let outer = normalize_ring(shell)
  let inner : Array[Array[Point]] = []
  for input in holes {
    let hole = normalize_ring(input)
    if rings_intersect(outer, hole) ||
      ring_location(outer, hole[0], EvenOdd).0 != Inside {
      raise InvalidPolygon("hole must lie strictly inside shell")
    }
    for previous in inner {
      if rings_intersect(previous, hole) ||
        ring_location(previous, hole[0], EvenOdd).0 != Outside ||
        ring_location(hole, previous[0], EvenOdd).0 != Outside {
        raise InvalidPolygon("holes must be disjoint and non-nested")
      }
    }
    inner.push(hole)
  }
  { shell: outer, holes: inner, bounds: points_bounds(outer), }
}

///|
pub fn Polygon::shell(self : Polygon) -> Array[Point] {
  self.shell.copy()
}

///|
pub fn Polygon::holes(self : Polygon) -> Array[Array[Point]] {
  self.holes.map(fn(r) { r.copy() })
}

///|
pub fn Polygon::bounds(self : Polygon) -> BBox {
  self.bounds
}

///|
pub fn Polygon::locate(
  self : Polygon,
  p : Point,
  rule~ : FillRule = EvenOdd,
) -> LocationReport {
  if !self.bounds.contains(p) {
    return { location: Outside, boundary: None, }
  }
  let (outer, edge) = ring_location(self.shell, p, rule)
  if edge is Some(i) {
    return {
      location: OnBoundary,
      boundary: Some({ ring: 0, edge: i, segment: edge_at(self.shell, i), }),
    }
  }
  if outer == Outside {
    return { location: Outside, boundary: None, }
  }
  for h in 0..<self.holes.length() {
    let (inner, edge) = ring_location(self.holes[h], p, rule)
    if edge is Some(i) {
      return {
        location: OnBoundary,
        boundary: Some({
          ring: h + 1,
          edge: i,
          segment: edge_at(self.holes[h], i),
        }),
      }
    }
    if inner == Inside {
      return { location: Outside, boundary: None, }
    }
  }
  { location: Inside, boundary: None, }
}

///|
/// Algebraic shoelace area of an arbitrary ring, including self-intersections.
/// This is a floating-point measurement, unlike exact topological predicates.
pub fn signed_area(ring : Array[Point]) -> Double {
  if ring.length() < 3 {
    return 0.0
  }
  let origin = ring[0]
  let mut sum = 0.0
  let mut correction = 0.0
  for i in 1..<(ring.length() - 1) {
    let cross = (ring[i].x - origin.x) * (ring[i + 1].y - origin.y) -
      (ring[i].y - origin.y) * (ring[i + 1].x - origin.x)
    let value = cross - correction
    let next = sum + value
    correction = next - sum - value
    sum = next
  }
  sum / 2.0
}

///|
pub fn Polygon::area(self : Polygon) -> Double {
  let mut area = signed_area(self.shell).abs()
  for hole in self.holes {
    area = area - signed_area(hole).abs()
  }
  area.max(0.0)
}

///|
fn ring_centroid(ring : Array[Point]) -> Point? {
  let origin = ring[0]
  let mut twice_area = 0.0
  let mut x = 0.0
  let mut y = 0.0
  for i in 0..<ring.length() {
    let a = ring[i]
    let b = ring[(i + 1) % ring.length()]
    let ax = a.x - origin.x
    let ay = a.y - origin.y
    let bx = b.x - origin.x
    let by = b.y - origin.y
    let cross = ax * by - ay * bx
    twice_area = twice_area + cross
    x = x + (ax + bx) * cross
    y = y + (ay + by) * cross
  }
  if twice_area == 0.0 {
    return None
  }
  Some({
    x: origin.x + x / (3.0 * twice_area),
    y: origin.y + y / (3.0 * twice_area),
  })
}

///|
/// None means the floating area collapsed to zero or a measurement overflowed.
pub fn Polygon::centroid(self : Polygon) -> Point? {
  let area = self.area()
  if area == 0.0 {
    return None
  }
  guard ring_centroid(self.shell) is Some(shell_center) else { return None }
  let mut x = shell_center.x
  let mut y = shell_center.y
  for hole in self.holes {
    let weight = signed_area(hole).abs() / area
    if weight != 0.0 {
      guard ring_centroid(hole) is Some(center) else { return None }
      x = x + (shell_center.x - center.x) * weight
      y = y + (shell_center.y - center.y) * weight
    }
  }
  Some(Point::new(x, y)) catch {
    _ => None
  }
}

///|
struct MultiPolygon {
  polygons : Array[Polygon]
} derive(Debug)

///|
/// Filled components must be strictly separated; touching or overlapping filled
/// regions are rejected. A separate island inside another component's hole is valid.
pub fn MultiPolygon::new(
  polygons : Array[Polygon],
) -> MultiPolygon raise GeoError {
  for i in 0..<polygons.length() {
    for j in 0..<i {
      let a = polygons[i]
      let b = polygons[j]
      if a.bounds.intersects(b.bounds) {
        let a_rings = [a.shell]
        for h in a.holes {
          a_rings.push(h)
        }
        let b_rings = [b.shell]
        for h in b.holes {
          b_rings.push(h)
        }
        for ar in a_rings {
          for br in b_rings {
            if rings_intersect(ar, br) {
              raise InvalidPolygon("components touch or intersect")
            }
          }
        }
        if a.locate(b.shell[0]).location != Outside ||
          b.locate(a.shell[0]).location != Outside {
          raise InvalidPolygon("components overlap or nest")
        }
      }
    }
  }
  { polygons: polygons.copy(), }
}

///|
pub fn MultiPolygon::from_polygon(polygon : Polygon) -> MultiPolygon {
  { polygons: [polygon], }
}

///|
pub fn MultiPolygon::polygons(self : MultiPolygon) -> Array[Polygon] {
  self.polygons.copy()
}

///|
pub fn MultiPolygon::bounds(self : MultiPolygon) -> BBox? {
  if self.polygons.is_empty() {
    return None
  }
  let mut bounds = self.polygons[0].bounds
  for p in self.polygons {
    bounds = bounds.union(p.bounds)
  }
  Some(bounds)
}
