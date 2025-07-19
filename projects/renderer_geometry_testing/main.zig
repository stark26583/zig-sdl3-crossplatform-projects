const sdl3 = @import("Cat");
const std = @import("std");
const FPSManager = sdl3.FpsManager;
const zstbi = sdl3.zstbi;
const builtin = @import("builtin");
const assets = @import("assets");

const allocator = std.heap.c_allocator;

const WINDOW_RESOLUTION = 570;
const android = builtin.abi.isAndroid();
var fwindow_width: f32 = 0;
var fwindow_height: f32 = 0;

const AppState = struct {
    const init_flags = sdl3.InitFlags{ .video = true };
    var radians: f32 = 0;
    var update: bool = true;
    window: sdl3.video.Window,
    renderer: sdl3.render.Renderer,
    fps_manager: FPSManager,
    vertices: [4]sdl3.render.Vertex,
    tex: sdl3.render.Texture,
};

fn init(
    app_state: *?*AppState,
    args: [][*:0]u8,
) !sdl3.AppResult {
    sdl3.log.setAllPriorities(.info);
    var window_dimensions: struct { width: u32, height: u32 } = undefined;

    try sdl3.init(AppState.init_flags);
    zstbi.init(allocator);

    const displays = try sdl3.video.getDisplays();
    defer sdl3.free(displays);

    const monitor_size = try displays[0].getBounds();

    if (!android) {
        fwindow_width = @floatFromInt(monitor_size.w);
        fwindow_height = @floatFromInt(monitor_size.h);
        const monitor_resolution = fwindow_width / fwindow_height;
        try sdl3.log.log("Monitor resolution: {d}", .{monitor_resolution});

        fwindow_width = WINDOW_RESOLUTION * monitor_resolution;
        fwindow_height = WINDOW_RESOLUTION;
        window_dimensions.width = @intFromFloat(fwindow_width);
        window_dimensions.height = @intFromFloat(fwindow_height);
    } else {
        window_dimensions.width = @intCast(monitor_size.w);
        window_dimensions.height = @intCast(monitor_size.h);
    }

    try sdl3.log.log("Window size: {d}x{d}", .{ window_dimensions.width, window_dimensions.height });

    fwindow_width = @floatFromInt(window_dimensions.width);
    fwindow_height = @floatFromInt(window_dimensions.height);

    const window = try sdl3.video.Window.init(
        std.mem.span(args[0]),
        window_dimensions.width,
        window_dimensions.height,
        .{
            .resizable = !android,
            .fullscreen = android,
        },
    );
    errdefer window.deinit();

    const renderer = try sdl3.render.Renderer.init(window, null);
    errdefer renderer.deinit();

    var image = try zstbi.Image.loadFromMemory(assets.@"animal.jpg", 4);
    defer image.deinit();

    const texture = try sdl3.render.Texture.init(renderer, .array_rgba_32, .static, image.width, image.height);
    errdefer texture.deinit();

    try texture.update(null, @ptrCast(image.data), image.width * 4);

    const state = try allocator.create(AppState);
    state.* = .{
        .window = window,
        .renderer = renderer,
        .fps_manager = FPSManager.init(.{ .manual = 120 }),
        .tex = texture,
        .vertices = std.mem.zeroes(@FieldType(AppState, "vertices")),
    };
    app_state.* = state;
    return .run;
}

