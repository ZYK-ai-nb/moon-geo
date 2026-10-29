///|
fn main {
  try {
    let tree = @geo.RTree::new(capacity=4)
    for id in 0..<50 {
      let x = id.to_double()
      tree.insert(id, @geo.BBox::new(x, 0.0, x + 0.5, 1.0))
    }
    let before = tree.stats()
    assert_true(before.height > 1)
    assert_true(before.splits > 0)
    for id in 0..<49 {
      assert_true(tree.remove(id))
    }
    assert_eq(tree.validate(), [])
    assert_eq(tree.stats().height, 1)
    assert_eq(
      tree.query(@geo.BBox::new(49.0, 0.0, 50.0, 1.0)).entries[0].id,
      49,
    )
    println(
      "after 50 inserts: height=\{before.height}; splits=\{before.splits}",
    )
    println(
      "after 49 deletes: entries=\{tree.length()}; height=\{tree.stats().height}; invariant errors=0",
    )
  } catch {
    error => abort("index example failed: \{error}")
  }
}
