const std = @import("std");
const main = @import("main.zig");
const bezier = @import("bezier.zig");
const functions = @import("functions/mod.zig");

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
    snapshots: std.ArrayListAligned(AVV_Action, null),

    pub fn close(self: AVV_Packet) void {
        for (self.snapshots.items) |i| {
            i.close();
        }
        self.snapshots.deinit();
    }
};

pub const AVV_Action = struct {
    nanosecondOffest: u32,
    function: functions.AVV_Function,

    pub fn close(self: AVV_Action) void {
        self.function.close();
    }
};

pub const AVV_Line = struct { startRounded: bool, endRounded: bool, points: std.ArrayListAligned(AVV_WorldPostion, null) };

pub const AVV_WorldPostion = struct { x: f64, y: f64 };

pub const IdOffsetXYUnion = struct {
    id: u32,
    offset_x: f64,
    offset_y: f64,
};

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

            var packets = std.ArrayList(AVV_Action).init(main.allocator);

            var header: [7]u8 = undefined;
            while (decompressed.read(&header) catch 0 == 7) {
                const function = header[0];
                const timeOffset = byteSwap(u32, header[1..5]);
                const args = byteSwap(u16, header[5..7]);

                const buf = try main.allocator.alloc(u8, args);
                defer main.allocator.free(buf);
                _ = try decompressed.read(buf);

                const funcUnion: functions.AVV_Function = switch (@as(functions.functions, @enumFromInt(function))) {
                    .create => try functions.create.parse(buf),
                    .delete => try functions.delete.parse(buf),
                    .move => try functions.move.parse(buf),
                    .scale => try functions.scale.parse(timeOffset, packets.items, buf),
                    _ => unreachable,
                };

                (try packets.addOne()).* = AVV_Action{
                    .nanosecondOffest = timeOffset,
                    .function = funcUnion,
                };
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

pub fn getPos(time: u32, items: []AVV_Action, id: u32) !AVV_WorldPostion {
    var ids: u32 = 0;
    var pos: ?AVV_WorldPostion = null;
    for (items) |i| {
        switch (i.function) {
            .create => |c| {
                if (ids == id) {
                    pos = c.lines.items[0].points.items[0];
                }
                ids += 1;
            },
            .delete => |d| if (std.mem.containsAtLeast(u32, d.ids, 1, &[1]u32{id})) return error.itemDoesNotExist,
            .move => |m| if (std.mem.containsAtLeast(u32, m.ids, 1, &[1]u32{id})) {
                const offset = bezier.get(time - i.nanosecondOffest, m.positions);

                pos.?.x += if (m.effects_x) offset else 0;
                pos.?.y += if (m.effects_y) offset else 0;
            },
            .scale => |s| {
                var start: ?IdOffsetXYUnion = null;
                for (s.ids) |_id| {
                    if (_id.id == id) {
                        start = _id;
                        break;
                    }
                }

                if (start) |_start| {
                    const offset = bezier.get(time - i.nanosecondOffest, s.positions);

                    pos.?.x += offset * _start.offset_x;
                    pos.?.y += offset * _start.offset_y;
                }
            },
        }
    }

    if (pos) |p| {
        return p;
    }
    return error.NotFound;
}

pub fn read(comptime T: type, file: anytype) !T {
    var buf: [@sizeOf(T)]u8 = undefined;
    _ = try file.read(&buf);

    return @bitCast(byteSwap(T, &buf));
}

pub fn byteSwap(comptime T: type, buf: *[@sizeOf(T)]u8) T {
    if (@import("builtin").cpu.arch.endian() == .big) {
        return @bitCast(buf.*);
    } else {
        return @bitCast(@byteSwap(@as(std.meta.Int(.unsigned, @sizeOf(T) * 8), @bitCast(buf.*))));
    }
}
