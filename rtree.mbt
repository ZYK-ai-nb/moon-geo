///|
pub(all) struct SpatialEntry {
  id : Int32
  bounds : BBox
} derive(Debug, Eq)

///|
priv struct RNode {
  mut bounds : BBox
  leaf : Bool
  mut entries : Array[SpatialEntry]
  mut children : Array[RNode]
}

///|
struct RTree {
  mut root : RNode?
  capacity : Int32
  minimum : Int32
  directory : Map[Int32, BBox]
  mut splits : Int32
  mut condenses : Int32
}

///|
pub(all) struct TreeStats {
  entries : Int32
  height : Int32
  nodes : Int32
  leaves : Int32
  splits : Int32
  condenses : Int32
} derive(Debug, Eq)

///|
pub(all) struct RangeReport {
  entries : Array[SpatialEntry]
  nodes_visited : Int32
  entries_tested : Int32
} derive(Debug)

///|
pub fn RTree::new(capacity~ : Int32 = 8) -> RTree raise GeoError {
  if capacity < 4 || capacity > 128 {
    raise InvalidCapacity
  }
  {
    root: None,
    capacity,
    minimum: capacity / 2,
    directory: {},
    splits: 0,
    condenses: 0,
  }
}

///|
fn leaf_node(entry : SpatialEntry) -> RNode {
  { bounds: entry.bounds, leaf: true, entries: [entry], children: [], }
}

///|
fn branch_node(children : Array[RNode]) -> RNode {
  let node = { bounds: children[0].bounds, leaf: false, entries: [], children, }
  refresh_bounds(node)
  node
}

///|
fn node_size(node : RNode) -> Int32 {
  if node.leaf {
    node.entries.length()
  } else {
    node.children.length()
  }
}

///|
fn refresh_bounds(node : RNode) -> Unit {
  let boxes = if node.leaf {
    node.entries.map(fn(e) { e.bounds })
  } else {
    node.children.map(fn(n) { n.bounds })
  }
  if !boxes.is_empty() {
    let mut bounds = boxes[0]
    for b in boxes {
      bounds = bounds.union(b)
    }
    node.bounds = bounds
  }
}

///|
fn enlargement(a : BBox, b : BBox) -> Double {
  a.union(b).area() - a.area()
}

///|
// Guttman quadratic split: maximum wasted-area seeds, then the entry whose
// enlargement preferences differ most. Enforce minimum occupancy explicitly.
fn quadratic_groups(
  boxes : Array[BBox],
  minimum : Int32,
) -> (Array[Int32], Array[Int32]) {
  let mut seed_a = 0
  let mut seed_b = 1
  let mut waste = boxes[0].union(boxes[1]).area() -
    boxes[0].area() -
    boxes[1].area()
  for i in 0..<boxes.length() {
    for j = i + 1; j < boxes.length(); j = j + 1 {
      let value = boxes[i].union(boxes[j]).area() -
        boxes[i].area() -
        boxes[j].area()
      if value > waste {
        seed_a = i
        seed_b = j
        waste = value
      }
    }
  }
  let a = [seed_a]
  let b = [seed_b]
  let assigned = Array::make(boxes.length(), false)
  assigned[seed_a] = true
  assigned[seed_b] = true
  let mut bounds_a = boxes[seed_a]
  let mut bounds_b = boxes[seed_b]
  let mut remaining = boxes.length() - 2
  while remaining > 0 {
    if a.length() + remaining == minimum || b.length() + remaining == minimum {
      let to_a = a.length() + remaining == minimum
      for i in 0..<boxes.length() {
        if !assigned[i] {
          if to_a {
            a.push(i)
          } else {
            b.push(i)
          }
          assigned[i] = true
        }
      }
      break
    }
    let mut next = -1
    let mut preference = -1.0
    for i in 0..<boxes.length() {
      if !assigned[i] {
        let difference = (enlargement(bounds_a, boxes[i]) -
        enlargement(bounds_b, boxes[i])).abs()
        if difference > preference {
          preference = difference
          next = i
        }
      }
    }
    let ea = enlargement(bounds_a, boxes[next])
    let eb = enlargement(bounds_b, boxes[next])
    let to_a = ea < eb ||
      (
        ea == eb &&
        (
          bounds_a.area() < bounds_b.area() ||
          (bounds_a.area() == bounds_b.area() && a.length() <= b.length())
        )
      )
    if to_a {
      a.push(next)
      bounds_a = bounds_a.union(boxes[next])
    } else {
      b.push(next)
      bounds_b = bounds_b.union(boxes[next])
    }
    assigned[next] = true
    remaining = remaining - 1
  }
  (a, b)
}

