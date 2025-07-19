const constants = @import("constants.zig");
const std = @import("std");

/// Defines vertex buffer attributes for all the vertex shaders.
/// This must be kept up to date with each vertex shader, to ensure CPU <-> GPU vertex buffer mappings function properly.
pub const vertex_buffer_attributes = std.StaticStringMap([]const constants.Attribute).initComptime(&.{
    .{
        "position_color.vert",
        &.{
            constants.vert_in_position,
            constants.vert_in_color,
        },
    },
    .{ "raw_triangle.vert", &[_]constants.Attribute{} },
});
