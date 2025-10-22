pub const create = @import("create.zig");
pub const delete = @import("delete.zig");
pub const move = @import("move.zig");
pub const scale = @import("scale.zig");

pub const functions = enum(u8) {
    create = 0,
    delete = 1,
    move = 2,
    scale = 9,
    _,
};

pub const AVV_Function = union(functions) {
    create: create.AVV_Create,
    delete: delete.AVV_Delete,
    move: move.AVV_Move,
    scale: scale.AVV_Scale,

    pub fn close(self: AVV_Function) void {
        switch (self) {
            .create => |x| x.close(),
            .delete => |x| x.close(),
            .move => |x| x.close(),
            .scale => |x| x.close(),
        }
    }
};
