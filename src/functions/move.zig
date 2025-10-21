const bezier = @import("../bezier.zig");

pub const AVV_Move = struct {
    effects_x: bool,
    effects_y: bool,
    positions: []bezier.Point,
    ids: []u32,
};
