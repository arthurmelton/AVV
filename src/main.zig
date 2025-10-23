const std = @import("std");
const parse = @import("parse.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub fn main() !void {
    const parsed = try parse.AVV_File.open(@constCast("./samples/ball.v0.avv"));

    var state: ?parse.AVV_Packet = null;
    defer if (state) |s| s.close();

    const start = try parsed.get(1, &state);

    for (start) |i| {
        for (i.lines.items) |l| {
            for (l.points.items) |p| {
                std.debug.print("{any}\n", .{p});
            }
        }
    }

    const second = try parsed.get(2147483648, &state);

    std.debug.print("-------\n", .{});
    for (second) |i| {
        for (i.lines.items) |l| {
            for (l.points.items) |p| {
                std.debug.print("{any}\n", .{p});
            }
        }
    }

    const last = try parsed.get(std.math.maxInt(u32)-1, &state);

    std.debug.print("-------\n", .{});
    for (last) |i| {
        for (i.lines.items) |l| {
            for (l.points.items) |p| {
                std.debug.print("{any}\n", .{p});
            }
        }
    }
}
