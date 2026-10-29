///|
test "public validated point" {
  let point = @moon-geo.Point::new(1.0, 2.0)
  assert_eq(point.x(), 1.0)
}

///|
test "orientation reverses for integer triples" {
  @qc.check(
    (t : (Int32, Int32, Int32)) => {
      let a = @moon-geo.Point::new((t.0 % 10000).to_double(), 0.0)
      let b = @moon-geo.Point::new(0.0, (t.1 % 10000).to_double())
      let c = @moon-geo.Point::new((t.2 % 10000).to_double(), 1.0)
      let forward = @moon-geo.orientation(a, b, c)
      let reverse = @moon-geo.orientation(b, a, c)
      (forward == @moon-geo.CCW && reverse == @moon-geo.CW) ||
      (forward == @moon-geo.CW && reverse == @moon-geo.CCW) ||
      (forward == @moon-geo.Collinear && reverse == @moon-geo.Collinear)
    },
    count=200U,
    seed=29102026UL,
  )
}

///|
test "segment classification is symmetric" {
  @qc.check(
    (v : (Int32, Int32, Int32, Int32)) => {
      let a = @moon-geo.Segment::new(
        @moon-geo.Point::new((v.0 % 50).to_double(), 0.0),
        @moon-geo.Point::new((v.1 % 50).to_double(), 5.0),
      )
      let b = @moon-geo.Segment::new(
        @moon-geo.Point::new((v.2 % 50).to_double(), 0.0),
        @moon-geo.Point::new((v.3 % 50).to_double(), 5.0),
      )
      @moon-geo.segment_relation(a, b) == @moon-geo.segment_relation(b, a)
    },
    count=200U,
    seed=321UL,
  )
}

///|
test "simple polygon fill rules agree away from boundaries" {
  let polygon = @moon-geo.Polygon::new([
    @moon-geo.Point::new(-10.0, -10.0),
    @moon-geo.Point::new(10.0, -10.0),
    @moon-geo.Point::new(10.0, 10.0),
    @moon-geo.Point::new(-10.0, 10.0),
  ])
  @qc.check(
    (v : (Int32, Int32)) => {
      let point = @moon-geo.Point::new(
        (v.0 % 60).to_double() / 2.0,
        (v.1 % 60).to_double() / 2.0,
      )
      polygon.locate(point, rule=@moon-geo.EvenOdd).location ==
      polygon.locate(point, rule=@moon-geo.NonZero).location
    },
    count=300U,
    seed=456UL,
  )
}

///|
test "convex hull encloses inputs and uses input vertices" {
  @qc.check(
    (values : Array[(Int32, Int32)]) => {
      let points : Array[@moon-geo.Point] = []
      for i in 0..<values.length().min(40) {
        points.push(
          @moon-geo.Point::new(
            (values[i].0 % 100).to_double(),
            (values[i].1 % 100).to_double(),
          ),
        )
      }
      let hull = @moon-geo.convex_hull(points)
      if hull.length() > points.length() {
        return false
      }
      for h in hull {
        if !points.contains(h) {
          return false
        }
      }
      if hull.length() >= 3 {
        for i in 0..<hull.length() {
          for p in points {
            if @moon-geo.orientation(hull[i], hull[(i + 1) % hull.length()], p) ==
              @moon-geo.CW {
              return false
            }
          }
        }
      }
      true
    },
    count=100U,
    seed=789UL,
  )
}
