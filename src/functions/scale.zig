const bezier = @import("../bezier.zig");
const std = @import("std");
const functions = @import("mod.zig");
const main = @import("../main.zig");
const _parse = @import("../parse.zig");

pub const AVV_Scale = struct {
    from: _parse.AVV_WorldPostion,
    positions: []bezier.Point,
    ids: []_parse.IdOffsetXYArray,

    pub fn close(self: AVV_Scale) void {
        main.allocator.free(self.positions);
        for (self.ids) |i| {
            main.allocator.free(i.offset);
        }
        main.allocator.free(self.ids);
    }

    pub fn update(self: AVV_Scale, time: u32, objects: []_parse.AVV_Object) void {
        for (objects) |o| {
            var start: ?_parse.IdOffsetXYArray = null;
            for (self.ids) |_id| {
                if (_id.id == o.id) {
                    start = _id;
                    break;
                }
            }
            if (start) |_start| {
                const offset = bezier.get(time - o.nanosecondOffset, self.positions);

                var current: u16 = 0;
                for (o.lines.items) |l| {
                    for (l.points.items) |*p| {
                        p.x += offset * _start.offset[current].x;
                        p.y += offset * _start.offset[current].y;
                        current += 1;
                    }
                }
            }
        }
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

    var ids = try main.allocator.alloc(_parse.IdOffsetXYArray, numOfIds);

    for (0..numOfIds) |i| {
        const id = _parse.byteSwap(u32, @ptrCast(buf[18 + (numOfPoints * 12 + 8) + (i * 4) .. 22 + (numOfPoints * 12 + 8) + (i * 4)].ptr));
        const obj = try _parse.getObject(time, allPrev, id);

        var count: usize = 0;
        for (obj.lines.items) |l| {
            count += l.points.items.len;
        }

        var pos = try main.allocator.alloc(_parse.AVV_WorldPostion, count);

        count = 0;
        for (obj.lines.items) |l| {
            for (l.points.items) |*p| {
                pos[count] = _parse.AVV_WorldPostion{
                    .x = p.x - from.x,
                    .y = p.y - from.y,
                };
                count += 1;
            }
        }

        ids[i] = _parse.IdOffsetXYArray{ .id = id, .offset = pos };
    }

    return functions.AVV_Function{ .scale = .{
        .from = from,
        .positions = points,
        .ids = ids,
    } };
}
