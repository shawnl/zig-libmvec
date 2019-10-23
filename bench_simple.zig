const std = @import("std");
const math = std.math;
const rand = std.rand;
const heap = std.heap;
const exp = @import("exp.zig").exp;

const V = @Vector(8, f64);
//extern fn _ZGVbN2v_exp(x: V) V;
//const doit = _ZGVbN2v_exp;

const time = std.time;
const Timer = time.Timer;

pub fn main() !void {
    var r = rand.Xoroshiro128.init(0);
    r.s[0] = 0xaeecf86f7878dd75;
    r.s[1] = 0x01cd153642e72623;
    
    const allocator = heap.direct_allocator;
    const buf = try allocator.alloc(u8, 128 * 1024 * 1024);
    const resbuf = try allocator.alloc(u8, 128 * 1024 * 1024);
    const res = @bytesToSlice(V, resbuf);
    r.random.bytes(buf);
    // normalize
    var doubles = @bytesToSlice(f64, buf);
    var rands = @bytesToSlice(u64, buf);
    for (rands) |thisrand, i| {
        doubles[i] = @intToFloat(f64, thisrand) / @intToFloat(f64, 1 << 63);
    }

    var timer = try Timer.start();
    const start = timer.lap();

    const s = @bytesToSlice(V, buf);
    for (s) |pair, j| {
        res[j] = exp(@Vector(2, f64), pair);//exp(V, pair);
    }

    const end = timer.read();
    var sum: u64 = 0;
    var resdoubles = @bytesToSlice(f64, resbuf);
    for (resdoubles) |double| {
        sum +%= @bitCast(u64, double);
    }
    std.debug.warn("{}ns {}bytes\n", end - start, buf.len);
    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, @intToFloat(f64, buf.len) / elapsed_s);
    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = stdout_file.outStream();
    const stdout = &stdout_out_stream.stream;
    try stdout.print("checksum: {x}. {} bytes/s\n", sum, throughput);    
}

