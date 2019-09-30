// Double-precision vector natural exponent
//
// Shawn Landden (c) 2019 All Rights Reserved
// This is *not* software libre.
//
// Based on https://github.com/ARM-software/optimized-routines/
// by Szabolcs Nagy
const std = @import("std");
const math = std.math;
const any = std.vector.any;
const select = std.vector.select;
use @import("exp_data.zig");

export fn _ZGVbN2v_exp(x: @Vector(2, f64)) @Vector(2, f64) {
    return exp(@Vector(2, f64), x);
}

//export fn _ZGVcN4v_exp(x: @Vector(4, f64)) @Vector(4, f64) {
//    return exp(@Vector(4, f64), x);
//}

//export fn _ZGVdN4v_exp(x: @Vector(4, f64)) @Vector(4, f64) {
//    return exp(@Vector(4, f64), x);
//}

//export fn _ZGVeN8v_exp(x: @Vector(8, f64)) @Vector(8, f64) {
//    return exp(@Vector(8, f64), x);
//}

pub fn exp(comptime T: type, x: T) T {
    comptime var vlen = @typeInfo(T).Vector.len;
    return switch (@typeInfo(T).Vector.child) {
    f64 => exp64(vlen, x),
    else => unreachable,
    };
}

fn exp64(comptime vlen: usize, x: @Vector(vlen, f64)) @Vector(vlen, f64) {
    const V = @typeOf(x);
    const S = @Vector(vlen, u64);
    var res: V = undefined;

    const exp_512 = @bitCast(u64, f64(512.0)) >> u6(52);
    const exp_1pn54 = @bitCast(u64, f64(0x1p-54)) >> u6(52);
    var is_special_case = ((@bitCast(S, x) >> @splat(vlen, u6(52))) & @splat(vlen, u64(0x7ff))) -% @splat(vlen, exp_1pn54) >=
        @splat(vlen, exp_512 - exp_1pn54);
    var is_special_case2: @Vector(vlen, bool) = @splat(vlen, false);
    if (any(is_special_case)) {
        var i: u16 = 0;
        while (i < vlen) : (i += 1) {
            if (is_special_case[i] == false) continue;
            if (@bitCast(u64, x[i]) & 0x7ff0000000000000 < @bitCast(u64, f64(0x1p-54)) & 0xfff0000000000000) {
                res[i] = 1.0;
                continue;
            }
            if (@bitCast(u64, x[i]) & 0x7ff0000000000000 >= @bitCast(u64, f64(1024.0)) & 0xfff0000000000000) {
                if (x[i] == -std.math.inf(f64)) {
                    res[i] = 0.0;
                } else if (@bitCast(u64, x[i]) & 0x7ff0000000000000 >= @bitCast(u64, std.math.inf(f64)) & 0xfff0000000000000) {
                    res[i] = 1.0 + x[i];
                } else if ((@bitCast(u64, x[i]) >> 63) > 0) {
                    res[i] = 0; // underflow
                } else {
                    res[i] = std.math.inf(f64); // overflow
                }
            } else {
                is_special_case[i] = false;
                is_special_case2[i] = true;
            }
        }
    }
    var z = x * @splat(vlen, Invln2N);
    var kd = z + @splat(vlen, Shift);
    var ki = @bitCast(u64, kd);
    kd -= @splat(vlen, Shift);
    var r = x + kd * @splat(vlen, Negln2hiN) + kd * @splat(vlen, Negln2loN);
    var idx = @splat(vlen, u64(2)) * (ki % @splat(vlen, u64(N)));
    // TODO check optimizations of this @Vector(2, u6)
    var top = ki << @splat(vlen, u6(52 - EXP_TABLE_BITS));
    var tail = @bitCast(f64, Tab[@truncate(usize, idx)]);
    var sbits = Tab[@truncate(usize, idx) + @splat(vlen, usize(1))] +% @Vector(vlen, u64)(top);
    var r2 = r * r;
    var tmp = tail + r + r2 * (@splat(vlen, C2) + r * @splat(vlen, C3)) + r2 * r2 * (@splat(vlen, C4) + r * @splat(vlen, C5));
    is_special_case2 |= ((@bitCast(u64, x) & @splat(vlen, u64(0x7ff0000000000000))) == @splat(vlen, u64(0))) & ~is_special_case;
    if (any(is_special_case2)) {
        var i: u32 = 0;
        while (i < vlen) : (i += 1) {
            if (is_special_case2[i] == false) continue;
            res[i] = specialcase2(tmp[i], sbits[i], ki[i]);
        }
    }
    var resUnspecial = @bitCast(f64, sbits) + @bitCast(f64, sbits) * tmp;
    return select(V, resUnspecial, res, is_special_case | is_special_case2);
}

