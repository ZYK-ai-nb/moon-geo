///|
suberror RequestError {
  InvalidRequest(String)
} derive(Debug)

///|
pub extend RequestError with @debug.Debug::{to_repr}

///|
fn field(value : Json, name : String) -> Json raise RequestError {
  match value {
    Object(obj) =>
      match obj.get(name) {
        Some(v) => v
        None => raise InvalidRequest("missing field: " + name)
      }
    _ => raise InvalidRequest("expected object")
  }
}

///|
fn integer(value : Json) -> Int32 raise RequestError {
  guard value is Number(n, ..) && n >= -2147483648.0 && n <= 2147483647.0 else {
    raise InvalidRequest("expected Int32")
  }
  let id = n.to_int()
  guard id.to_double() == n else { raise InvalidRequest("expected integer") }
  id
}

///|
fn coordinate(value : Json) -> @geo.Point raise {
  guard value is Array(v) && v.length() == 2 else {
    raise InvalidRequest("point requires two coordinates")
  }
  guard v[0] is Number(x, ..) && v[1] is Number(y, ..) else {
    raise InvalidRequest("point coordinates must be numbers")
  }
  guard x >= -180.0 && x <= 180.0 && y >= -90.0 && y <= 90.0 else {
    raise InvalidRequest("point outside longitude/latitude bounds")
  }
  @geo.Point::new(x, y)
}

///|
fn revision(index : @geo.RegionIndex) -> Json {
  Json(index.revision())
}

///|
fn query(index : @geo.RegionIndex, operation : Json) -> Json raise {
  let point = coordinate(field(operation, "point"))
  let boundary = match operation {
    Object(obj) =>
      match obj.get("include_boundary") {
        None => true
        Some(True) => true
        Some(False) => false
        _ => raise InvalidRequest("include_boundary must be boolean")
      }
    _ => raise InvalidRequest("expected operation object")
  }
  let report = index.query_point(point, include_boundary=boundary)
  let decisions = report.decisions.map(fn(d) {
    let location = match d.location {
      @geo.Inside => "Inside"
      @geo.Outside => "Outside"
      @geo.OnBoundary => "OnBoundary"
    }
    let witness = match d.boundary {
      None => Json::null()
      Some(w) => ({ "ring": Json(w.ring), "edge": Json(w.edge) } : Json)
    }
    (
      { "id": Json(d.id), "location": Json(location), "boundary": witness } :
      Json)
  })
  {
    "ok": Json(true),
    "revision": Json(report.revision),
    "hits": Json(report.hits),
    "candidates": Json(report.candidates),
    "entries_tested": Json(report.entries_tested),
    "nodes_visited": Json(report.nodes_visited),
    "decisions": Json(decisions),
  }
}

///|
fn apply(index : @geo.RegionIndex, operation : Json) -> Json raise {
  let op = field(operation, "op")
  if op == Json("query") {
    return query(index, operation)
  }
  if op == Json("remove") {
    let removed = index.remove(integer(field(operation, "id")))
    return {
      "ok": Json(true),
      "changed": Json(removed),
      "revision": revision(index),
    }
  }
  if op == Json("insert") || op == Json("replace") {
    // Parse and validate before changing the live index. One operation changes one ID.
    let features = @gj.parse_feature_collection(
      field(operation, "regions").stringify(),
    )
    guard features.length() == 1 else {
      raise InvalidRequest("insert/replace requires exactly one feature")
    }
    let (id, shape) = features[0]
    let changed = if op == Json("insert") {
      index.insert(id, shape)
      true
    } else {
      index.replace(id, shape)
    }
    return {
      "ok": Json(true),
      "changed": Json(changed),
      "revision": revision(index),
    }
  }
  raise InvalidRequest("unknown operation")
}

///|
/// Processes a local request. Errors in an operation leave that operation unchanged
/// and are returned in order. Earlier successful operations remain committed.
pub fn run(input : String) -> String {
  try {
    let request = @json.parse(input, reject_duplicate_keys=true)
    let index = @gj.build_index(field(request, "regions").stringify())
    guard field(request, "operations") is Array(operations) else {
      raise InvalidRequest("operations must be an array")
    }
    let results : Array[Json] = []
    for operation in operations {
      let result = apply(index, operation) catch {
        error =>
          (
            {
              "ok": Json(false),
              "error": Json(error.to_string()),
              "revision": revision(index),
            } : Json)
      }
      results.push(result)
    }
    (
      {
        "ok": Json(true),
        "results": Json(results),
        "revision": revision(index),
        "invariant_errors": Json(index.validate()),
      } : Json).stringify()
  } catch {
    error =>
      ({ "ok": Json(false), "error": Json(error.to_string()) } : Json).stringify()
  }
}