fn iterate(
    app_state: ?*AppState,
) !sdl3.AppResult {
    const state = app_state orelse return .failure;
    const size = try state.window.getSize();
    fwindow_width = @floatFromInt(size.width);
    fwindow_height = @floatFromInt(size.height);

    const color1 = sdl3.pixels.FColor{
        .r = 1.0,
        .g = @sin(AppState.radians) / 2 + 0.5,
        .b = @sin(AppState.radians) / 2 + 0.5,
        .a = 1.0,
    };
    const color2 = sdl3.pixels.FColor{
        .r = 1.0,
        .g = @cos(AppState.radians) / 2 + 0.5,
        .b = @cos(AppState.radians) / 2 + 0.5,
        .a = 1.0,
    };

    state.fps_manager.tick();
    if (AppState.update) AppState.radians += 6 * state.fps_manager.getDelta();
    // if (AppState.radians > std.math.pi) AppState.radians = 0;

    // top left
    state.vertices[0].position.x = fwindow_width / 7;
    state.vertices[0].position.y = fwindow_height / 7;
    state.vertices[0].color = color2;
    state.vertices[0].tex_coord.x = 0;
    state.vertices[0].tex_coord.y = 0;

    // bottom left
    state.vertices[1].position.x = fwindow_width / 7;
    state.vertices[1].position.y = fwindow_height * 6 / 7;
    state.vertices[1].color = color2;
    state.vertices[1].tex_coord.x = 0;
    state.vertices[1].tex_coord.y = 1;

    // bottom right
    state.vertices[2].position.x = fwindow_width * 6 / 7;
    state.vertices[2].position.y = fwindow_height * 6 / 7;
    state.vertices[2].color = color1;
    state.vertices[2].tex_coord.x = 1;
    state.vertices[2].tex_coord.y = 1;

    // top right
    state.vertices[3].position.x = fwindow_width * 6 / 7;
    state.vertices[3].position.y = fwindow_height / 7;
    state.vertices[3].color = color1;
    state.vertices[3].tex_coord.x = 1;
    state.vertices[3].tex_coord.y = 0;

    try state.renderer.setDrawColor(.{ .r = 0, .g = 0, .b = 0, .a = 255 });
    try state.renderer.clear();

    try state.renderer.setDrawBlendMode(sdl3.blend_mode.Mode.blend);
    try state.renderer.setDrawColor(.{ .r = 0, .g = 255, .b = 255, .a = 255 });

    try state.renderer.renderGeometry(state.tex, state.vertices[0..], &.{ 0, 1, 2, 2, 0, 3 });

    try state.renderer.setScale(1.5, 2.5);
    try state.renderer.renderDebugTextFormat(
        .{ .x = 12, .y = if (android) 62 else 12 },
        "FPS: {d}, delta: {d}",
        .{ state.fps_manager.getFps(), state.fps_manager.getDelta() },
    );
    try state.renderer.setScale(1, 1);

    try state.renderer.present();

    return .run;
}

fn event(
    app_state: ?*AppState,
    curr_event: sdl3.events.Event,
) !sdl3.AppResult {
    const state = app_state orelse return .failure;

    return switch (curr_event) {
        .quit => .success,
        .terminating => .success,
        .key_down => |key| {
            if (key.key) |k| {
                if (k == .space) {
                    AppState.update = !AppState.update;
                }
            }
            return .run;
        },
        .mouse_button_down => |button| {
            if (button.button == .left) {
                const thread = try std.Thread.spawn(.{}, save_render_png_seperate_thread, .{state});
                thread.join();
            }
            return .run;
        },
        else => .run,
    };
}

fn quit(
    app_state: ?*AppState,
    result: sdl3.AppResult,
) void {
    _ = result;
    if (app_state) |state| {
        state.renderer.deinit();
        state.window.deinit();
        allocator.destroy(state);
    }
    zstbi.deinit();
    sdl3.quit(AppState.init_flags);
    sdl3.shutdown();
}

fn save_render_png_seperate_thread(state: *AppState) void {
    const pixels = state.renderer.readPixels(null) catch {
        sdl3.log.log("Failed to read pixels", .{}) catch unreachable;
        return;
    };
    defer pixels.deinit();
    const pixels_formatted = pixels.convertFormat(.array_rgba_32) catch {
        sdl3.log.log("Failed to convert pixels", .{}) catch unreachable;
        return;
    };
    defer pixels_formatted.deinit();

    var saved_image = zstbi.Image.createEmpty(@intCast(pixels_formatted.getWidth()), @intCast(pixels_formatted.getHeight()), 4, .{
        .bytes_per_component = 1,
        .bytes_per_row = 4 * @as(u32, @intCast(pixels_formatted.getWidth())),
    }) catch {
        sdl3.log.log("Failed to create image", .{}) catch unreachable;
        return;
    };
    defer saved_image.deinit();

    @memcpy(saved_image.data, pixels_formatted.getPixels() orelse unreachable);

    saved_image.writeToFile("Mass_tree_rendered.png", .png) catch {
        sdl3.log.log("Failed to write image", .{}) catch unreachable;
        return;
    };
}

/// Entry point Boilerplate
pub fn main() u8 {
    sdl3.main_funcs.setMainReady();
    var args = [_:null]?[*:0]u8{
        @constCast("Hello SDL3"),
    };
    return sdl3.main_funcs.enterAppMainCallbacks(&args, AppState, init, iterate, event, quit);
}

export fn SDL_main() callconv(.C) void {
    _ = std.start.callMain();
}