fn specialcase2(tmp: f64, _sbits: u64, ki: u64) f64 {
    var scale: f64 = undefined;
    var sbits = _sbits;
    if ((ki & 0x80000000) == 0) {
        sbits -%= u64(1009) << 52;
        scale = @bitCast(f64, sbits);
        return 0x1p1009 * (scale + scale * tmp);
    }
    sbits +%= u64(1022) << 52;
    scale = @bitCast(f64, sbits);
    var y = scale + scale * tmp;
    if (y < 1.0) {
        var lo = scale - y + scale * tmp;
        var hi = 1.0 + y;
        lo = 1.0 - hi + y + lo;
        var narrow_eval: f64 = hi + lo;
        y = narrow_eval - 1.0;
        // avoid negative zero
        if (y == 0.0) {
            y = 0.0;
        }
        // underflow
    }
    y = 0x1p-1022 * y;
    return y;
}

test "exp64" {
    const c = @cImport({
        @cInclude("math.h");
    });
    const rand = std.rand;
    var r = rand.Xoroshiro128.init(0);
    r.s[0] = 0xaeecf86f7878dd75;
    r.s[1] = 0x01cd153642e72622;

{
    var i: usize = 0;
    while (i < 1024 * 64) : (i += 2) {
        var a: u64 = r.next();
        var b: u64 = r.next();
        var ares: f64 = c.exp(@bitCast(f64, a));
        var bres: f64 = c.exp(@bitCast(f64, b));
        var res = exp64(2, @bitCast(f64, @Vector(2, u64)([_]u64{a, b})));
        if (math.isNan(ares)) ares = math.nan(f64);
        if (math.isNan(bres)) bres = math.nan(f64);
        if (math.isNan(res[0])) res[0] = math.nan(f64);
        if (math.isNan(res[1])) res[1] = math.nan(f64);
        if (@bitCast(u64, res[0]) != @bitCast(u64, ares)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, a), ares, res[0]);
            std.os.abort();
        }
        if (@bitCast(u64, res[1]) != @bitCast(u64, bres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, b), bres, res[1]);
            std.os.abort();
        }
    }
}
{
    var i: usize = 0;
    while (i < 1024 * 64) : (i += 4) {
        var a: u64 = r.next();
        var b: u64 = r.next();
        var cv: u64 = r.next();
        var d: u64 = r.next();
        var ares: f64 = c.exp(@bitCast(f64, a));
        var bres: f64 = c.exp(@bitCast(f64, b));
        var cres: f64 = c.exp(@bitCast(f64, cv));
        var dres: f64 = c.exp(@bitCast(f64, d));
        var res = exp64(4, @bitCast(f64, @Vector(4, u64)([_]u64{a, b, cv, d})));
        if (math.isNan(ares)) ares = math.nan(f64);
        if (math.isNan(bres)) bres = math.nan(f64);
        if (math.isNan(cres)) cres = math.nan(f64);
        if (math.isNan(dres)) dres = math.nan(f64);
        if (math.isNan(res[0])) res[0] = math.nan(f64);
        if (math.isNan(res[1])) res[1] = math.nan(f64);
        if (math.isNan(res[2])) res[2] = math.nan(f64);
        if (math.isNan(res[3])) res[3] = math.nan(f64);
        if (@bitCast(u64, res[0]) != @bitCast(u64, ares)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, a), ares, res[0]);
            std.os.abort();
        }
        if (@bitCast(u64, res[1]) != @bitCast(u64, bres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, b), bres, res[1]);
            std.os.abort();
        }
        if (@bitCast(u64, res[2]) != @bitCast(u64, cres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, cv), cres, res[2]);
            std.os.abort();
        }
        if (@bitCast(u64, res[3]) != @bitCast(u64, dres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, d), dres, res[3]);
            std.os.abort();
        }
    }
}
{
    var i: usize = 0;
    while (i < 1024 * 64) : (i += 8) {
        var a: u64 = r.next();
        var b: u64 = r.next();
        var cv: u64 = r.next();
        var d: u64 = r.next();
        var e: u64 = r.next();
        var f: u64 = r.next();
        var g: u64 = r.next();
        var h: u64 = r.next();
        var ares: f64 = c.exp(@bitCast(f64, a));
        var bres: f64 = c.exp(@bitCast(f64, b));
        var cres: f64 = c.exp(@bitCast(f64, cv));
        var dres: f64 = c.exp(@bitCast(f64, d));
        var eres: f64 = c.exp(@bitCast(f64, e));
        var fres: f64 = c.exp(@bitCast(f64, f));
        var gres: f64 = c.exp(@bitCast(f64, g));
        var hres: f64 = c.exp(@bitCast(f64, h));
        var res = exp64(8, @bitCast(f64, @Vector(8, u64)([_]u64{a, b, cv, d, e, f, g, h})));
        if (math.isNan(ares)) ares = math.nan(f64);
        if (math.isNan(bres)) bres = math.nan(f64);
        if (math.isNan(cres)) cres = math.nan(f64);
        if (math.isNan(dres)) dres = math.nan(f64);
        if (math.isNan(eres)) eres = math.nan(f64);
        if (math.isNan(fres)) fres = math.nan(f64);
        if (math.isNan(gres)) gres = math.nan(f64);
        if (math.isNan(hres)) hres = math.nan(f64);
        if (math.isNan(res[0])) res[0] = math.nan(f64);
        if (math.isNan(res[1])) res[1] = math.nan(f64);
        if (math.isNan(res[2])) res[2] = math.nan(f64);
        if (math.isNan(res[3])) res[3] = math.nan(f64);
        if (math.isNan(res[4])) res[4] = math.nan(f64);
        if (math.isNan(res[5])) res[5] = math.nan(f64);
        if (math.isNan(res[6])) res[6] = math.nan(f64);
        if (math.isNan(res[7])) res[7] = math.nan(f64);
        if (@bitCast(u64, res[0]) != @bitCast(u64, ares)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, a), ares, res[0]);
            std.os.abort();
        }
        if (@bitCast(u64, res[1]) != @bitCast(u64, bres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, b), bres, res[1]);
            std.os.abort();
        }
        if (@bitCast(u64, res[2]) != @bitCast(u64, cres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, cv), cres, res[2]);
            std.os.abort();
        }
        if (@bitCast(u64, res[3]) != @bitCast(u64, dres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, d), dres, res[3]);
            std.os.abort();
        }
        if (@bitCast(u64, res[4]) != @bitCast(u64, eres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, e), eres, res[4]);
            std.os.abort();
        }
        if (@bitCast(u64, res[5]) != @bitCast(u64, fres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, f), fres, res[5]);
            std.os.abort();
        }
        if (@bitCast(u64, res[6]) != @bitCast(u64, gres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, g), gres, res[6]);
            std.os.abort();
        }
        if (@bitCast(u64, res[7]) != @bitCast(u64, hres)) {
            std.debug.warn("{} exp({}) should be {}, got {}\n", i, @bitCast(f64, h), hres, res[7]);
            std.os.abort();
        }
    }
}
    std.debug.warn("success!\n");
}
