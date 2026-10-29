///|
pub(all) enum Orientation {
  CW
  Collinear
  CCW
} derive(Debug, Eq)

///|
pub(all) enum ArithmeticPath {
  Filtered
  ExactDyadic
} derive(Debug, Eq)

///|
pub(all) struct OrientationReport {
  orientation : Orientation
  arithmetic : ArithmeticPath
} derive(Debug, Eq)

///|
fn sign_orientation(sign : Int32) -> Orientation {
  if sign > 0 {
    CCW
  } else if sign < 0 {
    CW
  } else {
    Collinear
  }
}

///|
// Decode the input's actual IEEE-754 value as integer significand * 2^exponent.
// No decimal conversion and no rounded intermediate coordinate subtraction.
fn dyadic(value : Double) -> (@bigint.BigInt, Int32) {
  let bits = value.reinterpret_as_uint64()
  let exponent = ((bits >> 52) & 0x7ffUL).to_int()
  let fraction = bits & 0x000fffffffffffffUL
  let mantissa = if exponent == 0 {
    fraction
  } else {
    fraction | 0x0010000000000000UL
  }
  let integer = @bigint.BigInt::from_uint64(mantissa)
  let signed = if bits >> 63 != 0UL { -integer } else { integer }
  (signed, if exponent == 0 { -1074 } else { exponent - 1075 })
}

///|
fn exact_coordinates(points : Array[Point]) -> Array[@bigint.BigInt] {
  let values : Array[(@bigint.BigInt, Int32)] = []
  let mut exponent = 1024
  for p in points {
    for value in [p.x, p.y] {
      let pair = dyadic(value)
      values.push(pair)
      if !pair.0.is_zero() && pair.1 < exponent {
        exponent = pair.1
      }
    }
  }
  values.map(fn(pair) {
    if pair.0.is_zero() {
      pair.0
    } else {
      pair.0 << (pair.1 - exponent)
    }
  })
}

///|
fn exact_orientation(a : Point, b : Point, c : Point) -> Orientation {
  let v = exact_coordinates([a, b, c])
  let det = (v[2] - v[0]) * (v[5] - v[1]) - (v[3] - v[1]) * (v[4] - v[0])
  sign_orientation(det.compare_int(0))
}

///|
/// Conservative floating-point filter, then exact dyadic integer arithmetic.
/// Exactness refers to the sign for the supplied binary coordinates, not to
/// recovering an unknown real-world position or exact constructed coordinates.
pub fn orientation_report(a : Point, b : Point, c : Point) -> OrientationReport {
  let acx = a.x - c.x
  let bcx = b.x - c.x
  let acy = a.y - c.y
  let bcy = b.y - c.y
  let left = acx * bcy
  let right = acy * bcx
  let det = left - right
  let safe = [acx, bcx, acy, bcy].all(fn(v) { v == 0.0 || v.abs() >= 1.0e-100 })
  // This deliberately exceeds the standard orient2d forward-error bound.
  let bound = 1.0e-14 * (left.abs() + right.abs())
  if safe && det.abs() > bound {
    { orientation: if det > 0.0 { CCW } else { CW }, arithmetic: Filtered, }
  } else {
    { orientation: exact_orientation(a, b, c), arithmetic: ExactDyadic, }
  }
}

///|
pub fn orientation(a : Point, b : Point, c : Point) -> Orientation {
  orientation_report(a, b, c).orientation
}
