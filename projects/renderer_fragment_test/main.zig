const sdl3 = @import("Cat");
const std = @import("std");
const FPSManager = sdl3.extras.FramerateCapper(f64);
const builtin = @import("builtin");
const assets = @import("assets");

const allocator = std.heap.c_allocator;

const WINDOW_RESOLUTION = 570;
const android = builtin.abi.isAndroid();
var fwindow_width: f32 = 0;
var fwindow_height: f32 = 0;

const AppState = struct {
    const init_flags = sdl3.InitFlags{ .video = true };
    window: sdl3.video.Window,
    renderer: sdl3.render.Renderer,
    fps_manager: FPSManager,
};

fn init(
    app_state: *?*AppState,
    args: [][*:0]u8,
) !sdl3.AppResult {
    sdl3.log.setAllPriorities(.info);
    var window_dimensions: struct { width: u32, height: u32 } = undefined;

    try sdl3.init(AppState.init_flags);

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

    const state = try allocator.create(AppState);
    state.* = .{
        .window = window,
        .renderer = renderer,
        .fps_manager = .{ .mode = .{ .limited = 120 } },
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

    const delta_time = state.fps_manager.delay();

    try state.renderer.setDrawColor(.{ .r = 45, .g = 45, .b = 45, .a = 255 });
    try state.renderer.clear();

    try state.renderer.setDrawColor(.{ .r = 255, .g = 255, .b = 255, .a = 255 });

    try state.renderer.setScale(1.5, 2.5);
    try state.renderer.renderDebugTextFormat(
        .{ .x = 12, .y = if (android) 62 else 12 },
        "FPS: {d}, delta: {d}",
        .{ state.fps_manager.getObservedFps(), delta_time },
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
    _ = state;

    return switch (curr_event) {
        .quit => .success,
        .terminating => .success,
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
    sdl3.quit(AppState.init_flags);
    sdl3.shutdown();
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
