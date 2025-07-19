// TODO:
const C = @import("c.zig").c;
const std = @import("std");

pub fn init() !void {
    const ret = C.TTF_Init();
    if (!ret) {
        return error.TTFInitFailed;
    }
}

pub fn quit() void {
    C.TTF_Quit();
}

pub fn loadIo(
    source: io_stream.Stream,
    close_when_done: bool,
    size: f32,
) !Font {
    const ret = C.TTF_OpenFontIO(
        source.value,
        close_when_done,
        size,
    );
    if (ret == null) {
        try log.log("TTF_OpenFontIO failed: {s}", .{C.SDL_GetError()});
        return error.SdlError;
    }
    return Font{ .value = ret };
}

pub const Font = struct {
    value: ?*C.TTF_Font,

    pub fn init(file: [:0]const u8, size: f32) !Font {
        const value = C.TTF_OpenFont(file, size);
        if (value == null) {
            try log.log("TTF_OpenFont failed: {s}", .{C.SDL_GetError()});
            return error.SdlError;
        }
        return Font{ .value = value };
    }

    pub fn deinit(self: Font) void {
        C.TTF_CloseFont(self.value);
    }
};

const io_stream = @import("io_stream.zig");
const log = @import("log.zig");
