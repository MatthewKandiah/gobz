const std = @import("std");

pub fn rdtsc() u64 {
    var hi: u32 = 0;
    var low: u32 = 0;

    asm (
        "rdtsc"
        : [low] "={eax}" (low),
          [hi] "={edx}" (hi),
    );
    return (@as(u64, hi) << 32 | @as(u64, low));
}

pub fn tscFreqTicksPerMillisecond() f64 {
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
