///|
pub(all) struct RegionDecision {
  id : Int32
  location : Location
  component : Int32?
  boundary : BoundaryWitness?
} derive(Debug, Eq)

///|
pub(all) struct RegionQueryReport {
  revision : Int32
  candidates : Int32
  nodes_visited : Int32
  entries_tested : Int32
  hits : Array[Int32]
  decisions : Array[RegionDecision]
} derive(Debug)

///|
struct RegionIndex {
  tree : RTree
  regions : Map[Int32, MultiPolygon]
  mut revision : Int32
}

///|
pub fn RegionIndex::new(capacity~ : Int32 = 8) -> RegionIndex raise GeoError {
  { tree: RTree::new(capacity~), regions: {}, revision: 0, }
}

///|
pub fn RegionIndex::insert(
  self : RegionIndex,
  id : Int32,
  region : MultiPolygon,
) -> Unit raise GeoError {
  guard region.bounds() is Some(bounds) else {
    raise InvalidPolygon("indexed region must not be empty")
  }
  self.tree.insert(id, bounds)
  self.regions[id] = region
  self.revision = self.revision + 1
}

///|
pub fn RegionIndex::insert_polygon(
  self : RegionIndex,
  id : Int32,
  polygon : Polygon,
) -> Unit raise GeoError {
  self.insert(id, MultiPolygon::from_polygon(polygon))
}

///|
pub fn RegionIndex::remove(self : RegionIndex, id : Int32) -> Bool {
  if !self.tree.remove(id) {
    return false
  }
  self.regions.remove(id)
  self.revision = self.revision + 1
  true
}

///|
/// Validates the replacement before changing the index. Missing IDs return false.
pub fn RegionIndex::replace(
  self : RegionIndex,
  id : Int32,
  region : MultiPolygon,
) -> Bool raise GeoError {
  if !self.regions.contains(id) {
    return false
  }
  guard region.bounds() is Some(bounds) else {
    raise InvalidPolygon("indexed region must not be empty")
  }
  ignore(self.tree.remove(id))
  self.tree.insert(id, bounds)
  self.regions[id] = region
  self.revision = self.revision + 1
  true
}

///|
pub fn RegionIndex::length(self : RegionIndex) -> Int32 {
  self.regions.length()
}

///|
pub fn RegionIndex::stats(self : RegionIndex) -> TreeStats {
  self.tree.stats()
}

///|
pub fn RegionIndex::validate(self : RegionIndex) -> Array[String] {
  let errors = self.tree.validate()
  if self.regions.length() != self.tree.length() {
    errors.push("region directory mismatch")
  }
  for id, region in self.regions {
    if self.tree.directory.get(id) != region.bounds() {
      errors.push("region envelope mismatch")
    }
  }
  errors
}

///|
/// Results are sorted by ID. By default hits include boundary contacts; every
/// candidate receives an explicit decision, including envelope false positives.
pub fn RegionIndex::query_point(
  self : RegionIndex,
  p : Point,
  include_boundary~ : Bool = true,
  rule~ : FillRule = EvenOdd,
) -> RegionQueryReport {
  let envelope = { min_x: p.x, min_y: p.y, max_x: p.x, max_y: p.y, }
  let range = self.tree.query(envelope)
  let hits : Array[Int32] = []
  let decisions : Array[RegionDecision] = []
  for entry in range.entries {
    if self.regions.get(entry.id) is Some(region) {
      let mut location = Outside
      let mut component = None
      let mut boundary = None
      for i in 0..<region.polygons.length() {
        let report = region.polygons[i].locate(p, rule~)
        if report.location != Outside {
          location = report.location
          component = Some(i)
          boundary = report.boundary
          break
        }
      }
      if location == Inside || (include_boundary && location == OnBoundary) {
        hits.push(entry.id)
      }
      decisions.push({ id: entry.id, location, component, boundary, })
    }
  }
  {
    revision: self.revision,
    candidates: range.entries.length(),
    nodes_visited: range.nodes_visited,
    entries_tested: range.entries_tested,
    hits,
    decisions,
  }
}
