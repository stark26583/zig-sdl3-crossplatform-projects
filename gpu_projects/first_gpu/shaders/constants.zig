const std = @import("std");

/// Stage of data for the attribute parameter.
pub const AttributeStage = enum {
    /// Input for the vertex stage. Provided by a vertex buffer.
    vert_input,
    /// Output of the vertex stage but an input for the fragment stage.
    vert_output_frag_input,
    /// Output of the fragment stage.
    frag_output,
};

/// GPU attribute structure.
pub const Attribute = struct {
    /// Attribute location.
    /// This has to be unique among attributes for each stage type, but does not have to be unique across different stage types.
    loc: u32,
    /// Data type.
    typ: type,
    /// If to normalize as bytes on the CPU side.
    byte_normalize: bool = false,
    /// Stage the uniform exists.
    stage: AttributeStage,

    /// Get the type for the CPU side.
    pub inline fn cpuType(comptime self: Attribute) type {
        if (self.byte_normalize) {
            return @Type(.{ .vector = .{
                .child = u8,
                .len = @typeInfo(self.typ).vector.len,
            } });
        }
        return self.typ;
    }
};

// The GPU has multiple "locations" that can be used for inputs and outputs for either the vertex or fragment stage.
// For example, we may have a vertex shader that takes in a position and color and will output a color to later be consumed by the fragment shader.
// Note that the position element for a vertex shader must be output as it is hardcoded to its pipeline.
// In the example above, we would use the `vert_in_position`, `vert_in_color`, and `vert_out_frag_in_color` attributes.
// We use these in `position_color.vert.zig`.
// Unfortunately, using the attributes in the shader code is a bit messy and hard to communicate.
// Below is a listing of the different possible attributes being used throughout the shaders.

/// Attribute to use for input vertex position.
pub const vert_in_position = Attribute{
    .loc = 0,
    .typ = @Vector(3, f32),
    .stage = .vert_input,
};

/// Attribute to use for input vertex color.
pub const vert_in_color = Attribute{
    .loc = 1,
    .typ = @Vector(4, f32),
    .byte_normalize = true,
    .stage = .vert_input,
};

/// Output type for vertex position.
/// This is a hardcoded output for the vertex stage.
pub const vert_out_position_type = @Vector(4, f32);

/// Attribute to use for vertex color outputs.
pub const vert_out_frag_in_color = Attribute{
    .loc = 0,
    .typ = @Vector(4, f32),
    .stage = .vert_output_frag_input,
};

// Note that vertex output locations and fragment output locations are allowed to overlap because they are different address spaces.
// Any vertex output location works as a fragment input location.

/// The fragment output color location should just be 0.
/// I don't know why, it's just expected to be at 0.
pub const frag_out_color = Attribute{
    .loc = 0,
    .typ = @Vector(4, f32),
    .stage = .frag_output,
};
