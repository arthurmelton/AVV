const std = @import("std");
const _parse = @import("../parse.zig");
const functions = @import("mod.zig");
const main = @import("../main.zig");

pub const AVV_Create = struct {
    points: std.ArrayListAligned(_parse.AVV_Line, null),

    pub fn close(self: AVV_Create) void {
        for (self.points.items) |p| {
            p.points.deinit();
        }
        self.points.deinit();
    }
};

pub fn parse(buf: []u8) !functions.AVV_Function {
    var i: u16 = 0;
    var points = try std.ArrayList(_parse.AVV_Line).initCapacity(main.allocator, 0);
    var positions = try std.ArrayList(_parse.AVV_WorldPostion).initCapacity(main.allocator, 0);

    var connected_end: bool = undefined;
    var startRounded: bool = _parse.byteSwap(u16, buf[0..2]) == 0xFFF0;
    if (startRounded) i += 2;

    while (i < buf.len) {
        const firstTwo = _parse.byteSwap(u16, @ptrCast(buf[i .. i + 2].ptr));
        if (firstTwo == 0xFFF0 or firstTwo == 0x7FF0) {
            connected_end = firstTwo == 0xFFF0;

            (try points.addOne()).* = _parse.AVV_Line{ .startRounded = startRounded, .endRounded = connected_end, .points = positions };

            positions = std.ArrayList(_parse.AVV_WorldPostion).init(main.allocator);

            startRounded = connected_end;
            i += 2;
        } else {
            const first = _parse.byteSwap(f64, @ptrCast(buf[i .. i + 8].ptr));
            i += 8;
            const second = _parse.byteSwap(f64, @ptrCast(buf[i .. i + 8].ptr));
            i += 8;

            (try positions.addOne()).* = _parse.AVV_WorldPostion{
                .x = first,
                .y = second,
            };
        }
    }

    if (positions.items.len > 0) {
        (try points.addOne()).* = _parse.AVV_Line{ .startRounded = startRounded, .endRounded = false, .points = positions };
    } else {
        positions.deinit();
    }

    return functions.AVV_Function{ .create = .{ .points = points } };
}
