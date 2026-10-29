///|
fn main {
  try {
    let polygon = @geo.Polygon::new([
      @geo.Point::new(0.0, 0.0),
      @geo.Point::new(4.0, 0.0),
      @geo.Point::new(4.0, 1.0),
      @geo.Point::new(1.0, 1.0),
      @geo.Point::new(1.0, 4.0),
      @geo.Point::new(0.0, 4.0),
    ])
    let index = @geo.RegionIndex::new()
    index.insert_polygon(7, polygon)
    let point = @geo.Point::new(2.0, 2.0)
    let report = index.query_point(point)
    assert_eq(report.candidates, 1)
    assert_eq(report.hits, [])
    assert_eq(report.decisions[0].location, @geo.Outside)
    println("L-shaped service area: candidates=1; exact region hits=0")
    let boundary = index.query_point(
      @geo.Point::new(1.0, 2.0),
      include_boundary=false,
    )
    assert_eq(boundary.decisions[0].location, @geo.OnBoundary)
    assert_eq(boundary.hits, [])
    println("boundary excluded from hits; diagnostic still reports OnBoundary")
  } catch {
    error => abort("region example failed: \{error}")
  }
}
