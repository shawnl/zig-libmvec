const std = @import("std");
const math = std.math;
const rand = std.rand;
const heap = std.heap;
const exp = @import("exp.zig").exp;
const assert = std.debug.assert;

const size = 1024 * 1024 * 1024;

const V2 = @Vector(2, f64);
const V4 = @Vector(4, f64);
const V8 = @Vector(8, f64);
extern fn _ZGVbN2v_exp(x: V2) V2;
const two = _ZGVbN2v_exp;
extern fn _ZGVdN4v_exp(x: V4) V4;
const four = _ZGVdN4v_exp;
extern fn _ZGVeN8v_exp(x: V8) V8;
const eight = _ZGVeN8v_exp;

const time = std.time;
const Timer = time.Timer;

pub fn main() !void {
    var r = rand.Xoroshiro128.init(0);
    r.s[0] = 0xaeecf86f7878dd75;
    r.s[1] = 0x01cd153642e72623;
    
    const allocator = heap.direct_allocator;
    const buf = try allocator.alloc(u8, size);
    const resbuf = try allocator.alloc(u8, size);
    r.random.bytes(buf);
    // normalize
    var doubles = @bytesToSlice(f64, buf);
    var rands = @bytesToSlice(u64, buf);
    for (rands) |thisrand, i| {
        doubles[i] = @intToFloat(f64, thisrand) / @intToFloat(f64, 1 << 63);
    }

var two_sys: f64 = undefined;
var two_native: f64 = undefined;
var four_sys: f64 = undefined;
var four_native: f64 = undefined;
var eight_sys: f64 = undefined;
var eight_native: f64 = undefined;
    var timer = try Timer.start();
    var start = timer.lap();
var end = timer.read();
{
    const res = @bytesToSlice(V2, resbuf);
    const s = @bytesToSlice(V2, buf);
    for (s) |pair, j| {
        res[j] = two(pair);//exp(V2, pair);
    }

    end = timer.read();
try check(resbuf);
two_sys = @intToFloat(f64, end - start);
    start = timer.read();

    for (s) |pair, j| {
        res[j] = exp(@Vector(2, f64), pair);//exp(V2, pair);
    }

    end = timer.read();
//try check(resbuf);
two_native = @intToFloat(f64, end - start);
}
{
//    const res = @bytesToSlice(V4, resbuf);
    const wrong = try allocator.alloc(u8, size);
    const res = @bytesToSlice(V4, wrong);
    const s = @bytesToSlice(V4, buf);

    start = timer.read();

    for (s) |pair, j| {
        res[j] = four(pair);//exp(V4, pair);
    }
const w = @bytesToSlice(f64, wrong);
const right = @bytesToSlice(f64, resbuf);
for (w) |d, i| {
if (@bitCast(u64, d) != @bitCast(u64, right[i])) {
std.debug.warn("{} ({x}) and {} ({x})\n", d, @bitCast(u64, d), right[i], @bitCast(u64, right[i]));
}
}
    end = timer.read();
try check(resbuf);
four_sys = @intToFloat(f64, end - start);
    start = timer.read();

    for (s) |pair, j| {
        res[j] = exp(@Vector(4, f64), pair);//exp(V, pair);
    }

    end = timer.read();
try check(resbuf);
four_native = @intToFloat(f64, end - start);
}
{
    const res = @bytesToSlice(V8, resbuf);
    const s = @bytesToSlice(V8, buf);

    start = timer.read();

    for (s) |pair, j| {
        res[j] = eight(pair);//exp(V, pair);
    }

    end = timer.read();
try check(resbuf);
eight_sys = @intToFloat(f64, end - start);
    start = timer.read();

    for (s) |pair, j| {
        res[j] = exp(@Vector(8, f64), pair);//exp(V, pair);
    }

    end = timer.read();
try check(resbuf);
eight_native = @intToFloat(f64, end - start);
}
//    std.debug.warn("{}ns {}bytes\n", end - start, buf.len);
//    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
//    const throughput = @floatToInt(u64, @intToFloat(f64, buf.len) / elapsed_s);
    var len = @intToFloat(f64, buf.len) * time.ns_per_s;
    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = stdout_file.outStream();
    const stdout = &stdout_out_stream.stream;
    try stdout.print("2: {} bytes/s {} bytes/s ({}%)\n", len / two_sys, len / two_native, two_sys / two_native);    
    try stdout.print("4: {} bytes/s {} bytes/s ({}%)\n", len / four_sys, len /four_native, four_sys / four_native);
    try stdout.print("8: {} bytes/s {} bytes/s ({}%)\n", len / eight_sys, len /eight_native, eight_sys / eight_native);

}

fn check(x: []u8) !void {
    var sum: u64 = 0;
    var resdoubles = @bytesToSlice(f64, x);
    for (resdoubles) |double| {
        sum +%= @bitCast(u64, double);
    }
std.debug.warn("{x}\n", sum);
if (sum == 5) return error.Damn;
std.mem.set(u8, x, 0);
}
