///|
struct TestRng {
  mut state : UInt32
}

///|
fn TestRng::next(self : TestRng, limit : Int32) -> Int32 {
  self.state = self.state * 1664525U + 1013904223U
  ((self.state >> 8) % limit.reinterpret_as_uint()).reinterpret_as_int()
}

///|
fn random_box(rng : TestRng) -> BBox raise GeoError {
  let x = (rng.next(2000) - 1000).to_double()
  let y = (rng.next(2000) - 1000).to_double()
  BBox::new(x, y, x + rng.next(80).to_double(), y + rng.next(80).to_double())
}

///|
fn brute_ids(entries : Map[Int32, BBox], query : BBox) -> Array[Int32] {
  let ids : Array[Int32] = []
  for id, b in entries {
    if b.min_x <= query.max_x &&
      b.max_x >= query.min_x &&
      b.min_y <= query.max_y &&
      b.max_y >= query.min_y {
      ids.push(id)
    }
  }
  ids.sort()
  ids
}

///|
fn actual_ids(tree : RTree, query : BBox) -> Array[Int32] {
  tree.query(query).entries.map(fn(e) { e.id })
}

///|
test "empty R-tree" {
  let tree = RTree::new()
  assert_eq(tree.stats(), {
    entries: 0,
    height: 0,
    nodes: 0,
    leaves: 0,
    splits: 0,
    condenses: 0,
  })
  assert_eq(actual_ids(tree, BBox::new(0.0, 0.0, 1.0, 1.0)), [])
  assert_eq(tree.validate(), [])
}

