const common = @import("common.zig");
const sdl3 = @import("Cat");
const std = @import("std");

/// Example structure.
const Example = struct {
    name: []const u8,
    init: *const fn () anyerror!common.Context,
    update: *const fn (ctx: common.Context) anyerror!void,
    draw: *const fn (ctx: common.Context) anyerror!void,
    quit: *const fn (ctx: common.Context) void,
};

/// Automatically create an example structure from an example file.
fn makeExample(example: anytype) Example {
    return .{
        .name = example.example_name,
        .init = &example.init,
        .update = &example.update,
        .draw = &example.draw,
        .quit = &example.quit,
    };
}

/// List of example files.
const examples = [_]Example{
    makeExample(@import("examples/clear_screen.zig")),
    makeExample(@import("examples/clear_screen_multi.zig")),
    makeExample(@import("examples/basic_triangle.zig")),
    makeExample(@import("examples/basic_vertex_buffer.zig")),
};

/// Example index to start with.
const starting_example = 3;

/// Main entry point of our code.
///
/// Note: For most actual projects, you most likely want a callbacks setup.
/// See the template for details.
pub fn main() !void {

    // Setup logging.
    // sdl3.errors.error_callback = &sdlErr;
    sdl3.c.SDL_SetLogPriority(sdl3.c.SDL_LOG_CATEGORY_GPU, sdl3.c.SDL_LOG_PRIORITY_ERROR);
    sdl3.log.setAllPriorities(.info);

    // Setup SDL3.
    defer sdl3.shutdown();
    const init_flags = sdl3.InitFlags{ .video = true };
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    // Setup initial example.
    var example_index: usize = starting_example;
    var ctx = try examples[example_index].init();
    defer examples[example_index].quit(ctx);
    try sdl3.log.log("Loaded \"{s}\" Example", .{examples[example_index].name});

    // Main loop.
    var quit = false;
    var goto_index: ?usize = null;
    var last_time: f32 = 0;
    const can_draw = true;
    while (!quit) {

        // Handle events.
        while (sdl3.events.poll()) |event| {
            switch (event) {
                .quit, .terminating => quit = true,
                else => {},
            }
        }

        // Early quit.
        if (quit)
            break;

        // Switch index.
        if (goto_index) |index| {
            examples[example_index].quit(ctx);
            example_index = index;
            goto_index = null;
            ctx = try examples[index].init();
            try sdl3.log.log("Loaded {s}", .{examples[example_index].name});
        }

        // Delta time calculation.
        const new_time = @as(f32, @floatFromInt(sdl3.timer.getMillisecondsSinceInit())) / 1000;
        const delta_time = new_time - last_time;
        last_time = new_time;
        ctx.delta_time = delta_time;

        // Update and draw current example.
        try examples[example_index].update(ctx);
        if (can_draw)
            try examples[example_index].draw(ctx);
    }
}

export fn SDL_main() callconv(.C) void {
    _ = std.start.callMain();
}
