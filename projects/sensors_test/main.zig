const std = @import("std");
const sdl3 = @import("Cat");
const FPSManager = sdl3.FpsManager;
const builtin = @import("builtin");
const c = sdl3.c;
const sensor = sdl3.sensor;

const WINDOW_WIDTH = if (builtin.abi.isAndroid()) 2412 else 1000;
const WINDOW_HEIGHT = if (builtin.abi.isAndroid()) 1080 else 600;

pub fn main() !void {
    defer sdl3.init.shutdown();

    var gpa = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer gpa.deinit();

    const allocator = gpa.allocator();

    try sdl3.init.setAppMetadata("sensors_test", "1.0", "sensors_test_very_good");
    sdl3.log.setAllPriorities(.info);

    const init_flags = sdl3.init.Flags{ .video = true, .sensor = true };
    try sdl3.init.init(init_flags);
    defer sdl3.init.quit(init_flags);

    //Init
    try log("Initializing", .{});
    const size = 100;
    // const velx: f32 = 550.0;
    // const vely: f32 = 550.0;
    var rect_x: f32 = (WINDOW_WIDTH - size) / 2;
    var rect_y: f32 = WINDOW_HEIGHT - size;

    const SensorWithData = struct {
        data: [3]f32,
        s: sensor.Sensor,
    };

    var sensor_update = false;

    // var accelerometer: ?SensorWithData = null;
    // var gyroscope: ?SensorWithData = null;
    // var gravity: ?SensorWithData = null;
    // var step_detect: ?sensor.Sensor = null;
    var all_sensors = std.ArrayList(SensorWithData).init(allocator);

    defer {
        // if (accelerometer) |accelerometer_| accelerometer_.s.deinit();
        // if (gyroscope) |gyroscope_| gyroscope_.s.deinit();
        // if (gravity) |gravity_| gravity_.s.deinit();
        for (all_sensors.items) |s| {
            s.s.deinit();
        }
        all_sensors.deinit();
    }

    const sensor_ids = try sensor.getSensors();
    try log("Sensors: {d}", .{sensor_ids.len});
    for (sensor_ids) |id| {
        // const sensor_type = id.getType().?;
        // switch (sensor_type) {
        //     // .accelerometer => accelerometer = SensorWithData{
        //     //     .s = try sensor.Sensor.init(id),
        //     //     .data = std.mem.zeroes([3]f32),
        //     // },
        //     // .gyroscope => gyroscope = SensorWithData{
        //     //     .s = try sensor.Sensor.init(id),
        //     //     .data = std.mem.zeroes([3]f32),
        //     // },
        //     else => {
        // const name = id.getName() orelse "null";
        // try log("({d}) (Name:{s}) (Type: {s})", .{ id.value, name, @tagName(sensor_type) });
        // if (std.mem.containsAtLeast(u8, name, 1, "gravity")) {
        //     gravity = SensorWithData{
        //         .s = try sensor.Sensor.init(id),
        //         .data = std.mem.zeroes([3]f32),
        //     };
        // }
        // if (std.mem.containsAtLeast(u8, name, 1, "gyro")) {
        //     gyroscope = SensorWithData{
        //         .s = try sensor.Sensor.init(id),
        //         .data = std.mem.zeroes([3]f32),
        //     };
        // }
        // if (std.mem.containsAtLeast(u8, name, 1, "pedo") or std.mem.containsAtLeast(u8, name, 1, "DETECT") or std.mem.containsAtLeast(u8, name, 1, "step")) {
        //     step_detect = try sensor.Sensor.init(id);
        // }
        try all_sensors.append(.{
            .data = undefined,
            .s = try sensor.Sensor.init(id),
        });
        // },
        // }
    }
    // if (accelerometer) |accelerometer_| try log("Accelerometer: {s}", .{try accelerometer_.s.getName()});
    // if (gyroscope) |gyroscope_| try log("Gyroscope: {s}", .{try gyroscope_.s.getName()});
    // if (gravity) |gravity_| try log("Gravity: {s}", .{try gravity_.s.getName()});
    // if(step_detect) |step_detect_| try log("Step Detect: {s}", .{try step_detect_.getName()});

    const window = try sdl3.video.Window.init(
        "Sensors",
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        .{ .fullscreen = builtin.abi.isAndroid() },
    );
    defer window.deinit();

    const renderer = try sdl3.render.Renderer.init(window, null);
    defer renderer.deinit();

    var fps_manager = FPSManager.init(.auto);

    var mouse_button_down = false;
    var mouse_button: u8 = 0;
    while (true) {
        while (sdl3.events.poll()) |event| {
            switch (event) {
                .quit => return,
                .unknown => |unknown| {
                    if (unknown.event_type == c.SDL_EVENT_FINGER_DOWN) {
                        try log("Finger down from zig\n", .{});
                    }
                    if (unknown.event_type == c.SDL_EVENT_MOUSE_BUTTON_DOWN) {
                        const mouse_event = event.toSdl().button;
                        mouse_button_down = true;
                        mouse_button = mouse_event.button;

                        try log("Finger down from zig\n", .{});
                    }
                    if (unknown.event_type == c.SDL_EVENT_SENSOR_UPDATE) {
                        sensor_update = true;
                    } else {
                        sensor_update = false;
                    }
                },
                else => {},
            }
        }

        // Update
        // velx *= accelerometer.data[1];
        // vely *= accelerometer.data[0];

        // if (accelerometer) |accelerometer_| rect_x += velx * fps_manager.getDelta() * accelerometer_.data[1];
        // if (accelerometer) |accelerometer_| rect_y += vely * fps_manager.getDelta() * accelerometer_.data[0];

        if (rect_x < 0) rect_x = 0;
        if (rect_x > WINDOW_WIDTH - size) rect_x = WINDOW_WIDTH - size;
        if (rect_y < 0) rect_y = 0;
        if (rect_y > WINDOW_HEIGHT - size) rect_y = WINDOW_HEIGHT - size;

        fps_manager.tick();

        // if (sensor_update) {
        //     if (accelerometer) |_| try accelerometer.?.s.getData(f32, &accelerometer.?.data);
        //     if (gyroscope) |_| try gyroscope.?.s.getData(f32, &gyroscope.?.data);
        //     if (gravity) |_| try gravity.?.s.getData(f32, &gravity.?.data);
        //     for (all_sensors.items) |*s| {
        //         try s.s.getData(&s.data);
        //     }
        // }

        try renderer.setDrawColor(.{ .r = 0, .g = 60, .b = 30, .a = 255 });
        try renderer.clear();

        try renderer.setDrawColor(.{ .r = 255, .g = 255, .b = 0, .a = 255 });
        try renderer.setScale(2, 3);
        // if (accelerometer) |accelerometer_| try renderer.renderText("Accelerometer {s}: (x: {d:.3}, y: {d:.3}, z: {d:.3})", .{
        //     try accelerometer_.s.getName(),
        //     accelerometer_.data[0],
        //     accelerometer_.data[1],
        //     accelerometer_.data[2],
        // }, 12, 24);
        // if (gyroscope) |gyroscope_| try renderer.renderText("Gyroscope {s}: (x: {d:.3}, y: {d:.3}, z: {d:.3})", .{
        //     try gyroscope_.s.getName(),
        //     std.math.radiansToDegrees(gyroscope_.data[0]),
        //     std.math.radiansToDegrees(gyroscope_.data[1]),
        //     std.math.radiansToDegrees(gyroscope_.data[2]),
        // }, 12, 36);
        // if (gravity) |gravity_| try renderer.renderText("Gravity {s}: (x: {d:.3}, y: {d:.3}, z: {d:.3})", .{
        //     try gravity_.s.getName(),
        //     gravity_.data[0],
        //     gravity_.data[1],
        //     gravity_.data[2],
        // }, 12, 48);

        // for (all_sensors.items, 0..) |*s, i| {
        //     try renderer.renderText("Other {s}: (x: {d:.3}, y: {d:.3}, z: {d:.3})", .{
        //         try s.s.getName(),
        //         s.data[0],
        //         s.data[1],
        //         s.data[2],
        //     }, 12, 48 + 12 * @as(f32, @floatFromInt(i + 1)));
        // }

        try renderer.setScale(1, 1);

        try renderer.setDrawColor(.{ .r = 255, .g = 255, .b = 255, .a = 255 });
        // if (gyroscope) |gyroscope_| try renderer.renderFillRect(.{ .x = WINDOW_WIDTH - 154, .y = WINDOW_HEIGHT / 2, .w = 50, .h = (gyroscope_.data[0] / (std.math.pi)) * (WINDOW_HEIGHT) });
        // if (gyroscope) |gyroscope_| try renderer.renderFillRect(.{ .x = WINDOW_WIDTH - 102, .y = WINDOW_HEIGHT / 2, .w = 50, .h = (gyroscope_.data[1] / (std.math.pi)) * (WINDOW_HEIGHT) });
        // if (gyroscope) |gyroscope_| try renderer.renderFillRect(.{ .x = WINDOW_WIDTH - 51, .y = WINDOW_HEIGHT / 2, .w = 50, .h = (gyroscope_.data[2] / (std.math.pi)) * (WINDOW_HEIGHT) });
        //
        try renderer.setDrawColor(.{ .r = 255, .g = 0, .b = 0, .a = 255 });
        try renderer.renderFillRect(.{ .x = rect_x, .y = rect_y, .w = size, .h = size });

        try draw_fps(renderer, allocator, fps_manager);
        try renderer.present();
    }
}

fn draw_fps(renderer: sdl3.render.Renderer, allocator: std.mem.Allocator, fps_manager: FPSManager) !void {
    try renderer.setDrawColor(.{ .r = 255, .g = 255, .b = 0, .a = 255 });
    try renderer.setScale(2, 3);
    const text = try std.fmt.allocPrintZ(allocator, "FPS: {d}, Delta: {d}\n", .{ fps_manager.getFps(), fps_manager.getDelta() });
    defer allocator.free(text);
    if (!c.SDL_RenderDebugText(renderer.value, 12, 12, text)) {
        try log("SDL_RenderDebugText failed: {s}", .{c.SDL_GetError()});
    }
    try renderer.setScale(1, 1);
}

const log = sdl3.log.log;

/// This needs to be exported for Android builds
export fn SDL_main() callconv(.C) void {
    _ = std.start.callMain();
}
