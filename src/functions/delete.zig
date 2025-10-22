const std = @import("std");
const functions = @import("mod.zig");
const main = @import("../main.zig");
const _parse = @import("../parse.zig");

pub const AVV_Delete = struct {
    ids: []u32,

    pub fn close(self: AVV_Delete) void {
        main.allocator.free(self.ids);
    }
};

pub fn parse(buf: []u8) !functions.AVV_Function {
    var ids = try main.allocator.alloc(u32, buf.len / 4);

    for (0..buf.len / 4) |i| {
        ids[i] = _parse.byteSwap(u32, @ptrCast(buf[i * 4 .. i * 4 + 4].ptr));
    }

    return functions.AVV_Function{ .delete = .{ .ids = ids } };
}