///|
fn split_node(node : RNode, minimum : Int32) -> RNode {
  let boxes = if node.leaf {
    node.entries.map(fn(e) { e.bounds })
  } else {
    node.children.map(fn(n) { n.bounds })
  }
  let (a, b) = quadratic_groups(boxes, minimum)
  let sibling = if node.leaf {
    let old = node.entries
    node.entries = a.map(fn(i) { old[i] })
    {
      bounds: boxes[b[0]],
      leaf: true,
      entries: b.map(fn(i) { old[i] }),
      children: [],
    }
  } else {
    let old = node.children
    node.children = a.map(fn(i) { old[i] })
    branch_node(b.map(fn(i) { old[i] }))
  }
  refresh_bounds(node)
  refresh_bounds(sibling)
  sibling
}

///|
fn insert_node(tree : RTree, node : RNode, entry : SpatialEntry) -> RNode? {
  if node.leaf {
    node.entries.push(entry)
  } else {
    let mut best = 0
    for i in 1..<node.children.length() {
      let candidate = node.children[i].bounds
      let chosen = node.children[best].bounds
      let ce = enlargement(candidate, entry.bounds)
      let be = enlargement(chosen, entry.bounds)
      if ce < be || (ce == be && candidate.area() < chosen.area()) {
        best = i
      }
    }
    if insert_node(tree, node.children[best], entry) is Some(sibling) {
      node.children.push(sibling)
    }
  }
  refresh_bounds(node)
  if node_size(node) > tree.capacity {
    tree.splits = tree.splits + 1
    Some(split_node(node, tree.minimum))
  } else {
    None
  }
}

///|
fn insert_raw(tree : RTree, entry : SpatialEntry) -> Unit {
  match tree.root {
    None => tree.root = Some(leaf_node(entry))
    Some(root) =>
      if insert_node(tree, root, entry) is Some(sibling) {
        tree.root = Some(branch_node([root, sibling]))
      }
  }
}

///|
pub fn RTree::insert(
  self : RTree,
  id : Int32,
  bounds : BBox,
) -> Unit raise GeoError {
  if self.directory.contains(id) {
    raise DuplicateId(id)
  }
  insert_raw(self, { id, bounds, })
  self.directory[id] = bounds
}

///|
fn collect_entries(node : RNode, output : Array[SpatialEntry]) -> Unit {
  if node.leaf {
    for e in node.entries {
      output.push(e)
    }
  } else {
    for child in node.children {
      collect_entries(child, output)
    }
  }
}

///|
fn remove_node(
  tree : RTree,
  node : RNode,
  id : Int32,
  bounds : BBox,
  orphans : Array[SpatialEntry],
) -> Bool {
  if !node.bounds.intersects(bounds) {
    return false
  }
  if node.leaf {
    for i in 0..<node.entries.length() {
      if node.entries[i].id == id {
        ignore(node.entries.remove(i))
        refresh_bounds(node)
        return true
      }
    }
  } else {
    for i in 0..<node.children.length() {
      let child = node.children[i]
      if remove_node(tree, child, id, bounds, orphans) {
        if node_size(child) < tree.minimum {
          collect_entries(child, orphans)
          ignore(node.children.remove(i))
          tree.condenses = tree.condenses + 1
        }
        refresh_bounds(node)
        return true
      }
    }
  }
  false
}

