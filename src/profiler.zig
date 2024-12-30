const std = @import("std");

fn rdtsc() u64 {
    var hi: u32 = 0;
    var low: u32 = 0;

    asm ("rdtsc"
        : [low] "={eax}" (low),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32 | @as(u64, low));
}

fn tscFreqTicksPerMillisecond() f64 {
    const calibration_duration_nanos = 50_000_000; // 50ms
    const start_time_nanos = std.time.nanoTimestamp();
    const start_tsc = rdtsc();
    while (std.time.nanoTimestamp() < start_time_nanos + calibration_duration_nanos) {
        // wait for calibration time to pass
    }
    const end_time_nanos = std.time.nanoTimestamp();
    const end_tsc = rdtsc();

    const nanos = end_time_nanos - start_time_nanos;
    const ticks = end_tsc - start_tsc;
    const ticks_per_millisecond = @as(f64, @floatFromInt(ticks)) / @as(f64, @floatFromInt(nanos)) * 1e6;

    return ticks_per_millisecond;
}

pub const TickCountsMap = std.StringHashMap(u64);

pub const Profiler = struct {
    cpu_ticks_per_millisecond: f64,
    tick_counts_map: TickCountsMap,

    const Self = @This();

    fn countToMilliseconds(self: Self, count: u64) f64 {
        return @as(f64, @floatFromInt(count)) / self.cpu_ticks_per_millisecond;
    }

    // allowing capture to allocate memory may be an error in the long run, but I think it's fine for my current use case
    // I want to profile my main loop, which will run a lot of times, always inserting the same small number of keys with updated values
    // so if there are any memory allocations on insertion, they should all happen in the first run through the loop, since we will be reusing a small set of keys
    // A thought for later, it would be really neat if we could use some comptime magic to gather a list of all the labels that will be used for this profiler. Then we
    // could keep a fixed size array of labels, and stack-allocate an equal-size array of values, associating key-value pairs by array index. That would minimise runtime overhead.
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .cpu_ticks_per_millisecond = tscFreqTicksPerMillisecond(),
            .tick_counts_map = TickCountsMap.init(allocator),
        };
    }

    pub fn capture(self: *Self, label: []const u8) !void {
        try self.tick_counts_map.put(label, rdtsc());
    }

    pub fn report(self: Self, start_label: []const u8, end_label: []const u8) void {
        const start_ticks = self.tick_counts_map.get(start_label) orelse @panic("ERROR: reporting start label that hasn't been inserted");
        const end_ticks = self.tick_counts_map.get(end_label) orelse @panic("ERROR: reporting end label that hasn't been inserted");
        if (start_ticks > end_ticks) {
            @panic("ERROR: reporting start that occurs later than end");
        }
        const diff_ticks = end_ticks - start_ticks;
        const diff_time_ms = self.countToMilliseconds(diff_ticks);
        std.debug.print("PROFILE: {s} to {s}\n\t{d:.6}ms\n\n", .{ start_label, end_label, diff_time_ms });
    }
};
