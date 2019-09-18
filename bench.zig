const std = @import("std");
const math = std.math;
const rand = std.rand;
const heap = std.heap;
const exp = @import("exp.zig").exp;

const time = std.time;
const Timer = time.Timer;

pub fn main() !void {
    var r = rand.Xoroshiro128.init(0);
    r.s[0] = 0xaeecf86f7878dd75;
    r.s[1] = 0x01cd153642e72622;
    
    const allocator = heap.direct_allocator;
    const buf = try allocator.alloc(u8, 16 * 1024 * 1024);
    r.random.bytes(buf);

    var timer = try Timer.start();
    const start = timer.lap();

    var sum: u128 = 0;
    const s = @bytesToSlice(@Vector(2, f64), buf);
    for (s) |pair| {
        sum +%= @bitCast(u128, exp(@Vector(2, f64), pair));
    }

    const end = timer.read();
    std.debug.warn("{} {} {}\n", end, start, buf.len);
    const elapsed_s = @intToFloat(f64, end - start) / time.ns_per_s;
    const throughput = @floatToInt(u64, @intToFloat(f64, buf.len) / elapsed_s);
    var stdout_file = try std.io.getStdOut();
    var stdout_out_stream = stdout_file.outStream();
    const stdout = &stdout_out_stream.stream;
    try stdout.print("checksum: {}. {} bytes/s\n", (sum << 64) +% (sum % (u128(1) << 64)), throughput);
    
    
}
