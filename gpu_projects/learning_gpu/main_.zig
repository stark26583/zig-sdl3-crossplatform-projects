const std = @import("std");
const sdl3 = @import("Cat");
const gpu = sdl3.gpu;

const zgltf = sdl3.zgltf;
const zstbi = sdl3.zstbi;
const model_glb = @embedFile("assets/models/wraith.glb");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        std.debug.assert(leaked == .ok);
    }
    const allocator = gpa.allocator();

    var gltf = zgltf.init(allocator);
    defer gltf.deinit();
    zstbi.init(allocator);
    defer zstbi.deinit();

    const raw: []const u8 = model_glb;
    const size = raw.len;

    // 2) Allocate an aligned buffer for parsing
    //    allocAligned(T, count, alignment)
    var aligned_buf = try allocator.alignedAlloc(u8, 4, size);
    defer allocator.free(aligned_buf);

    // 3) Copy the embedded data into the aligned buffer
    @memcpy(aligned_buf[0..size], raw[0..size]);

    // 4) Cast it to the parser’s expected slice type
    const glb_buffer: []align(4) const u8 = aligned_buf[0..size];

    try gltf.parse(glb_buffer);

    std.log.info("Mesh count: {d}", .{gltf.data.meshes.items.len});
    if (gltf.data.meshes.items.len == 0) std.log.info("No mesh found in this model", .{});
    for (gltf.data.meshes.items) |mesh| {
        std.log.info("Mesh: {s}", .{mesh.name orelse "No mesh found in this model"});
    }

    // Grab mesh 0

    const mesh = gltf.data.meshes.items[0];
    const primitives = mesh.primitives.items.len;

    std.log.info("Primitive count: {d}", .{primitives});

    for (mesh.primitives.items) |primitive| {
        // const ind_accessor = gltf.data.accessors.items[primitive.indices.?];
        // var ind_it = ind_accessor.iterator(u32, &gltf, gltf.glb_binary.?);
        // std.log.info("Indices:------------", .{});
        // while (ind_it.next()) |i| {
        //     std.log.info("{d}", .{i[0]});
        // }
        // std.log.info("Indices:------------", .{});

        for (primitive.attributes.items) |attribute| {
            switch (attribute) {
                // .position => |idx| {
                // const accessor = gltf.data.accessors.items[idx];
                // var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                // std.log.info("positions:------------", .{});
                // while (it.next()) |v| {
                //     std.log.info("{d} {d} {d}", .{ v[0], v[1], v[2] });
                // }
                // std.log.info("positions:------------", .{});
                // },
                // .normal => |idx| {
                //     const accessor = gltf.data.accessors.items[idx];
                //     var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                //     std.log.info("normals:------------", .{});
                //     while (it.next()) |n| {
                //         std.log.info("{d} {d} {d}", .{ n[0], n[1], n[2] });
                //     }
                //     std.log.info("normals:------------", .{});
                // },
                // .texcoord => |idx| {
                //     const accessor = gltf.data.accessors.items[idx];
                //     var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                //     std.log.info("texcoords:------------", .{});
                //     while (it.next()) |t| {
                //         std.log.info("{d} {d}", .{ t[0], t[1] });
                //     }
                //     std.log.info("texcoords:------------", .{});
                // },
                // .color => |idx| {
                //     const accessor = gltf.data.accessors.items[idx];
                //     var it = accessor.iterator(f32, &gltf, gltf.glb_binary.?);
                //     std.log.info("colors:------------", .{});
                //     while (it.next()) |c| {
                //         std.log.info("{d} {d} {d}", .{ c[0], c[1], c[2] });
                //     }
                //     std.log.info("colors:------------", .{});
                // },
                else => {},
            }
        }
    }

    std.log.info("Image count: {d}", .{gltf.data.images.items.len});
    if (gltf.data.images.items.len == 0) std.log.info("No image found in this model", .{});
    for (gltf.data.images.items, 0..) |image, i| {
        std.log.info("{d} Image: {s}", .{ i, image.name orelse "unknown" });
        if (image.data) |data| {
            var img = try zstbi.Image.loadFromMemory(data, 4);
            defer img.deinit();
            std.log.info("Image width: {d}", .{img.width});
            std.log.info("Image height: {d}", .{img.height});
            std.log.info("Image channels: {d}", .{img.num_components});
        }
    }

    std.log.info("Texture count: {d}", .{gltf.data.textures.items.len});
    if (gltf.data.textures.items.len == 0) std.log.info("No texture found in this model", .{});
    // for (gltf.data.textures.items) |texture| {
    //     std.log.info("Texture: {s}", .{texture.name orelse "No texture found in this model"});
    // }

    std.log.info("Material count: {d}", .{gltf.data.materials.items.len});
    if (gltf.data.materials.items.len == 0) std.log.info("No material found in this model", .{});
    // for (gltf.data.materials.items) |material| {
    //     std.log.info("Material: {s}", .{material.name orelse "No material found in this model"});
    // }

    std.log.info("Node count: {d}", .{gltf.data.nodes.items.len});
    if (gltf.data.nodes.items.len == 0) std.log.info("No node found in this model", .{});
    // for (gltf.data.nodes.items) |node| {
    //     std.log.info("Node: {s}", .{node.name orelse "No node found in this model"});
    // }

    std.log.info("Scene count: {d}", .{gltf.data.scenes.items.len});
    if (gltf.data.scenes.items.len == 0) std.log.info("No scene found in this model", .{});
    // for (gltf.data.scenes.items) |scene| {
    //     std.log.info("Scene: {s}", .{scene.name orelse "No scene found in this model"});
    // }

    std.log.info("Animation count: {d}", .{gltf.data.animations.items.len});
    if (gltf.data.animations.items.len == 0) std.log.info("No animation found in this model", .{});
    // for (gltf.data.animations.items) |animation| {
    //     std.log.info("Animation: {s}", .{animation.name orelse "No animation found in this model"});
    // }

    std.log.info("Skin count: {d}", .{gltf.data.skins.items.len});
    if (gltf.data.skins.items.len == 0) std.log.info("No skin found in this model", .{});
    // for (gltf.data.skins.items) |skin| {
    //     std.log.info("Skin: {s}", .{skin.name orelse "No skin found in this model"});
    // }

    std.log.info("Camera count: {d}", .{gltf.data.cameras.items.len});
    if (gltf.data.cameras.items.len == 0) std.log.info("No camera found in this model", .{});
    // for (gltf.data.cameras.items) |camera| {
    //     std.log.info("Camera: {s}", .{camera.name orelse "No camera found in this model"});
    // }

    std.log.info("Buffer count: {d}", .{gltf.data.buffers.items.len});
    if (gltf.data.buffers.items.len == 0) std.log.info("No buffer found in this model", .{});
    // for (gltf.data.buffers.items) |buffer| {
    //     std.log.info("Buffer: {s}", .{buffer.name orelse "No buffer found in this model"});
    // }

    std.log.info("BufferView count: {d}", .{gltf.data.buffer_views.items.len});
    if (gltf.data.buffer_views.items.len == 0) std.log.info("No bufferView found in this model", .{});
    // for (gltf.data.buffer_views.items) |bufferView| {
    //     std.log.info("BufferView: {s}", .{bufferView.name orelse "No bufferView found in this model"});
    // }

    std.log.info("Accessor count: {d}", .{gltf.data.accessors.items.len});
    if (gltf.data.accessors.items.len == 0) std.log.info("No accessor found in this model", .{});
    // for (gltf.data.accessors.items) |accessor| {
    //     std.log.info("Accessor: {s}", .{accessor.name orelse "No accessor found in this model"});
    // }

    std.log.info("Texture Sampler count: {d}", .{gltf.data.samplers.items.len});
    if (gltf.data.samplers.items.len == 0) std.log.info("No textureSampler found in this model", .{});
    // for (gltf.data.samplers.items) |textureSampler| {
    //     std.log.info("TextureSampler: {s}", .{textureSampler.name orelse "No textureSampler found in this model"});
    // }
    std.log.info("Lights count: {d}", .{gltf.data.lights.items.len});
    if (gltf.data.lights.items.len == 0) std.log.info("No light found in this model", .{});
    for (gltf.data.lights.items) |light| {
        std.log.info("Light: {s}", .{light.name orelse "No light found in this model"});
    }
}
