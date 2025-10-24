const std = @import("std");
const parse = @import("parse.zig");

const SDL = @import("sdl2");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub fn main() !void {
    const parsed = try parse.AVV_File.open(@constCast("./samples/love.v0.avv"));

    var x: i32 = 500;
    var y: i32 = 500;
    if (parsed.xInTermsOfY) x = @intFromFloat(parsed.aspectRatio * @as(f64, @floatFromInt(y))) else y = @intFromFloat(parsed.aspectRatio * @as(f64, @floatFromInt(x)));

    if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO) < 0)
        sdlPanic();
    defer SDL.SDL_Quit();

    const window = SDL.SDL_CreateWindow(
        "AVV Video",
        SDL.SDL_WINDOWPOS_CENTERED,
        SDL.SDL_WINDOWPOS_CENTERED,
        x,
        y,
        SDL.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer _ = SDL.SDL_DestroyWindow(window);

    const renderer = SDL.SDL_CreateRenderer(window, -1, SDL.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
    defer _ = SDL.SDL_DestroyRenderer(renderer);

    var start: ?i128 = null;

    var state: ?parse.AVV_Packet = null;
    defer if (state) |s| s.close();

    var last: ?i128 = null;
    mainLoop: while (true) {
        var ev: SDL.SDL_Event = undefined;
        while (SDL.SDL_PollEvent(&ev) != 0) {
            if (ev.type == SDL.SDL_QUIT)
                break :mainLoop;
        }

        if (start == null) start = std.time.nanoTimestamp();

        const current = std.time.nanoTimestamp();
        while (current - start.? > parsed.videoLength) {
            if (!parsed.loop) break;
            start.? += parsed.videoLength;
        }

        _ = SDL.SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0x00);
        _ = SDL.SDL_RenderClear(renderer);

        const frame = try parsed.get(@intCast(current - start.?), &state);

        if (last) |l| {
            std.debug.print("{any} fps\n", .{@divTrunc(1000000000,current - l)});
        }

        for (frame) |o| {
            _ = SDL.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF);

            var points = try allocator.alloc(SDL.SDL_Point, o.lines.items.len * 99);
            defer allocator.free(points);

            var i: usize = 0;
            for (o.lines.items) |l| {
                var prev = try deCasteljau(l.points.items, l.points.items.len, 0.0);

                var t: f64 = 0.01;
                while (t <= 1.0) {
                    const _current = try deCasteljau(l.points.items, l.points.items.len, t);

                    points[i] = .{.x=@as(i32,@intFromFloat((_current.x + 1) / 2 * @as(f64, @floatFromInt(x)))), .y=@as(i32, @intFromFloat((_current.y + 1) / 2 * @as(f64, @floatFromInt(y))))};
                    i += 1;

                    prev = _current;
                    t += 0.01;
                }
            }

            _ = SDL.SDL_SetRenderDrawColor(renderer, 0xFF, 0x00, 0x00, 0xFF);
            try fillPolygon(renderer, points);

            _ = SDL.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF);
            var prev: ?SDL.SDL_Point = null;
            for (points) |p| {
                if (prev) |pp| {
                    _ = SDL.SDL_RenderDrawLine(renderer, pp.x, pp.y, p.x, p.y);
                }
                prev = p;
            }

        }

        SDL.SDL_RenderPresent(renderer);

        last = current;
    }
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}

fn deCasteljau(points: []parse.AVV_WorldPosition, numPoints: u64, t: f64) !parse.AVV_WorldPosition {
    if (numPoints == 1)
        return points[0];

    var newPoints = try allocator.alloc(parse.AVV_WorldPosition, numPoints - 1);
    defer allocator.free(newPoints);

    for (0..numPoints - 1) |i| {
        newPoints[i].x = (1 - t) * points[i].x + t * points[i + 1].x;
        newPoints[i].y = (1 - t) * points[i].y + t * points[i + 1].y;
    }

    return deCasteljau(newPoints, numPoints - 1, t);
}

fn fillPolygon(renderer: ?*SDL.SDL_Renderer, points: []const SDL.SDL_Point) !void {
    if (points.len < 3) return;

    var min_y = points[0].y;
    var max_y = points[0].y;
    for (points) |p| {
        min_y = @min(min_y, p.y);
        max_y = @max(max_y, p.y);
    }

    var y = min_y;
    while (y <= max_y) : (y += 1) {
        var intersections = std.ArrayList(i32).init(allocator);
        defer intersections.deinit();

        var i: usize = 0;
        while (i < points.len) : (i += 1) {
            const j = if (i == 0) points.len-1 else i-1;
            const p1 = points[i];
            const p2 = points[j];

            if (p1.y == p2.y) continue;

            if ((p1.y > y and p2.y <= y) or (p2.y > y and p1.y <= y)) {
                const slope = @as(f32,@floatFromInt(p2.x - p1.x)) / @as(f32,@floatFromInt(p2.y - p1.y));
                const x_float = @as(f32,@floatFromInt(p1.x)) + slope * @as(f32,@floatFromInt(y - p1.y));

                const x = @as(i32,@intFromFloat(@round(x_float)));
                try intersections.append(x);
            }
        }

        std.sort.insertion(i32, intersections.items, {}, comptime std.sort.asc(i32));

        if (intersections.items.len >= 2) {
            var k: usize = 0;
            while (k + 1 < intersections.items.len) : (k += 2) {
                _ = SDL.SDL_RenderDrawLine(
                    renderer,
                    intersections.items[k],
                    y,
                    intersections.items[k+1],
                    y
                );
            }
        }
    }
}

