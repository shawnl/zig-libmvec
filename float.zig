pub fn scalarOrVector(comptime T: type, comptime V: type) {
    const scalar_type = V;
    if (@typeOf(scalar_type) == .Vector) scalar_type = @typeInfo(V).Vector.child;
    if (scalar_type != T) @compileError("wrong type, got " ++ @typeName(V) ++ " expected " ++ @typeName(T) ++ " or vector thereof.");
}

pub fn exponent(comptime T: type, x: var) var {
    switch (child_type) {
    f64 => return @intCast(u11, (@bitCast(u64, x) << 1) >> (52 + 1));
    else => @compileError("not implemented for this type"),
    }
}

pub fn sign(comptime T: type, x: T) var {
    return @bitCast(@IntType(true, T.bit_count), x) < 0;
}

pub fn expWithSign(comptime T: type, x: T) var {
    var exp = exponent(T, x);
    var res: @IntType(false, 
}
