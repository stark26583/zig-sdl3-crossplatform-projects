const c = @import("c.zig").c;
const events = @import("events.zig");
const sdl3 = @import("sdl3.zig");
const std = @import("std");

/// The prototype for the application's `main()` function
///
/// ## Function Parameters
/// * `args`: Arguments to the main function.
///
/// ## Return Value
/// Returns an ANSI-C main return code; generally `0` is considered successful program completion, and small non-zero values are considered errors.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const MainCallback = *const fn (
    args: [][*:0]u8,
) anyerror!void;

/// An entry point for SDL's use in main callbacks.
///
/// ## Function Parameters
/// * `args`: Application arguments.
/// * `UserData`: Type for user data.
/// * `app_init`: Application initialize function.
/// * `app_iterate`: Application iterate function.
/// * `app_event`: Application event function.
/// * `app_quit`: Application quit function.
///
/// ## Return Value
/// Returns standard Unix main return value.
///
/// ## Remarks
/// Generally, you should not call this function directly.
/// This only exists to hand off work into SDL as soon as possible, where it has a lot more control and functionality available,
/// and make the inline code in `SDL_main.h` as small as possible.
///
/// Not all platforms use this, it's actual use is hidden in a magic header-only library,
/// and you should not call this directly unless you really know what you're doing.
///
/// ## Thread Safety
/// It is not safe to call this anywhere except as the only function call in `SDL_main()`.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn enterAppMainCallbacks(
    args: [:null]?[*:0]u8,
    comptime UserData: type,
    comptime app_init: ?sdl3.AppInitCallback(UserData),
    comptime app_iterate: ?sdl3.AppIterateCallback(UserData),
    comptime app_event: ?sdl3.AppEventCallback(UserData),
    comptime app_quit: ?sdl3.AppQuitCallback(UserData),
) u8 {
    const Cb = struct {
        pub fn init(app_state_c: [*c]?*anyopaque, arg_count_c: c_int, arg_values_c: [*c][*c]u8) callconv(.c) c_uint {
            if (app_init) |cb| {
                const ret = cb(@alignCast(@ptrCast(app_state_c)), @as([*][*:0]u8, @ptrCast(arg_values_c))[0..@intCast(arg_count_c)]) catch |err| {
                    std.log.err("{s}", .{@errorName(err)});
                    if (@errorReturnTrace()) |trace| {
                        std.debug.dumpStackTrace(trace.*);
                    }
                    return c.SDL_APP_FAILURE;
                };
                return @intFromEnum(ret);
            }
            return c.SDL_APP_CONTINUE;
        }
        pub fn iterate(app_state_c: ?*anyopaque) callconv(.c) c_uint {
            if (app_iterate) |cb| {
                const ret = cb(@alignCast(@ptrCast(app_state_c))) catch |err| {
                    std.log.err("{s}", .{@errorName(err)});
                    if (@errorReturnTrace()) |trace| {
                        std.debug.dumpStackTrace(trace.*);
                    }
                    return c.SDL_APP_FAILURE;
                };
                return @intFromEnum(ret);
            }
            return c.SDL_APP_CONTINUE;
        }
        pub fn event(app_state_c: ?*anyopaque, event_c: [*c]c.SDL_Event) callconv(.c) c_uint {
            if (app_event) |cb| {
                const ret = cb(@alignCast(@ptrCast(app_state_c)), events.Event.fromSdl(event_c.*)) catch |err| {
                    std.log.err("{s}", .{@errorName(err)});
                    if (@errorReturnTrace()) |trace| {
                        std.debug.dumpStackTrace(trace.*);
                    }
                    return c.SDL_APP_FAILURE;
                };
                return @intFromEnum(ret);
            }
            return c.SDL_APP_CONTINUE;
        }
        pub fn quit(app_state_c: ?*anyopaque, result_c: c_uint) callconv(.c) void {
            if (app_quit) |cb| {
                cb(@alignCast(@ptrCast(app_state_c)), @enumFromInt(result_c));
            }
        }
    };
    return @intCast(c.SDL_EnterAppMainCallbacks(
        @intCast(args.len),
        @ptrCast(args.ptr),
        Cb.init,
        Cb.iterate,
        Cb.event,
        Cb.quit,
    ));
}

/// Callback from the application to let the suspend continue.
///
/// ## Remarks
/// This function is only needed for Xbox GDK support; all other platforms will do nothing and set an "unsupported" error message.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn gdkSuspendComplete() void {
    c.SDL_GDKSuspendComplete();
}

// I'm pretty sure `SDL_main` makes no sense to include in this subsystem so I will not until reason is given.

