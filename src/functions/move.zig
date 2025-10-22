const bezier = @import("../bezier.zig");
const std = @import("std");
const functions = @import("mod.zig");
const main = @import("../main.zig");
const _parse = @import("../parse.zig");

pub const AVV_Move = struct {
    effects_x: bool,
    effects_y: bool,
    positions: []bezier.Point,
    ids: []u32,

    pub fn close(self: AVV_Move) void {
        main.allocator.free(self.positions);
        main.allocator.free(self.ids);
    }

    pub fn update(self: AVV_Move, time: u32, objects: []_parse.AVV_Object) void {
        for (objects) |o| {
            if (std.mem.containsAtLeast(u32, self.ids, 1, &[1]u32{o.id})) {
                const offset = bezier.get(time - o.nanosecondOffset, self.positions);

                for (o.lines.items) |l| {
                    for (l.points.items) |*p| {
                        p.x += if (self.effects_x) offset else 0;
                        p.y += if (self.effects_y) offset else 0;
                    }
                }
            }
        }
    }
};

pub fn parse(buf: []u8) !functions.AVV_Function {
    const header = _parse.byteSwap(u16, @ptrCast(buf[0..2].ptr));

    const x = header & 0x8000 == 0x8000;
    const y = header & 0x4000 == 0x4000;

    const numOfPoints = header & 0x2FFF;
    const numOfIds = (buf.len - 2 - (numOfPoints * 12 + 8)) / 4;

    var points = try main.allocator.alloc(bezier.Point, numOfPoints + 1);

    points[0] = bezier.Point{
        .x = 0,
        .y = _parse.byteSwap(f64, @ptrCast(buf[2..10].ptr)),
    };

    for (0..numOfPoints) |i| {
        points[i + 1] = bezier.Point{
            .x = _parse.byteSwap(u32, @ptrCast(buf[10 + (i * 12) .. 14 + (i * 12)].ptr)),
            .y = _parse.byteSwap(f64, @ptrCast(buf[14 + (i * 12) .. 20 + (i * 12)].ptr)),
        };
    }

    var ids = try main.allocator.alloc(u32, numOfIds);

    for (0..numOfIds) |i| {
        ids[i] = _parse.byteSwap(u32, @ptrCast(buf[2 + (numOfPoints * 12 + 8) + (i * 4) .. 6 + (numOfPoints * 12 + 8) + (i * 4)].ptr));
    }

    return functions.AVV_Function{ .move = .{
        .effects_x = x,
        .effects_y = y,
        .positions = points,
        .ids = ids,
    } };
}
