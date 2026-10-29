///|
fn main {
  try {
    let shell = [
      @geo.Point::new(0.0, 0.0),
      @geo.Point::new(10.0, 0.0),
      @geo.Point::new(10.0, 10.0),
      @geo.Point::new(0.0, 10.0),
    ]
    let hole = [
      @geo.Point::new(2.0, 2.0),
      @geo.Point::new(4.0, 2.0),
      @geo.Point::new(4.0, 4.0),
      @geo.Point::new(2.0, 4.0),
    ]
    let index = @geo.RegionIndex::new()
    index.insert_polygon(101, @geo.Polygon::new(shell, holes=[hole]))
    for
      point in [
        @geo.Point::new(1.0, 1.0),
        @geo.Point::new(3.0, 3.0),
        @geo.Point::new(2.0, 3.0),
      ] {
      let report = index.query_point(point)
      println(
        "point=(\{point.x()},\{point.y()}) candidates=\{report.candidates} hits=\{report.hits.length()}",
      )
      for decision in report.decisions {
        let label = match decision.location {
          @geo.Inside => "Inside"
          @geo.OnBoundary => "OnBoundary"
          @geo.Outside => "Outside"
        }
        println("  region=\{decision.id} location=\{label}")
        if decision.boundary is Some(w) {
          println("  witness: ring=\{w.ring} edge=\{w.edge}")
        }
      }
    }
    assert_eq(index.validate(), [])
  } catch {
    error => abort("demo failed: \{error}")
  }
}