// /// Register a win32 window class for SDL's use.
// ///
// /// ## Function Parameters
// /// * `name`: The window class name, in UTF-8 encoding. If `null`, SDL currently uses "SDL_app" but this isn't guaranteed.
// /// * `style`: The value to use in `WNDCLASSEX::style`. If name is `null`, SDL currently uses `CS_BYTEALIGNCLIENT`.
// /// * `hInst`: The `HINSTANCE` to use in `WNDCLASSEX::hInstance`. If zero, SDL will use `GetModuleHandle(NULL)` instead.
// ///
// /// ## Return Value
// /// This can be called to set the application window class at startup.
// /// It is safe to call this multiple times, as long as every call is eventually paired with a call to `main.unregisterApp()`,
// /// but a second registration attempt while a previous registration is still active will be ignored, other than to increment a counter.
// ///
// /// Most applications do not need to, and should not, call this directly; SDL will call it when initializing the video subsystem.
// ///
// /// ## Version
// /// This function is available since SDL 3.2.0.
// So this function (`SDL_RegisterApp`) only exists for windows, don't need to add it?
// The function (`SDL_UnegisterApp`) only exists for windows, don't need to add it?

/// Initializes and launches an SDL application, by doing platform-specific initialization before calling your mainFunction and cleanups after it returns,
/// if that is needed for a specific platform, otherwise it just calls mainFunction.
///
/// ## Function Parameters
/// * `args`: Application arguments.
/// `main_function`: Tour SDL app's C-style `main()`. NOT the function you're calling this from! Its name doesn't matter; it doesn't literally have to be main.
///
/// ## Return Value
/// Returns the return value from mainFunction: `0` on success, otherwise failure; `errors.get()` might have more information on the failure.
///
/// ## Remarks
/// You can use this if you want to use your own `main()` implementation without using `SDL_main` (like when using main handled).
/// When using this, you do not need `main.setMainReady()`.
///
/// ## Thread Safety
/// Generally this is called once, near startup, from the process's initial thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn runApp(
    args: [:null]?[*:0]u8,
    comptime main_function: MainCallback,
) u8 {
    const Cb = struct {
        fn run(arg_count_c: c_int, arg_values_c: [*c][*c]u8) callconv(.c) c_int {
            main_function(@as([*][*:0]u8, @ptrCast(arg_values_c))[0..@intCast(arg_count_c)]) catch |err| {
                std.log.err("{s}", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
                return 1;
            };
            return 0;
        }
    };
    return @intCast(c.SDL_RunApp(
        @intCast(args.len),
        @ptrCast(args.ptr),
        Cb.run,
        null,
    ));
}

/// Circumvent failure of `SDL_Init()` when not using `SDL_main()` as an entry point.
///
/// ## Remarks
/// You probably shouldn't use this.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn setMainReady() void {
    c.SDL_SetMainReady();
}

fn dummyMain(
    args: [][*:0]u8,
) !void {
    try std.testing.expectEqualStrings("Hello", std.mem.span(args[0]));
    try std.testing.expectEqualStrings("World", std.mem.span(args[1]));
}

fn dummyInit(
    app_state: *?*anyopaque,
    args: [][*:0]u8,
) !sdl3.AppResult {
    if (args.len < 2)
        return .failure;
    try std.testing.expectEqualStrings("Hello", std.mem.span(args[0]));
    try std.testing.expectEqualStrings("World", std.mem.span(args[1]));
    app_state.* = @ptrFromInt(5);
    return .run;
}

fn dummyIterate(
    app_state: ?*anyopaque,
) !sdl3.AppResult {
    if (app_state) |val| {
        std.testing.expectEqual(5, @intFromPtr(val)) catch return .failure;
        return .success;
    }
    return .failure;
}

fn dummyEvent(
    app_state: ?*anyopaque,
    event: events.Event,
) !sdl3.AppResult {
    _ = app_state;
    _ = event;
    return .run;
}

fn dummyQuit(
    app_state: ?*anyopaque,
    result: sdl3.AppResult,
) void {
    _ = app_state;
    _ = result;
}

// Test main-related functions.
test "Main" {
    std.testing.refAllDeclsRecursive(@This());
    var args = [_:null]?[*:0]u8{
        @constCast("Hello"),
        @constCast("World"),
    };
    setMainReady();
    try std.testing.expectEqual(0, runApp(
        &args,
        dummyMain,
    ));
    try std.testing.expectEqual(0, enterAppMainCallbacks(
        &args,
        anyopaque,
        dummyInit,
        dummyIterate,
        dummyEvent,
        dummyQuit,
    ));
    gdkSuspendComplete();
}
