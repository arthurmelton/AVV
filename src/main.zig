const std = @import("std");
const parse = @import("parse.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub fn main() !void {
    const parsed = try parse.AVV_File.open(@constCast("./samples/ball.v0.avv"));
    const first = try parsed.get(0, null);

    std.debug.print("{any}\n", .{first.index});
}
