///|
#derive(Debug)
pub suberror GeoJsonError {
  InvalidGeoJson(String)
}

///|
pub extend GeoJsonError with @debug.Debug::{to_repr}

///|
fn object(value : Json) -> Map[String, Json] raise GeoJsonError {
  guard value is Object(fields) else {
    raise InvalidGeoJson("expected an object")
  }
  if fields.contains("crs") {
    raise InvalidGeoJson("custom crs is unsupported; supply longitude/latitude")
  }
  fields
}

///|
fn field(fields : Map[String, Json], name : String) -> Json raise GeoJsonError {
  guard fields.get(name) is Some(value) else {
    raise InvalidGeoJson("missing member: " + name)
  }
  value
}

///|
fn require_type(
  fields : Map[String, Json],
  expected : String,
) -> Unit raise GeoJsonError {
  guard field(fields, "type") is String(actual) && actual == expected else {
    raise InvalidGeoJson("expected type: " + expected)
  }
}

///|
fn array(value : Json) -> Array[Json] raise GeoJsonError {
  guard value is Array(items) else { raise InvalidGeoJson("expected an array") }
  items
}

///|
fn point(value : Json) -> @geo.Point raise GeoJsonError {
  let coordinates = array(value)
  guard coordinates.length() == 2 &&
    coordinates[0] is Number(x, ..) &&
    coordinates[1] is Number(y, ..) else {
    raise InvalidGeoJson("positions must contain exactly two numbers")
  }
  if x.is_nan() || y.is_nan() || x.abs() > 180.0 || y.abs() > 90.0 {
    raise InvalidGeoJson("position outside longitude/latitude bounds")
  }
  @geo.Point::new(x, y) catch {
    _ => raise InvalidGeoJson("invalid position")
  }
}

///|
fn ring(value : Json) -> Array[@geo.Point] raise GeoJsonError {
  let positions = array(value)
  if positions.length() < 4 {
    raise InvalidGeoJson("linear rings require at least four positions")
  }
  let points = positions.map(point)
  if points[0] != points[points.length() - 1] {
    raise InvalidGeoJson("linear ring must be explicitly closed")
  }
  let mut min_lon = points[0].x()
  let mut max_lon = min_lon
  for i in 1..<points.length() {
    min_lon = min_lon.min(points[i].x())
    max_lon = max_lon.max(points[i].x())
    if (points[i].x() - points[i - 1].x()).abs() > 180.0 {
      raise InvalidGeoJson("antimeridian-crossing edges are unsupported")
    }
  }
  if max_lon - min_lon > 180.0 {
    raise InvalidGeoJson("rings spanning over 180 degrees are unsupported")
  }
  points
}

///|
fn polygon(value : Json) -> @geo.Polygon raise GeoJsonError {
  let rings = array(value)
  if rings.is_empty() {
    raise InvalidGeoJson("polygon must have an exterior ring")
  }
  let shell = ring(rings[0])
  let holes : Array[Array[@geo.Point]] = []
  for i in 1..<rings.length() {
    holes.push(ring(rings[i]))
  }
  @geo.Polygon::new(shell, holes~) catch {
    _ => raise InvalidGeoJson("invalid polygon topology")
  }
}

///|
fn geometry(value : Json) -> @geo.MultiPolygon raise GeoJsonError {
  let fields = object(value)
  match field(fields, "type") {
    String("Polygon") =>
      @geo.MultiPolygon::from_polygon(polygon(field(fields, "coordinates")))
    String("MultiPolygon") => {
      let parts = array(field(fields, "coordinates"))
      if parts.is_empty() {
        raise InvalidGeoJson("multipolygon must have at least one component")
      }
      let polygons = parts.map(polygon)
      @geo.MultiPolygon::new(polygons) catch {
        _ => raise InvalidGeoJson("multipolygon components intersect or touch")
      }
    }
    _ => raise InvalidGeoJson("only Polygon and MultiPolygon are supported")
  }
}

///|
fn feature_id(value : Json) -> Int32 raise GeoJsonError {
  guard value is Number(n, ..) &&
    !n.is_nan() &&
    n >= -2147483648.0 &&
    n <= 2147483647.0 else {
    raise InvalidGeoJson("feature id must be a numeric Int32")
  }
  let id = n.to_int()
  if id.to_double() != n {
    raise InvalidGeoJson("fractional feature ids are unsupported")
  }
  id
}

///|
/// Parse a restricted GeoJSON FeatureCollection for local planar topology.
/// Only two-dimensional lon/lat Polygon and MultiPolygon geometries are accepted.
/// IDs are unique numeric Int32 values. Properties must be an object or null;
/// their contents and any supplied bbox are ignored.
/// Coordinates are used as straight line segments, without geodesic projection.
pub fn parse_feature_collection(
  text : String,
) -> Array[(Int32, @geo.MultiPolygon)] raise GeoJsonError {
  let document = @json.parse(text, reject_duplicate_keys=true) catch {
    _ => raise InvalidGeoJson("invalid JSON or duplicate object keys")
  }
  let fields = object(document)
  require_type(fields, "FeatureCollection")
  let features = array(field(fields, "features"))
  let seen : Map[Int32, Bool] = Map([])
  let result : Array[(Int32, @geo.MultiPolygon)] = []
  for value in features {
    let feature = object(value)
    require_type(feature, "Feature")
    match field(feature, "properties") {
      Object(_) | Null => ()
      _ => raise InvalidGeoJson("feature properties must be an object or null")
    }
    let id = feature_id(field(feature, "id"))
    if seen.contains(id) {
      raise InvalidGeoJson("duplicate feature id")
    }
    let region = geometry(field(feature, "geometry"))
    seen[id] = true
    result.push((id, region))
  }
  result
}

///|
/// Build a new index only after the complete collection passes validation.
pub fn build_index(
  text : String,
  capacity~ : Int32 = 8,
) -> @geo.RegionIndex raise GeoJsonError {
  let features = parse_feature_collection(text)
  let index = @geo.RegionIndex::new(capacity~) catch {
    _ => raise InvalidGeoJson("invalid index capacity")
  }
  for (id, region) in features {
    index.insert(id, region) catch {
      _ => raise InvalidGeoJson("invalid region insertion")
    }
  }
  index
}
