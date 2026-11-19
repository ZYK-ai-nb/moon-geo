///|
test "request duplicate keys cannot silently replace regions" {
  let result = @json.parse(
    @workflow.run("{\"regions\":{},\"regions\":{},\"operations\":[]}"),
  )
  guard result is Object(fields) else { fail("expected object") }
  assert_eq(fields.get("ok"), Some(Json(false)))
}

///|
test "bad operations preserve version and allow subsequent query" {
  let request =
    #| {"regions":{"type":"FeatureCollection","features":[]},"operations":[
    #| {"op":"unknown"},{"op":"remove","id":0.5},
    #| {"op":"query","point":[0,0],"include_boundary":"yes"},
    #| {"op":"query","point":[0,0]}]}
  let result = @json.parse(@workflow.run(request))
  guard result is Object(fields) else { fail("expected object") }
  assert_eq(fields.get("revision"), Some(Json(0)))
  guard fields.get("results") is Some(Array(items)) else { fail("results") }
  assert_eq(items.length(), 4)
  for i in 0..<3 {
    guard items[i] is Object(operation) else { fail("operation") }
    assert_eq(operation.get("ok"), Some(Json(false)))
    assert_eq(operation.get("revision"), Some(Json(0)))
  }
  guard items[3] is Object(last) else { fail("query") }
  assert_eq(last.get("ok"), Some(Json(true)))
  let empty : Array[Int32] = []
  assert_eq(last.get("hits"), Some(Json(empty)))
}