///|
test "invalid R-tree capacity rejected" {
  for capacity in [0, 3, 129] {
    let rejected = try {
      ignore(RTree::new(capacity~))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "R-tree exact bbox boundary and zero area entry" {
  let tree = RTree::new()
  tree.insert(-1, BBox::new(1.0, 1.0, 1.0, 1.0))
  assert_eq(actual_ids(tree, BBox::new(0.0, 0.0, 1.0, 1.0)), [-1])
  assert_eq(actual_ids(tree, BBox::new(0.0, 0.0, 0.5, 0.5)), [])
}

///|
test "duplicate ID rejected without mutation" {
  let tree = RTree::new()
  tree.insert(7, BBox::new(0.0, 0.0, 1.0, 1.0))
  let rejected = try {
    tree.insert(7, BBox::new(5.0, 5.0, 6.0, 6.0))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(tree.length(), 1)
  assert_eq(actual_ids(tree, BBox::new(0.0, 0.0, 1.0, 1.0)), [7])
}

///|
test "leaf splits are real" {
  let tree = RTree::new(capacity=4)
  for id in 0..<5 {
    tree.insert(id, BBox::new(id.to_double(), 0.0, id.to_double() + 0.5, 1.0))
  }
  assert_eq(tree.stats().height, 2)
  assert_eq(tree.stats().leaves, 2)
  assert_eq(tree.stats().splits, 1)
  assert_eq(tree.validate(), [])
}

///|
test "identical rectangles terminate and split" {
  let tree = RTree::new(capacity=4)
  for id in 0..<60 {
    tree.insert(id, BBox::new(0.0, 0.0, 1.0, 1.0))
  }
  assert_eq(tree.query(BBox::new(0.5, 0.5, 0.5, 0.5)).entries.length(), 60)
  assert_true(tree.stats().height >= 3)
  assert_eq(tree.validate(), [])
}

///|
test "500 seeded rectangles match brute force over 200 ranges" {
  let rng = { state: 20261029U, }
  let tree = RTree::new(capacity=4)
  let entries : Map[Int32, BBox] = Map([])
  for id in 0..<500 {
    let bounds = random_box(rng)
    entries[id] = bounds
    tree.insert(id, bounds)
  }
  assert_true(tree.stats().height >= 3)
  assert_eq(tree.validate(), [])
  for _ in 0..<200 {
    let query = random_box(rng)
    assert_eq(actual_ids(tree, query), brute_ids(entries, query))
  }
}

///|
test "deletion condenses tree and preserves every other entry" {
  let tree = RTree::new(capacity=4)
  let entries : Map[Int32, BBox] = Map([])
  let rng = { state: 42U, }
  for id in 0..<100 {
    let bounds = random_box(rng)
    entries[id] = bounds
    tree.insert(id, bounds)
  }
  for id in 0..<99 {
    assert_true(tree.remove(id))
    entries.remove(id)
    assert_eq(tree.validate(), [])
    assert_eq(
      actual_ids(tree, BBox::new(-2000.0, -2000.0, 2000.0, 2000.0)),
      brute_ids(entries, BBox::new(-2000.0, -2000.0, 2000.0, 2000.0)),
    )
  }
  assert_eq(tree.stats().height, 1)
  assert_true(tree.stats().condenses > 0)
  assert_true(tree.remove(99))
  assert_eq(tree.stats().height, 0)
}

///|
test "missing delete does not modify tree" {
  let tree = RTree::new()
  assert_false(tree.remove(99))
  assert_eq(tree.length(), 0)
}

///|
test "deleted ID can be reinserted" {
  let tree = RTree::new()
  tree.insert(1, BBox::new(0.0, 0.0, 1.0, 1.0))
  assert_true(tree.remove(1))
  tree.insert(1, BBox::new(2.0, 2.0, 3.0, 3.0))
  assert_eq(actual_ids(tree, BBox::new(0.0, 0.0, 1.0, 1.0)), [])
  assert_eq(actual_ids(tree, BBox::new(2.0, 2.0, 3.0, 3.0)), [1])
}

///|
test "1000 mixed operations agree with independent directory oracle" {
  let tree = RTree::new(capacity=5)
  let entries : Map[Int32, BBox] = Map([])
  let rng = { state: 1234567U, }
  for _ in 0..<1000 {
    let id = rng.next(80)
    if rng.next(3) == 0 {
      assert_eq(tree.remove(id), entries.contains(id))
      entries.remove(id)
    } else if !entries.contains(id) {
      let bounds = random_box(rng)
      tree.insert(id, bounds)
      entries[id] = bounds
    }
    assert_eq(tree.length(), entries.length())
    assert_eq(tree.validate(), [])
    let query = random_box(rng)
    assert_eq(actual_ids(tree, query), brute_ids(entries, query))
  }
}

///|
test "query returns independent result array" {
  let tree = RTree::new()
  let bounds = BBox::new(0.0, 0.0, 1.0, 1.0)
  tree.insert(1, bounds)
  tree.query(bounds).entries.clear()
  assert_eq(tree.query(bounds).entries.length(), 1)
}

///|
test "query order is deterministic by ID" {
  let tree = RTree::new()
  let bounds = BBox::new(0.0, 0.0, 1.0, 1.0)
  for id in [9, -3, 5, 1] {
    tree.insert(id, bounds)
  }
  assert_eq(actual_ids(tree, bounds), [-3, 1, 5, 9])
}

///|
test "subnormal rectangles retain range semantics" {
  let tree = RTree::new(capacity=4)
  let s = 1UL.reinterpret_as_double()
  for id in 0..<20 {
    let x = id.to_double() * s
    tree.insert(id, BBox::new(x, 0.0, x, s))
  }
  assert_eq(actual_ids(tree, BBox::new(0.0, 0.0, 0.0, s)), [0])
  assert_eq(tree.validate(), [])
}

///|
test "region query refines hole envelope false positive" {
  let index = RegionIndex::new()
  index.insert_polygon(
    10,
    Polygon::new(square(0.0, 0.0, 10.0), holes=[square(2.0, 2.0, 2.0)]),
  )
  let report = index.query_point(tp(3.0, 3.0))
  assert_eq(report.candidates, 1)
  assert_eq(report.hits, [])
  assert_eq(report.decisions[0].location, Outside)
}

///|
test "region boundary inclusion is explicit" {
  let index = RegionIndex::new()
  index.insert_polygon(1, Polygon::new(square(0.0, 0.0, 1.0)))
  assert_eq(index.query_point(tp(1.0, 0.5)).hits, [1])
  let report = index.query_point(tp(1.0, 0.5), include_boundary=false)
  assert_eq(report.hits, [])
  assert_eq(report.decisions[0].location, OnBoundary)
  assert_true(report.decisions[0].boundary is Some(_))
}

///|
test "region query returns multipolygon component" {
  let index = RegionIndex::new()
  index.insert(
    7,
    MultiPolygon::new([
      Polygon::new(square(0.0, 0.0, 1.0)),
      Polygon::new(square(3.0, 0.0, 1.0)),
    ]),
  )
  assert_eq(index.query_point(tp(3.5, 0.5)).decisions[0].component, Some(1))
  assert_eq(index.query_point(tp(2.0, 0.5)).hits, [])
}

///|
test "region replace updates revision and envelope" {
  let index = RegionIndex::new()
  index.insert_polygon(1, Polygon::new(square(0.0, 0.0, 1.0)))
  assert_true(
    index.replace(
      1,
      MultiPolygon::from_polygon(Polygon::new(square(2.0, 2.0, 1.0))),
    ),
  )
  assert_eq(index.query_point(tp(0.5, 0.5)).hits, [])
  let report = index.query_point(tp(2.5, 2.5))
  assert_eq(report.hits, [1])
  assert_eq(report.revision, 2)
  assert_eq(index.validate(), [])
}

///|
test "invalid replacement leaves previous region intact" {
  let index = RegionIndex::new()
  index.insert_polygon(1, Polygon::new(square(0.0, 0.0, 1.0)))
  let rejected = try {
    ignore(index.replace(1, MultiPolygon::new([])))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(index.query_point(tp(0.5, 0.5)).hits, [1])
  assert_eq(index.query_point(tp(0.5, 0.5)).revision, 1)
}

///|
test "region duplicate insert is atomic" {
  let index = RegionIndex::new()
  index.insert_polygon(1, Polygon::new(square(0.0, 0.0, 1.0)))
  let rejected = try {
    index.insert_polygon(1, Polygon::new(square(5.0, 5.0, 1.0)))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(index.query_point(tp(0.5, 0.5)).hits, [1])
  assert_eq(index.query_point(tp(0.5, 0.5)).revision, 1)
}

///|
test "empty indexed region rejected" {
  let index = RegionIndex::new()
  let rejected = try {
    index.insert(1, MultiPolygon::new([]))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "region remove and missing replace" {
  let index = RegionIndex::new()
  index.insert_polygon(1, Polygon::new(square(0.0, 0.0, 1.0)))
  assert_true(index.remove(1))
  assert_false(index.remove(1))
  assert_false(index.replace(2, MultiPolygon::new([])))
  assert_eq(index.length(), 0)
  assert_eq(index.validate(), [])
}

///|
test "seeded region query agrees with direct polygon scan" {
  let index = RegionIndex::new(capacity=4)
  let regions : Array[Polygon] = []
  for i in 0..<40 {
    let polygon = Polygon::new(
      square((i % 8).to_double() * 4.0, (i / 8).to_double() * 4.0, 3.0),
      holes=[
        square(
          (i % 8).to_double() * 4.0 + 1.0,
          (i / 8).to_double() * 4.0 + 1.0,
          1.0,
        ),
      ],
    )
    regions.push(polygon)
    index.insert_polygon(i, polygon)
  }
  let rng = { state: 777U, }
  for _ in 0..<200 {
    let point = tp(
      rng.next(320).to_double() / 10.0,
      rng.next(200).to_double() / 10.0,
    )
    let expected : Array[Int32] = []
    for i in 0..<regions.length() {
      if regions[i].locate(point).location != Outside {
        expected.push(i)
      }
    }
    assert_eq(index.query_point(point).hits, expected)
  }
}
