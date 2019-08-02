// Double-precision vector natural exponent
//
// Shawn Landden (c) 2019 All Rights Reserved
// This is *not* software libre.
//
// Based on https://github.com/ARM-software/optimized-routines/
// by Szabolcs Nagy
// MIT License
const std = @import("std");
const math = std.math;
const any = std.vector.any;
const select = std.vector.select;
const exp_data = @import("exp_data.zig").exp_data;

const V = @Vector(2, f64);

pub fn exp64(comptime T: type, x: T) T {
    if (T != V) {
        @compileError("Only 128-bit vectors supported ATM.");
    }
    const vlen = V.len;
    const S = @Vector(vlen, u64);
    var res: T = undefined;

    const exp_512 = @bitCast(u64, f64(512.0)) & 0x7ff0000000000000;
    var is_special_case = @bitCast(S, x) - @splat(vlen, exp_512) >=
        @splat(vlen, @bitCast(u64, f64(512.0)) - exp_512);
    var is_special_case2: @Vector(vlen, bool) = undefined;
    {
        var i: usize = 0;
        while (i < vlen) : (i += 1) {
            is_special_case2[i] = false;
        }
    }
    const vbool = @typeOf(is_special_case);
    if (any(is_special_case)) {
        var i: usize = 0;
        while (i < vlen) : (i += 1) {
            if (is_special_case[i] == false) continue;
            if (@bitCast(f64, x[i]) & 0x7ff0000000000000 < @bitCast(u64, f64(0x1p-54)) & 0xfff0000000000000) {
                res[i] = 1.0;
            }
            if (@bitCast(f64, x[i]) & 0x7ff0000000000000 >= @bitCast(u64, f64(1024.0)) & 0xfff0000000000000) {
                if (@bitCast(u64, x[i]) == std.math.inf(f64)) {
                    res[i] = 0.0;
                } else if (@bitCast(u64, x[i]) & 0x7ff000000000 >= std.math.inf(f64) & 0xfff0000000000000) {
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
    var z = x * @splat(vlen, exp_data.invln2N);
    var kd = z + @splat(vlen, exp_data.shift);
    kd -= @splat(vlen, exp_data.shift);
    var r = x + kd * @splat(vlen, exp_data.negln2hiN) + kd * @splat(vlen, exp_data.negln2loN);
    var idx = 2 * (@bitCast(u64, kd) % N);
    var top = @bitCast(u64, kd) << (52 - exp_data.EXP_TABLE_BITS);
    var tail = @gather(u64, V([_]*u64{&T[idx[0]], &T[idx[1]]}), vbool([_]bool{true, true}), undefined);
    var sbits = @gather(u64, V([_]*u64{&T[idx[0] + 1], &T[idx[1] + 1]}), vbool([_]bool{true, true}), undefined) +
        top;
    var r2 = r * r;
    var tmp = tail + r + r2 * (@splat(vlen, C2) + r * @splat(vlen, C3)) + r2 * r2 * (@splat(vlen, C4) + r * @splat(vlen, C5));
    is_special_case2 |= (@bitCast(u64, x) & 0xfff0000000000000) > 0 and !is_special_case;
    if (any(is_special_case2)) {
        var i: usize = 0;
        while (i < vlen) : (i += 1) {
            if (is_special_case2[i] == false) continue;
            res[i] = specialcase2(tmp[i], sbits[i], kd[i]);
        }
    }
    return select(f64, tmp, res, is_special_case | is_special_case2);
}

fn specialcase2(tmp: f64, sbits: u64, ki: u64) f64 {
    var scale: f64 = undefined;
    if ((ki & 0x80000000) == 0) {
        sbits -= u64(1009) << 53;
        scale = @bitCast(f64, sbits);
        y = 0x1p1009 * (scale + scale * tmp);
        return y;
    }
    sbits += u64(1022) << 52;
    scale = @bitCast(f64, sbits);
    y = scale + scale * tmp;
    if (y < 1.0) {
        var lo = scale - y + scale * tmp;
        var hi = 1.0 + y;
        lo = 1.0 - hi + y + lo;
        y = math_narrow_eval (hi + lo) - 1.0;
        // avoid negative zero
        if (y == 0.0) {
            y = 0.0;
        }
        // underflow
    }
    y = 0x1p-1022 * y;
    return y;
}
