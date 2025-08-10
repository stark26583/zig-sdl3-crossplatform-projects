const std = @import("std");
const sdl3 = @import("Cat");
const FpsManager = sdl3.extras.FramerateCapper(f32);
const assets = @import("assets");
const builtin = @import("builtin");

const zgui = @import("zgui");

pub fn main() !void {
    defer sdl3.shutdown();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    try sdl3.setAppMetadata("Strawkhold", "1.0", "my first official android game for my time pass");
    sdl3.log.setAllPriorities(.info);

    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer {
        log("Quitting ....", .{}) catch {};
        sdl3.quit(init_flags);
    }

    //Init
    try log("Initializing", .{});

    const displays = try sdl3.video.getDisplays();
    defer sdl3.free(displays);

    const monitor_size = try displays[0].getBounds();
    try log("Monitor size: {d}x{d}", .{ monitor_size.w, monitor_size.h });

    const window = try sdl3.video.Window.init(
        "CRMI_SCHEDULER",
        if (builtin.abi.isAndroid()) @intCast(monitor_size.w) else 1280,
        if (builtin.abi.isAndroid()) @intCast(monitor_size.h) else 720,
        .{ .resizable = !builtin.abi.isAndroid() },
    );
    defer window.deinit();

    // var window_safe_area = try window.getSafeArea();

    const renderer = try sdl3.render.Renderer.init(window, null);
    defer renderer.deinit();
    const renderer_name = try renderer.getName();

    var window_safe_area = try window.getSize();
    try log("Window size: {d}x{d}", .{ window_safe_area.width, window_safe_area.height });

    zgui.init(allocator);
    defer zgui.deinit();

    zgui.backend.init(window.value, renderer.value);
    defer zgui.backend.deinit();

    try zgui_style_init(window);

    var fps_manager = FpsManager{ .mode = .{ .limited = 120 } };

    var clear_color: [3]f32 = .{ 0.45, 0.55, 0.60 };
    while (true) {
        var event: sdl3.c.SDL_Event = undefined;
        while (sdl3.c.SDL_PollEvent(&event)) {
            _ = zgui.backend.processEvent(&event);

            const io = zgui.io;
            if (io.getWantCaptureKeyboard() or io.getWantTextInput()) {
                continue;
            }

            switch (sdl3.events.Event.fromSdl(event)) {
                .quit => return,
                .key_down => |key| {
                    if (key.key) |k| {
                        switch (k) {
                            .escape => return,
                            .ac_back => return,
                            else => {},
                        }
                    }
                },
                else => {},
            }
        }

        //Update

        window_safe_area = try window.getSize();
        const width: f32 = @floatFromInt(window_safe_area.width);
        const height: f32 = @floatFromInt(window_safe_area.height);
        const delta = fps_manager.delay();
        //Render

        try renderer.setDrawColorFloat(.{ .r = clear_color[0], .g = clear_color[1], .b = clear_color[2], .a = 1.0 });
        try renderer.clear();

        zgui.backend.newFrame(@intCast(window_safe_area.width), @intCast(window_safe_area.height));
        if (window_safe_area.height > window_safe_area.width) {
            zgui.setNextWindowSize(.{ .cond = .always, .w = width / 2, .h = height / 7 });
            zgui.setNextWindowBgAlpha(.{ .alpha = 0.1 });
            zgui.setNextWindowPos(.{ .cond = .always, .x = width - width / 2, .y = 0 });
        } else {
            zgui.setNextWindowSize(.{ .cond = .always, .w = width / 4, .h = height / 6 });
            zgui.setNextWindowBgAlpha(.{ .alpha = 0.1 });
            zgui.setNextWindowPos(.{ .cond = .always, .x = width - width / 4, .y = 0 });
        }

        if (zgui.begin("Debug", .{ .flags = .{
            .no_resize = true,
            .no_collapse = true,
            .no_title_bar = true,
            .no_scrollbar = true,
            .no_docking = true,
            .no_nav_inputs = true,
        } })) {
            zgui.textUnformattedColored(.{ 0.1, 1, 0.1, 1 }, "Debug");
            zgui.text("Renderer: {s}", .{renderer_name});
            zgui.text("FPS: {d:.4}", .{fps_manager.getObservedFps()});
            zgui.text("Delta: {d:.4} ms", .{delta * 1000});
        }
        zgui.end();

        if (zgui.begin("Settings", .{})) {
            _ = zgui.colorEdit3("Clear Color", .{ .col = &clear_color });
        }
        zgui.end();
        zgui.backend.draw(renderer.value);

        try renderer.present();
    }
}

fn zgui_style_init(window: sdl3.video.Window) !void {
    _ = zgui.io.addFontFromMemory(assets.files.@"Candara.ttf", std.math.floor(19 * try window.getDisplayScale()));
    zgui.io.setIniFilename(null);
    zgui.io.setConfigFlags(.{ .dock_enable = true });
    var style = zgui.getStyle();
    style.window_rounding = 12;
    style.child_rounding = 12;
    style.frame_rounding = 12;
    style.scrollbar_rounding = 12;
    style.grab_rounding = 12;
    style.tab_rounding = 12;
    style.popup_rounding = 12;
}

const log = sdl3.log.log;

/// This needs to be exported for Android builds
export fn SDL_main() callconv(.C) void {
    _ = std.start.callMain();
}
