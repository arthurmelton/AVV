const std = @import("std");
const main = @import("main.zig");
const bezier = @import("bezier.zig");
const functions = @import("functions/mod.zig");

const AVVFileOpenError = error{
    NotAVVFile,
};

pub const AVV_Packets = struct {
    nanosecondOffset: u64,
    byteOffset: u64,
};

pub const AVV_Packet = struct {
    index: u64,
    startNanosecondOffset: u64,
    endNanosecondOffset: u64,
    snapshots: std.ArrayListAligned(AVV_Action, null),

    pub fn close(self: AVV_Packet) void {
        for (self.snapshots.items) |i| {
            i.close();
        }
        self.snapshots.deinit();
    }
};

pub const AVV_Action = struct {
    nanosecondOffset: u32,
    function: functions.AVV_Function,

    pub fn close(self: AVV_Action) void {
        self.function.close();
    }
};

pub const AVV_Object = struct {
    id: u32,
    nanosecondOffset: u32,
    lines: std.ArrayListAligned(AVV_Line, null),
    fillColor: AVV_Color,

    pub fn close(self: AVV_Object) void {
        for (self.lines.items) |i| {
            i.close();
        }
        self.lines.deinit();
    }

    pub fn clone(self: AVV_Object) !AVV_Object {
        var lines = try std.ArrayList(AVV_Line).initCapacity(main.allocator, self.lines.items.len);
        for (0..self.lines.items.len) |i| {
            var positions = try std.ArrayList(AVV_WorldPostion).initCapacity(main.allocator, self.lines.items[i].points.items.len);
            for (0..self.lines.items[i].points.items.len) |x| {
                positions.items[x] = self.lines.items[i].points.items[x];
            }
            lines.items[i] = AVV_Line{
                .startRounded = self.lines.items[i].startRounded,
                .endRounded = self.lines.items[i].endRounded,
                .points = positions,
            };
        }

        return AVV_Object{ .id = self.id, .nanosecondOffset = self.nanosecondOffset, .lines = lines, .fillColor = self.fillColor };
    }
};

pub const AVV_Line = struct {
    startRounded: bool,
    endRounded: bool,
    points: std.ArrayListAligned(AVV_WorldPostion, null),

    pub fn close(self: AVV_Line) void {
        self.points.deinit();
    }
};

pub const AVV_WorldPostion = struct { x: f64, y: f64 };
pub const AVV_Color = struct { r: f32, g: f32, b: f32, a: f32 };

pub const IdOffsetXYArray = struct {
    id: u32,
    offset: []AVV_WorldPostion,

    pub fn close(self: IdOffsetXYArray) void {
        main.allocator.free(self.offset);
    }
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
                packets.?[i].nanosecondOffset = try read(u64, file);
                packets.?[i].byteOffset = try read(u64, file);
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
        if (prev == null or prev.?.startNanosecondOffset > time or prev.?.endNanosecondOffset <= time) {
            var index: u64 = undefined;
            bk: {
                if (self.packets != null) {
                    for (0..self.packets.?.len) |i| {
                        if (self.packets.?[i].nanosecondOffset > time) {
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

            try self.file.seekTo(self.packetsOffset + (if (index == 0) 0 else self.packets.?[index - 1].byteOffset));

            var d = try std.compress.lzma.decompress(
                main.allocator,
                self.file.reader(),
            );
            defer d.deinit();

            var decompressed = d.reader();

            var packets = std.ArrayList(AVV_Action).init(main.allocator);

            var header: [7]u8 = undefined;

            var ids: u32 = 0;
            while (decompressed.read(&header) catch 0 == 7) {
                const function = header[0];
                const timeOffset = byteSwap(u32, header[1..5]);
                const args = byteSwap(u16, header[5..7]);

                const buf = try main.allocator.alloc(u8, args);
                defer main.allocator.free(buf);
                _ = try decompressed.read(buf);

                const funcUnion: functions.AVV_Function = switch (@as(functions.functions, @enumFromInt(function))) {
                    .create => try functions.create.parse(ids, timeOffset, buf),
                    .delete => try functions.delete.parse(buf),
                    .move => try functions.move.parse(buf),
                    .scale => try functions.scale.parse(timeOffset, packets.items, buf),
                    _ => @panic("Unkown function used"),
                };

                if (@as(functions.functions, @enumFromInt(function)) == .create) {
                    ids += 1;
                }

                (try packets.addOne()).* = AVV_Action{
                    .nanosecondOffset = timeOffset,
                    .function = funcUnion,
                };
            }

            current = AVV_Packet{
                .index = index,
                .startNanosecondOffset = if (index == 0) 0 else self.packets.?[index - 1].nanosecondOffset,
                .endNanosecondOffset = if (index == 0 or index == self.packets.?.len) self.videoLength else self.packets.?[index].nanosecondOffset,
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

pub fn getObject(time: u32, items: []AVV_Action, id: u32) !AVV_Object {
    var obj: ?AVV_Object = null;
    errdefer if (obj) |p| p.close();

    for (items) |i| {
        switch (i.function) {
            .create => |c| {
                if (c.object.id == id) {
                    obj = try c.object.clone();
                }
            },
            .delete => |d| if (std.mem.containsAtLeast(u32, d.ids, 1, &[1]u32{id})) return error.itemDoesNotExist,
            .move => |m| m.update(time, @constCast(&[1]AVV_Object{obj.?})),
            .scale => |s| s.update(time, @constCast(&[1]AVV_Object{obj.?})),
        }
    }

    if (obj) |o| {
        return o;
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
