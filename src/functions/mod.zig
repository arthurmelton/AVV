pub const create = @import("create.zig");
pub const delete = @import("delete.zig");
pub const move = @import("move.zig");

pub const functions = enum { create, delete, move };

pub const AVV_Function = union(functions) {
    create: create.AVV_Create,
    delete: delete.AVV_Delete,
    move: move.AVV_Move,

    pub fn close(self: AVV_Function) void {
        switch (self) {
            .create => |x| x.close(),
            else => {},
        }
    }
};
