const bezier = @import("../bezier.zig");
const std = @import("std");
const functions = @import("mod.zig");
const main = @import("../main.zig");
const _parse = @import("../parse.zig");

pub const AVV_Scale = struct {
    from: _parse.AVV_WorldPostion,
    positions: []bezier.Point,
    ids: []_parse.IdOffsetXYUnion,

    pub fn close(self: AVV_Scale) void {
        main.allocator.free(self.positions);
        main.allocator.free(self.ids);
    }
};

pub fn parse(time: u32, allPrev: []_parse.AVV_Action, buf: []u8) !functions.AVV_Function {
    const header = _parse.byteSwap(u16, @ptrCast(buf[0..2].ptr));
    const from = _parse.AVV_WorldPostion{
        .x = _parse.byteSwap(f64, @ptrCast(buf[2..10].ptr)),
        .y = _parse.byteSwap(f64, @ptrCast(buf[10..18].ptr)),
    };

    const numOfPoints = header & 0x2FFF;
    const numOfIds = (buf.len - 18 - (numOfPoints * 12 + 8)) / 4;

    var points = try main.allocator.alloc(bezier.Point, numOfPoints + 1);

    points[0] = bezier.Point{
        .x = 0,
        .y = _parse.byteSwap(f64, @ptrCast(buf[18..26].ptr)),
    };

    for (0..numOfPoints) |i| {
        points[i + 1] = bezier.Point{
            .x = _parse.byteSwap(u32, @ptrCast(buf[26 + (i * 12) .. 30 + (i * 12)].ptr)),
            .y = _parse.byteSwap(f64, @ptrCast(buf[30 + (i * 12) .. 36 + (i * 12)].ptr)),
        };
    }

    var ids = try main.allocator.alloc(_parse.IdOffsetXYUnion, numOfIds);

    for (0..numOfIds) |i| {
        const id = _parse.byteSwap(u32, @ptrCast(buf[18 + (numOfPoints * 12 + 8) + (i * 4) .. 22 + (numOfPoints * 12 + 8) + (i * 4)].ptr));
        const pos = try _parse.getPos(time, allPrev, id);

        ids[i] = _parse.IdOffsetXYUnion{ .id = id, .offset_x = pos.x, .offset_y = pos.y };
    }

    return functions.AVV_Function{ .scale = .{
        .from = from,
        .positions = points,
        .ids = ids,
    } };
}
