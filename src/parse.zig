const std = @import("std");
const main = @import("main.zig");
const bezier = @import("bezier.zig");

const AVVFileOpenError = error{
    NotAVVFile,
};

pub const AVV_Packets = struct {
    nanosecondOffest: u64,
    byteOffest: u64,
};

pub const AVV_Packet = struct {
    index: u64,
    startNanosecondOffest: u64,
    endNanosecondOffest: u64,
    snapshots: std.ArrayListAligned(AVV_Snapshot, null),

    pub fn close(self: AVV_Packet) void {
        for (self.snapshots.items) |i| {
            i.close();
        }
        self.snapshots.deinit();
    }
};

pub const AVV_Snapshot = struct {
    nanosecondOffest: u32,
    function: AVV_Function,

    pub fn close(self: AVV_Snapshot) void {
        self.function.close();
    }
};

const functions = enum { create, delete, move };

pub const AVV_Function = union(functions) {
    create: AVV_Create,
    delete: AVV_Delete,
    move: AVV_Move,

    pub fn close(self: AVV_Function) void {
        switch (self) {
            .create => |c| {
                for (c.points.items) |p| {
                    p.points.deinit();
                }
                c.points.deinit();
            },
            else => {},
        }
    }
};

pub const AVV_Create = struct { points: std.ArrayListAligned(AVV_Line, null) };

pub const AVV_Delete = struct { ids: []u32 };

pub const AVV_Move = struct {
    effects_x: bool,
    effects_y: bool,
    positions: []bezier.Point,
    ids: []u32,
};

pub const AVV_Line = struct { startRounded: bool, endRounded: bool, points: std.ArrayListAligned(AVV_WorldPostion, null) };

pub const AVV_WorldPostion = struct { x: f64, y: f64 };

