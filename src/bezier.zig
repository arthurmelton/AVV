const std = @import("std");

pub const Point = struct { x: u32, y: f64 };

const i_type = u6;
const max_tries = std.math.maxInt(i_type);

pub fn get(a: u32, points: []Point) f64 {
    const upper: u32 = points[points.len - 1].x;
    if (a >= upper) return points[points.len - 1].y;

    const upper_minus_a = upper - a;
    const num_of_points = @as(u32, @truncate(points.len));

    var count: u32 = 1;
    var val: f64 = 0;

    for (1..num_of_points) |i| {
        if (i == 1 or i == num_of_points - 2) {
            count = num_of_points - 1;
        } else if (i == num_of_points - 1) {
            count = 1;
        } else {
            count *= @as(u32, @truncate(@divExact(num_of_points + 1 - i, i)));
        }

        var current: u64 = upper;

        for (0..num_of_points - 1) |x| {
            const factor = if (x < i) a else upper_minus_a;

            current = (current * factor) / upper;
        }

        current *= count;

        val += (@as(f64, @floatFromInt(current)) * points[i].y) / @as(f64, @floatFromInt(upper));
    }

    return val;
}

pub fn find(calc: u32, points: []Point, values: *[max_tries]u32) u32 {
    var i: i_type = 0;

    var current = tryCalc(calc, calc, @constCast(&points));

    while (!std.mem.containsAtLeast(u32, values[0..i], 1, &[1]u32{current}) and i < max_tries) {
        values[i] = current;
        i += 1;
        current = tryCalc(current, calc, @constCast(&points));
    }

    return current;
}

fn tryCalc(a: u32, goFor: i64, points: []Point) u32 {
    const upper: u32 = points[points.len - 1].x;
    const upper_minus_a = upper - a;
    const num_of_points = @as(u32, @truncate(points.len));

    var count: u32 = 1;
    var val: u64 = 0;
    var derivative: u64 = 0;

    for (1..num_of_points) |i| {
        if (i == 1 or i == num_of_points - 2) {
            count = num_of_points - 1;
        } else if (i == num_of_points - 1) {
            count = 1;
        } else {
            count *= @as(u32, @truncate(@divExact(num_of_points + 1 - i, i)));
        }

        var current: u64 = points[i].x;
        var term: u64 = points[i].x;

        for (0..num_of_points - 1) |x| {
            const factor = if (x < i) a else upper_minus_a;

            current = (current * factor) / upper;

            if (x != 0 and x != i) {
                term = (term * factor) / upper;
            }
        }

        current *= count;

        val += current;

        term = (term * (i * upper - (num_of_points - 1) * a)) / upper;
        term *= count;

        derivative += term;
    }

    if (derivative == 0) derivative = 1;

    return @intCast(a + @divTrunc((goFor - @as(i64, @intCast(val))) * upper, @as(i65, @intCast(derivative))));
}
