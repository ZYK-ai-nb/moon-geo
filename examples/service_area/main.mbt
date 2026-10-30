///|
fn main {
  try {
    // Hypothetical service area on a local plane; coordinates are not GPS.
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

    // The excluded zone is inside the bounding box but outside the service area.
    let query = @geo.Point::new(3.0, 3.0)
    let before = index.query_point(query, include_boundary=false)
    assert_eq(before.revision, 1)
    assert_eq(before.candidates, 1)
    assert_eq(before.hits, [])
    assert_eq(before.decisions[0].location, @geo.Outside)
    println(
      "revision=1 point=(3,3): candidate=101, outside (inside excluded zone)",
    )

    // Boundary policy excludes the edge but keeps its diagnostic witness.
    let boundary = index.query_point(
      @geo.Point::new(2.0, 3.0),
      include_boundary=false,
    )
    assert_eq(boundary.hits, [])
    assert_eq(boundary.decisions[0].location, @geo.OnBoundary)
    guard boundary.decisions[0].boundary is Some(witness) else {
      abort("boundary witness missing")
    }
    assert_eq(witness.ring, 1)
    println(
      "revision=1 point=(2,3): boundary excluded; ring=\{witness.ring}, edge=\{witness.edge}",
    )

    // A policy change removes the exclusion; the same query must now match.
    let revised = @geo.MultiPolygon::from_polygon(@geo.Polygon::new(shell))
    assert_true(index.replace(101, revised))
    let after = index.query_point(query, include_boundary=false)
    assert_eq(after.revision, 2)
    assert_eq(after.hits, [101])
    assert_eq(after.decisions[0].location, @geo.Inside)
    println("revision=2 point=(3,3): inside; hits=[101]")

    assert_true(index.remove(101))
    let removed = index.query_point(query, include_boundary=false)
    assert_eq(removed.revision, 3)
    assert_eq(removed.candidates, 0)
    assert_eq(removed.hits, [])
    assert_eq(index.validate(), [])
    println("revision=3 point=(3,3): area removed; candidates=0")

    // The index needs no fixed world extent before adding a distant region.
    let distant = @geo.Polygon::new([
      @geo.Point::new(1000000.0, 1000000.0),
      @geo.Point::new(1000010.0, 1000000.0),
      @geo.Point::new(1000010.0, 1000010.0),
      @geo.Point::new(1000000.0, 1000010.0),
    ])
    index.insert_polygon(102, distant)
    let far = index.query_point(@geo.Point::new(1000005.0, 1000005.0))
    assert_eq(far.revision, 4)
    assert_eq(far.hits, [102])
    assert_eq(index.validate(), [])
    println("revision=4 distant region: hits=[102]; no fixed world extent")
  } catch {
    error => abort("service area example failed: \{error}")
  }
}