///|
pub fn RTree::remove(self : RTree, id : Int32) -> Bool {
  guard self.directory.get(id) is Some(bounds) else { return false }
  guard self.root is Some(root) else { return false }
  let orphans : Array[SpatialEntry] = []
  if !remove_node(self, root, id, bounds, orphans) {
    return false
  }
  self.directory.remove(id)
  if node_size(root) == 0 {
    self.root = None
  }
  let mut collapsing = true
  while collapsing {
    match self.root {
      Some(node) =>
        if !node.leaf && node.children.length() == 1 {
          self.root = Some(node.children[0])
        } else {
          collapsing = false
        }
      None => collapsing = false
    }
  }
  for entry in orphans {
    insert_raw(self, entry)
  }
  true
}

///|
pub fn RTree::length(self : RTree) -> Int32 {
  self.directory.length()
}

///|
pub fn RTree::query(self : RTree, bounds : BBox) -> RangeReport {
  let stack : Array[RNode] = []
  if self.root is Some(root) {
    stack.push(root)
  }
  let entries : Array[SpatialEntry] = []
  let mut visited = 0
  let mut tested = 0
  while stack.pop() is Some(node) {
    visited = visited + 1
    if node.bounds.intersects(bounds) {
      if node.leaf {
        for entry in node.entries {
          tested = tested + 1
          if entry.bounds.intersects(bounds) {
            entries.push(entry)
          }
        }
      } else {
        for child in node.children {
          if child.bounds.intersects(bounds) {
            stack.push(child)
          }
        }
      }
    }
  }
  entries.sort_by(fn(a, b) { a.id.compare(b.id) })
  { entries, nodes_visited: visited, entries_tested: tested, }
}

///|
fn node_stats(node : RNode) -> (Int32, Int32, Int32) {
  if node.leaf {
    return (1, 1, 1)
  }
  let mut height = 0
  let mut nodes = 1
  let mut leaves = 0
  for child in node.children {
    let (h, n, l) = node_stats(child)
    height = height.max(h)
    nodes = nodes + n
    leaves = leaves + l
  }
  (height + 1, nodes, leaves)
}

///|
pub fn RTree::stats(self : RTree) -> TreeStats {
  let (height, nodes, leaves) = match self.root {
    None => (0, 0, 0)
    Some(root) => node_stats(root)
  }
  {
    entries: self.length(),
    height,
    nodes,
    leaves,
    splits: self.splits,
    condenses: self.condenses,
  }
}

///|
fn validate_node(
  node : RNode,
  root : Bool,
  tree : RTree,
  seen : Map[Int32, BBox],
  errors : Array[String],
) -> Int32 {
  let size = node_size(node)
  if size > tree.capacity || size == 0 || (!root && size < tree.minimum) {
    errors.push("node occupancy")
  }
  if node.leaf {
    if !node.children.is_empty() {
      errors.push("leaf has children")
    }
    for e in node.entries {
      if seen.contains(e.id) {
        errors.push("duplicate entry")
      }
      seen[e.id] = e.bounds
    }
  } else if !node.entries.is_empty() {
    errors.push("branch has entries")
  }
  let boxes = if node.leaf {
    node.entries.map(fn(e) { e.bounds })
  } else {
    node.children.map(fn(n) { n.bounds })
  }
  if !boxes.is_empty() {
    let mut bounds = boxes[0]
    for b in boxes {
      bounds = bounds.union(b)
    }
    if bounds != node.bounds {
      errors.push("incorrect node bounds")
    }
  }
  let mut height = 0
  for child in node.children {
    let h = validate_node(child, false, tree, seen, errors)
    if height != 0 && height != h {
      errors.push("unequal leaf depth")
    }
    height = h
  }
  height + 1
}

///|
/// An empty list means occupancy, bounds, balanced depth and ID directory agree.
pub fn RTree::validate(self : RTree) -> Array[String] {
  let errors : Array[String] = []
  let seen : Map[Int32, BBox] = Map([])
  if self.root is Some(root) {
    ignore(validate_node(root, true, self, seen, errors))
  }
  if seen.length() != self.directory.length() {
    errors.push("directory length mismatch")
  }
  for id, bounds in self.directory {
    if seen.get(id) != Some(bounds) {
      errors.push("directory bounds mismatch")
    }
  }
  errors
}