pub const AVV_File = struct {
    file: std.fs.File,
    version: u8,
    aspectRatio: f64,
    loop: bool,
    xInTermsOfY: bool,
    highestColor: f32,
    packets: ?[]AVV_Packets,
    videoLength: u64,
    packetsOffset: u64,

    pub fn open(input: []u8) !AVV_File {
        const file = try std.fs.cwd().openFile(input, .{});

        var magic: [3]u8 = undefined;

        _ = try file.read(&magic);

        if (magic[0] != 0x41 or magic[1] != 0x56 or magic[2] != 0x56) return AVVFileOpenError.NotAVVFile;

        const version: u8 = try read(u8, file);
        const aspectRatio: u64 = try read(u64, file);
        const highestColor: f32 = try read(f32, file);
        const numOfPackets: u64 = try read(u64, file);

        var packets: ?[]AVV_Packets = null;
        if (numOfPackets > 0) {
            packets = try main.allocator.alloc(AVV_Packets, numOfPackets);
            for (0..numOfPackets) |i| {
                packets.?[i].nanosecondOffest = try read(u64, file);
                packets.?[i].byteOffest = try read(u64, file);
            }
        }

        const videoLength: u64 = try read(u64, file);
        const packetsOffset = try file.getPos();

        return AVV_File{
            .file = file,
            .version = version,
            .aspectRatio = @bitCast(aspectRatio & 0x3FFFFFFFFFFFFFFF),
            .loop = (aspectRatio >> 63) & 1 == 1,
            .xInTermsOfY = (aspectRatio >> 62) & 1 == 1,
            .highestColor = highestColor,
            .packets = packets,
            .videoLength = videoLength,
            .packetsOffset = packetsOffset,
        };
    }

    pub fn get(self: AVV_File, time: u64, prev: ?AVV_Packet) !AVV_Packet {
        var current = prev;
        if (prev == null or prev.?.startNanosecondOffest > time or prev.?.endNanosecondOffest <= time) {
            var index: u64 = undefined;
            bk: {
                if (self.packets != null) {
                    for (0..self.packets.?.len) |i| {
                        if (self.packets.?[i].nanosecondOffest > time) {
                            index = i;
                            break :bk;
                        }
                    }
                    index = self.packets.?.len;
                } else {
                    index = 0;
                }
            }

            if (prev) |p| p.close();

            try self.file.seekTo(self.packetsOffset + (if (index == 0) 0 else self.packets.?[index - 1].byteOffest));

            var d = try std.compress.lzma.decompress(
                main.allocator,
                self.file.reader(),
            );
            defer d.deinit();

            var decompressed = d.reader();

            var packets = std.ArrayList(AVV_Snapshot).init(main.allocator);

            var have_read: u64 = 0;
            while (have_read < d.state.unpacked_size.?) {
                const function = try read(u8, decompressed);
                const timeOffset = try read(u32, decompressed);
                const args = try read(u16, decompressed);

                var buf = try main.allocator.alloc(u8, args);
                defer main.allocator.free(buf);
                _ = try decompressed.read(buf);

                have_read += 7 + args;

                var i: u16 = 0;

                const funcUnion: AVV_Function = bk: switch (function) {
                    0 => {
                        var points = try std.ArrayList(AVV_Line).initCapacity(main.allocator, 0);
                        var positions = try std.ArrayList(AVV_WorldPostion).initCapacity(main.allocator, 0);

                        var connected_end: bool = undefined;
                        var startRounded: bool = byteSwap(u16, buf[0..2]) == 0xFFF0;
                        if (startRounded) i += 2;

                        while (i < args) {
                            const firstTwo = byteSwap(u16, @ptrCast(buf[i .. i + 2].ptr));
                            if (firstTwo == 0xFFF0 or firstTwo == 0x7FF0) {
                                connected_end = firstTwo == 0xFFF0;

                                var new = try points.addOne();
                                new = @constCast(&AVV_Line{ .startRounded = startRounded, .endRounded = connected_end, .points = positions });

                                positions = std.ArrayList(AVV_WorldPostion).init(main.allocator);

                                startRounded = connected_end;
                                i += 2;
                            } else {
                                const first = byteSwap(f64, @ptrCast(buf[i .. i + 8].ptr));
                                i += 8;
                                const second = byteSwap(f64, @ptrCast(buf[i .. i + 8].ptr));
                                i += 8;

                                var new = try positions.addOne();
                                new = @constCast(&AVV_WorldPostion{
                                    .x = first,
                                    .y = second,
                                });
                            }
                        }

                        if (positions.items.len > 0) {
                            var new = try points.addOne();
                            new = @constCast(&AVV_Line{ .startRounded = startRounded, .endRounded = false, .points = positions });
                        } else {
                            positions.deinit();
                        }

                        break :bk AVV_Function{ .create = .{ .points = points } };
                    },
                    else => unreachable,
                };

                var new = packets.addOne();
                new = @constCast(&AVV_Snapshot{
                    .nanosecondOffest = timeOffset,
                    .function = funcUnion,
                });
            }

            current = AVV_Packet{
                .index = index,
                .startNanosecondOffest = if (index == 0) 0 else self.packets.?[index - 1].nanosecondOffest,
                .endNanosecondOffest = if (index == 0 or index == self.packets.?.len) self.videoLength else self.packets.?[index].nanosecondOffest,
                .snapshots = packets,
            };
        }

        return error.Todo;
    }

    pub fn close(self: AVV_File) void {
        self.file.close();
        main.allocator.free(self.packets);
    }
};

fn read(comptime T: type, file: anytype) !T {
    var buf: [@sizeOf(T)]u8 = undefined;
    _ = try file.read(&buf);

    return @bitCast(byteSwap(T, &buf));
}

fn byteSwap(comptime T: type, buf: *[@sizeOf(T)]u8) T {
    if (@import("builtin").cpu.arch.endian() == .big) {
        return @bitCast(buf.*);
    } else {
        return @bitCast(@byteSwap(@as(std.meta.Int(.unsigned, @sizeOf(T) * 8), @bitCast(buf.*))));
    }
}
