///|
#derive(Eq)
struct Item {
  id : Int32
  box : @rb.BBox
}

///|
// Application adapter for the single-ring API. 0 boundary, 1 inside, -1 outside.
fn kit_location(shell : @kit.Polygon, hole : @kit.Polygon, p : @kit.Point) -> Int32 {
  for polygon in [shell, hole] {
    let points = polygon.points
    for i in 0..<points.length() {
      if @kit.point_on_segment(p, @kit.Segment::new(points[i], points[(i + 1) % points.length()])) {
        return 0
      }
    }
  }
  if shell.contains_point(p) && !hole.contains_point(p) { 1 } else { -1 }
}

///|
fn main {
  try {
    let geo = @geo.RTree::new()
    let grid = @kit.GridSpatialIndex::new(@kit.Bounds::new(-8.0, -8.0, 8.0, 8.0), 16, 16)
    let bush : @rb.RBush[Item] = @rb.RBush::new(fn(v) { v.box })
    let items : Array[Item] = []
    for i in 0..<16 {
      for j in 0..<16 {
        let id = i * 16 + j
        let x = i.to_double() - 8.0
        let y = j.to_double() - 8.0
        geo.insert(id, @geo.BBox::new(x, y, x + 0.8, y + 0.8))
        assert_true(grid.insert(@kit.SpatialItem::new(id, @kit.Bounds::new(x, y, x + 0.8, y + 0.8))))
        let item = Item::{ id, box: @rb.BBox::new(x, y, x + 0.8, y + 0.8) }
        items.push(item)
        bush.insert(item)
      }
    }
    let mut matched = 0
    for i in 0..<16 {
      for j in 0..<16 {
        let id = i * 16 + j
        let x = i.to_double() - 7.6
        let y = j.to_double() - 7.6
        assert_eq(geo.query(@geo.BBox::new(x, y, x, y)).entries.map(fn(v) { v.id }), [id])
        assert_eq(grid.query_point(@kit.Point::new(x, y)).items.map(fn(v) { v.id }), [id])
        assert_eq(bush.search(@rb.BBox::new(x, y, x, y)).map(fn(v) { v.id }), [id])
        matched = matched + 1
      }
    }
    assert_true(geo.remove(0))
    assert_true(grid.remove(0))
    assert_true(bush.remove(items[0]))
    assert_eq(geo.query(@geo.BBox::new(-7.6, -7.6, -7.6, -7.6)).entries.length(), 0)
    assert_eq(grid.query_point(@kit.Point::new(-7.6, -7.6)).items.length(), 0)
    assert_eq(bush.search(@rb.BBox::new(-7.6, -7.6, -7.6, -7.6)).length(), 0)

    // The same ring data; MoonGeoKit's single-ring API needs hole subtraction.
    let shell = [@geo.Point::new(0.0,0.0), @geo.Point::new(10.0,0.0), @geo.Point::new(10.0,10.0), @geo.Point::new(0.0,10.0)]
    let hole = [@geo.Point::new(2.0,2.0), @geo.Point::new(4.0,2.0), @geo.Point::new(4.0,4.0), @geo.Point::new(2.0,4.0)]
    let ks = @kit.Polygon::new(shell.map(fn(p) { @kit.Point::new(p.x(),p.y()) }))
    let kh = @kit.Polygon::new(hole.map(fn(p) { @kit.Point::new(p.x(),p.y()) }))
    let ms = shell.map(fn(p) { @mgcore.Point2D::new(p.x(), p.y()) })
    let mh = hole.map(fn(p) { @mgcore.Point2D::new(p.x(), p.y()) })
    let mp = @mgholes.polygon_with_holes_new(ms, [mh])
    let mut mg_matches = 0
    for (x, y, expected) in [(1.0,1.0,true),(3.0,3.0,false),(11.0,11.0,false)] {
      assert_eq(@mgholes.polygon_with_holes_contains(mp, @mgcore.Point2D::new(x,y)), expected)
      mg_matches = mg_matches + 1
    }
    let parsed = @mgjson.geojson_parse("{\"type\":\"Polygon\",\"coordinates\":[[[0,0],[10,0],[10,10],[0,10],[0,0]],[[2,2],[4,2],[4,4],[2,4],[2,2]]]}")
    guard parsed is Some(@mgjson.GeoPolygon(rings)) else { abort("moon-geometry polygon parse") }
    assert_eq(rings.length(), 2)
    let regions = @geo.RegionIndex::new()
    regions.insert_polygon(1, @geo.Polygon::new(shell, holes=[hole]))
    for (x,y) in [(1.0,1.0),(3.0,3.0),(11.0,11.0),(2.0,3.0),(0.0,5.0)] {
      let kp = @kit.Point::new(x,y)
      let kit_code = kit_location(ks, kh, kp)
      let gp = @geo.Point::new(x,y)
      let located = @geo.Polygon::new(shell, holes=[hole]).locate(gp).location
      let geo_code = match located { @geo.Inside => 1; @geo.OnBoundary => 0; @geo.Outside => -1 }
      assert_eq(geo_code, kit_code)
      assert_eq(regions.query_point(gp, include_boundary=false).hits.length() == 1, kit_code == 1)
    }
    assert_true(regions.replace(1, @geo.MultiPolygon::from_polygon(@geo.Polygon::new(shell))))
    assert_eq(regions.query_point(@geo.Point::new(3.0,3.0)).hits, [1])
    assert_true(ks.contains_point(@kit.Point::new(3.0,3.0)))

    let direction = @kit.orientation_sign(@kit.Point::new(0.0,0.0), @kit.Point::new(134217728.0,134217729.0), @kit.Point::new(134217729.0,134217730.0), 0.0)
    let exact = @geo.orientation(@geo.Point::new(0.0,0.0), @geo.Point::new(134217728.0,134217729.0), @geo.Point::new(134217729.0,134217730.0))
    let sign = match exact { @geo.CW => -1; @geo.Collinear => 0; @geo.CCW => 1 }
    geo.insert(1000, @geo.BBox::new(100.0,100.0,101.0,101.0))
    bush.insert(Item::{ id:1000, box:@rb.BBox::new(100.0,100.0,101.0,101.0) })
    let far = @kit.SpatialItem::new(1000,@kit.Bounds::new(100.0,100.0,101.0,101.0))
    let fixed_grid_accepts = grid.insert(far)
    let linear = @kit.SpatialIndex::new()
    linear.insert(far)
    assert_eq(geo.validate(), [])
    println(({ "grid_queries_matched": Json(matched), "delete_then_query_matched":Json(true), "hole_workflow_matched":Json(true), "moon_geometry_hole_queries_matched":Json(mg_matches), "moon_geometry_geojson_polygon_parsed":Json(true), "geokit_direction":Json(direction), "moongeo_direction":Json(sign), "far_insert_geokit_fixed_grid":Json(fixed_grid_accepts), "far_insert_geokit_linear":Json(linear.query_point(@kit.Point::new(100.5,100.5)).length()==1), "far_insert_moongeo":Json(geo.query(@geo.BBox::new(100.5,100.5,100.5,100.5)).entries.length()==1), "far_insert_rbush":Json(bush.search(@rb.BBox::new(100.5,100.5,100.5,100.5)).length()==1) } : Json).stringify())
  } catch { error => abort(error.to_string()) }
}
