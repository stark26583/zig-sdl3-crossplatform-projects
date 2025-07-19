const std = @import("std");
const sdl3 = @import("Cat");
const zstbi = sdl3.zstbi;
const Image = zstbi.Image;
const SDL_Image = sdl3.image;

const rel_path = "projects/apk_icon_generator";

const width = 96;
const height = 96;

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    zstbi.init(allocator);
    defer zstbi.deinit();

    const init_flags = sdl3.init.Flags{ .video = true };
    try sdl3.init.init(init_flags);
    defer sdl3.init.quit(init_flags);

    var rng = std.Random.Xoroshiro128.init(@intCast(std.time.timestamp()));
    const random = rng.random();

    var svg_files = std.ArrayList(std.fs.File).init(allocator);
    defer {
        for (0..svg_files.items.len) |i| svg_files.items[i].close();
        svg_files.deinit();
    }

    const real_path = try std.fs.cwd().realpathAlloc(allocator, rel_path);
    defer allocator.free(real_path);

    var cwd = try std.fs.openDirAbsolute(real_path, .{ .iterate = true });
    defer cwd.close();

    var cwd_iter = cwd.iterate();
    while (try cwd_iter.next()) |entry| {
        if (entry.kind == .file) {
            if (std.mem.endsWith(u8, entry.name, ".svg")) try svg_files.append(try cwd.openFile(entry.name, .{}));
        }
    }

    const wr = try sdl3.render.Renderer.initWithWindow("APK_ICON", width, height, .{});
    defer wr.window.deinit();
    const renderer = wr.renderer;
    defer renderer.deinit();
    defer {
        renderer.present() catch {};
        sdl3.timer.delayMilliseconds(1500);
    }

    const random_svg_file = svg_files.items[random.uintLessThan(usize, svg_files.items.len)];
    const random_svg_file_content = try random_svg_file.readToEndAlloc(allocator, 4096);
    defer allocator.free(random_svg_file_content);

    const random_svg_image_tex = try SDL_Image.loadTextureIo(
        renderer,
        try sdl3.io_stream.Stream.initFromConstMem(random_svg_file_content),
        true,
    );
    defer random_svg_image_tex.deinit();

    //Make our Changes to the renderer
    {
        try renderer.setDrawColor(.{ .r = 255, .g = 255, .b = 255, .a = 255 });
        try renderer.clear();
        // try renderer.setDrawBlendMode(sdl3.blend_mode.Mode.mul);
        try renderer.renderTexture(
            random_svg_image_tex,
            null, // .{ .x = 0, .y = 0, .w = 100, .h = 100 },
            .{ .x = 0, .y = 0, .w = width, .h = height },
        );

        const tmp_surf = try renderer.readPixels(null);
        defer tmp_surf.deinit();

        var r = @as(u8, 255);
        var g = @as(u8, 255);
        var b = @as(u8, random.intRangeAtMost(u8, 1, 255));
        for (0..width) |x| {
            for (0..height) |y| {
                r -%= random.intRangeAtMost(u8, 1, 3);
                b -%= random.intRangeAtMost(u8, 1, 255);
                const pixel = try tmp_surf.readPixel(@intCast(x), @intCast(y));
                if (pixel.r < 30 and pixel.g < 30 and pixel.b < 30) {
                    try renderer.setDrawColor(.{ .r = r, .g = g, .b = b, .a = 255 });
                    try renderer.renderPoint(.{ .x = @floatFromInt(x), .y = @floatFromInt(y) });
                }
            }
            r -%= random.uintLessThan(u8, random.intRangeAtMost(u8, 1, 20));
            g -%= random.uintLessThan(u8, random.intRangeAtMost(u8, 1, 40));
            b -%= random.uintLessThan(u8, random.intRangeAtMost(u8, 1, 30));
        }
        for (0..width) |x| {
            for (0..height) |y| {
                const pixel = try tmp_surf.readPixel(@intCast(x), @intCast(y));
                if (pixel.r > 250 and pixel.g > 250 and pixel.b > 250) {
                    try renderer.setDrawColor(.{ .r = 0, .g = 0, .b = 0, .a = 0 });
                }
            }
        }
    }

    const updated_surf = try renderer.readPixels(null);
    defer updated_surf.deinit();

    for (0..width) |x| {
        for (0..height) |y| {
            const pixel = try updated_surf.readPixel(@intCast(x), @intCast(y));
            if (pixel.r > 200 and pixel.g > 200 and pixel.b > 200 and pixel.a > 200) {
                try updated_surf.writePixel(@intCast(x), @intCast(y), .{ .r = 0, .g = 0, .b = 0, .a = 0 });
            }
        }
    }

    const updated_img_surf = try updated_surf.convertFormat(sdl3.pixels.Format.array_rgba_32);
    defer updated_surf.deinit();

    var updated_image = try Image.createEmpty(width, height, 4, .{});
    defer updated_image.deinit();

    const updated_img_surf_data = updated_img_surf.getPixels().?;
    std.debug.assert(updated_img_surf_data.len == updated_image.data.len);

    @memcpy(updated_image.data, updated_img_surf_data);

    // const file_name = try std.fmt.allocPrint(allocator, "icon_{d}.", .{});
    // defer allocator.free(file_name);

    try updated_image.writeToFile("icon.png", .png);
}
