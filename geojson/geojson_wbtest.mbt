///|
fn collection(
  geometry : String,
  id~ : String = "1",
  properties~ : String = "{}",
) -> String {
  "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":\{properties},\"id\":\{id},\"geometry\":\{geometry}}]}"
}

///|
fn rejected(text : String) -> Bool {
  try {
    ignore(parse_feature_collection(text))
    false
  } catch {
    _ => true
  }
}

///|
fn square_json() -> String {
  "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[10,0],[10,10],[0,10],[0,0]]]}"
}

///|
test "closed polygon holes preserve inside boundary outside" {
  let text = collection(
    "{\"type\":\"Polygon\",\"bbox\":[100,100,101,101],\"coordinates\":[[[0,0],[10,0],[10,10],[0,10],[0,0]],[[2,2],[4,2],[4,4],[2,4],[2,2]]]}",
  )
  let index = build_index(text)
  assert_eq(index.query_point(@geo.Point::new(1.0, 1.0)).hits, [1])
  let hole = index.query_point(@geo.Point::new(3.0, 3.0))
  assert_eq(hole.candidates, 1)
  assert_eq(hole.hits, [])
  assert_eq(hole.decisions[0].location, @geo.Outside)
  let boundary = index.query_point(@geo.Point::new(2.0, 3.0))
  assert_eq(boundary.decisions[0].location, @geo.OnBoundary)
  guard boundary.decisions[0].boundary is Some(w) else {
    fail("missing hole boundary")
  }
  assert_eq(w.ring, 1)
}

///|
test "multipolygon component gaps remain outside" {
  let text = collection(
    "{\"type\":\"MultiPolygon\",\"coordinates\":[[[[0,0],[1,0],[1,1],[0,1],[0,0]]],[[[3,0],[4,0],[4,1],[3,1],[3,0]]]]}",
    id="-7",
  )
  let index = build_index(text)
  assert_eq(index.query_point(@geo.Point::new(0.5, 0.5)).hits, [-7])
  assert_eq(index.query_point(@geo.Point::new(3.5, 0.5)).hits, [-7])
  let gap = index.query_point(@geo.Point::new(2.0, 0.5))
  assert_eq(gap.candidates, 1)
  assert_eq(gap.hits, [])
}

///|
test "unclosed and self crossing rings are rejected" {
  assert_true(
    rejected(
      collection(
        "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,0],[1,1],[0,1]]]}",
      ),
    ),
  )
  assert_true(
    rejected(
      collection(
        "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,1],[1,0],[0,1],[0,0]]]}",
      ),
    ),
  )
}

///|
test "positions reject elevation and invalid lonlat" {
  for
    shape in [
      "{\"type\":\"Polygon\",\"coordinates\":[[[0,0,5],[1,0,5],[1,1,5],[0,0,5]]]}",
      "{\"type\":\"Polygon\",\"coordinates\":[[[181,0],[182,0],[182,1],[181,0]]]}",
      "{\"type\":\"Polygon\",\"coordinates\":[[[0,91],[1,91],[1,92],[0,91]]]}", "{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1e999,0],[1,1],[0,0]]]}",
    ] {
    assert_true(rejected(collection(shape)))
  }
}

///|
test "antimeridian edges and overwide rings rejected" {
  assert_true(
    rejected(
      collection(
        "{\"type\":\"Polygon\",\"coordinates\":[[[179,0],[-179,0],[-179,1],[179,1],[179,0]]]}",
      ),
    ),
  )
  assert_true(
    rejected(
      collection(
        "{\"type\":\"Polygon\",\"coordinates\":[[[-120,0],[0,1],[120,0],[0,-1],[-120,0]]]}",
      ),
    ),
  )
}

///|
test "feature ids reject fractions overflow strings and duplicates" {
  for id in ["1.5", "2147483648", "-2147483649", "\"1\"", "null"] {
    assert_true(rejected(collection(square_json(), id~)))
  }
  assert_true(
    rejected(
      "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{},\"id\":1,\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,0],[1,1],[0,0]]]}},{\"type\":\"Feature\",\"properties\":{},\"id\":1,\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[2,0],[3,0],[3,1],[2,0]]]}}]}",
    ),
  )
  assert_true(
    rejected(
      "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,0],[1,1],[0,0]]]}}]}",
    ),
  )
}

///|
test "unsupported geometry and custom crs rejected" {
  assert_true(
    rejected(collection("{\"type\":\"Point\",\"coordinates\":[0,0]}")),
  )
  assert_true(
    rejected(
      collection(
        "{\"type\":\"Polygon\",\"crs\":null,\"coordinates\":[[[0,0],[1,0],[1,1],[0,0]]]}",
      ),
    ),
  )
  assert_true(
    rejected("{\"type\":\"FeatureCollection\",\"crs\":{},\"features\":[]}"),
  )
}

///|
test "duplicate JSON keys rejected and empty collection accepted" {
  assert_true(
    rejected(
      "{\"type\":\"FeatureCollection\",\"type\":\"FeatureCollection\",\"features\":[]}",
    ),
  )
  assert_eq(
    parse_feature_collection("{\"type\":\"FeatureCollection\",\"features\":[]}").length(),
    0,
  )
}

///|
test "empty multipolygon and bad capacity rejected" {
  assert_true(
    rejected(collection("{\"type\":\"MultiPolygon\",\"coordinates\":[]}")),
  )
  let bad = try {
    ignore(build_index(collection(square_json()), capacity=2))
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}

///|
test "feature properties require object or null" {
  assert_true(
    rejected(
      "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"id\":1,\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[1,0],[1,1],[0,0]]]}}]}",
    ),
  )
  for properties in ["[]", "1", "true", "\"invalid\""] {
    assert_true(rejected(collection(square_json(), properties~)))
  }
  assert_eq(
    parse_feature_collection(collection(square_json(), properties="null")).length(),
    1,
  )
}
