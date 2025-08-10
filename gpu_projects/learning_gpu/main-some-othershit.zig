// const std = @import("std");
// const sdl3 = @import("Cat");
// const zmath = sdl3.zmath;
// const zstbi = sdl3.zstbi;
// const zgui = sdl3.zgui;
// const zgui_sdl = zgui.backend;
// const assets = @import("assets");
// const shaders = @import("shaders");
// const FpsManager = sdl3.FpsManager;
//
// const SCREEN_WIDTH = 1280;
// const SCREEN_HEIGHT = 780;
//
// const assert = std.debug.assert;
//
// const vertex_shader_code = shaders.@"shader.vertex.spirv";
// const fragment_shader_code = shaders.@"shader.fragment.spirv";
//
// const UBO = struct {
//     mvp: zmath.Mat,
// };
//
// pub fn main() !void {
//     defer sdl3.shutdown();
//
//     sdl3.log.setAllPriorities(.verbose);
//
//     const init_flags = sdl3.InitFlags{ .video = true };
//     try sdl3.init(init_flags);
//     defer sdl3.quit(init_flags);
//
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer {
//         const leaked = gpa.deinit();
//         assert(leaked == .ok);
//     }
//     const allocator = gpa.allocator();
//
//     zgui.init(allocator);
//     defer zgui.deinit();
//     zstbi.init(allocator);
//     defer zstbi.deinit();
//
//     const window = try sdl3.video.Window.init("GPU programming", SCREEN_WIDTH, SCREEN_HEIGHT, .{});
//     defer window.deinit();
//
//     var fps_manager = FpsManager.init(.none);
//
//     const gpu = sdl3.c.SDL_CreateGPUDevice(sdl3.c.SDL_GPU_SHADERFORMAT_SPIRV, true, null);
//     defer sdl3.c.SDL_DestroyGPUDevice(gpu);
//
//     const driver_name = sdl3.c.SDL_GetGPUDeviceDriver(gpu);
//
//     assert(sdl3.c.SDL_ClaimWindowForGPUDevice(gpu, window.value));
//     defer sdl3.c.SDL_ReleaseWindowFromGPUDevice(gpu, window.value);
//
//     try zgui_style_init(window);
//
//     zgui_sdl.init(window.value, .{
//         .device = gpu.?,
//         .color_target_format = sdl3.c.SDL_GetGPUSwapchainTextureFormat(gpu, window.value),
//         .msaa_samples = 0,
//     });
//     defer zgui_sdl.deinit();
//
//     const vertex_shader = loadShader(
//         gpu,
//         vertex_shader_code,
//         sdl3.c.SDL_GPU_SHADERSTAGE_VERTEX,
//         1,
//         0,
//     );
//     defer sdl3.c.SDL_ReleaseGPUShader(gpu, vertex_shader);
//     const fragment_shader = loadShader(
//         gpu,
//         fragment_shader_code,
//         sdl3.c.SDL_GPU_SHADERSTAGE_FRAGMENT,
//         0,
//         1,
//     );
//     defer sdl3.c.SDL_ReleaseGPUShader(gpu, fragment_shader);
//
//     //Create Texture
//     var image = try zstbi.Image.loadFromMemory(assets.images.@"trees.jpeg", 4);
//     defer image.deinit();
//     const pixels_byte_size = image.width * image.height * 4;
//
//     const texture = sdl3.c.SDL_CreateGPUTexture(gpu, &.{
//         .type = sdl3.c.SDL_GPU_TEXTURETYPE_2D,
//         .width = image.width,
//         .height = image.height,
//         .format = sdl3.c.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
//         .usage = sdl3.c.SDL_GPU_TEXTUREUSAGE_SAMPLER,
//         .layer_count_or_depth = 1,
//         .num_levels = 1,
//     });
//     defer sdl3.c.SDL_ReleaseGPUTexture(gpu, texture);
//
//     // create vertex data
//
//     const Vec3 = @Vector(3, f32);
//     const Color = @Vector(4, f32);
//     const Vertex = struct {
//         pos: Vec3,
//         color: Color,
//         uv: @Vector(2, f32),
//     };
//
//     const White: Color = .{ 1.0, 1.0, 1.0, 1.0 };
//     // const Green: Color = .{ 0.0, 1.0, 0.0, 1.0 };
//     const tint = White;
//
//     const vertices = [_]Vertex{
//         .{ .pos = .{ -1.0, 1.0, 0.0 }, .color = tint, .uv = .{ 0.0, 0.0 } }, //top left
//         .{ .pos = .{ 1.0, 1.0, 0.0 }, .color = tint, .uv = .{ 1.0, 0.0 } }, //top right
//         .{ .pos = .{ -1.0, -1.0, 0.0 }, .color = tint, .uv = .{ 0.0, 1.0 } }, //bottom left
//         .{ .pos = .{ 1.0, -1.0, 0.0 }, .color = tint, .uv = .{ 1.0, 1.0 } }, //bottom right
//     };
//     const vertices_byte_size = vertices.len * @sizeOf(@TypeOf(vertices[0]));
//
//     const indices = [_]u16{
//         0, 1, 2,
//         2, 1, 3,
//     };
//     const indices_byte_size = indices.len * @sizeOf(@TypeOf(indices[0]));
//
//     // describe vertex attributes and vertex buffers in pipline
//     const vertex_attributes = [_]sdl3.c.SDL_GPUVertexAttribute{
//         .{
//             .location = 0,
//             .format = sdl3.c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
//             .offset = @offsetOf(Vertex, "pos"),
//         },
//         .{
//             .location = 1,
//             .format = sdl3.c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
//             .offset = @offsetOf(Vertex, "color"),
//         },
//         .{
//             .location = 2,
//             .format = sdl3.c.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
//             .offset = @offsetOf(Vertex, "uv"),
//         },
//     };
//
//     const vertex_buffer_descriptions = [_]sdl3.c.SDL_GPUVertexBufferDescription{
//         .{
//             .slot = 0,
//             .pitch = @sizeOf(Vertex),
//         },
//     };
//
//     // create vertex buffer
//     const vertex_buffer = sdl3.c.SDL_CreateGPUBuffer(gpu, &.{
//         .usage = sdl3.c.SDL_GPU_BUFFERUSAGE_VERTEX,
//         .size = @intCast(vertices_byte_size),
//     });
//     defer sdl3.c.SDL_ReleaseGPUBuffer(gpu, vertex_buffer);
//     // create index buffer
//     const index_buffer = sdl3.c.SDL_CreateGPUBuffer(gpu, &.{
//         .usage = sdl3.c.SDL_GPU_BUFFERUSAGE_INDEX,
//         .size = @intCast(indices_byte_size),
//     });
//     defer sdl3.c.SDL_ReleaseGPUBuffer(gpu, index_buffer);
//
//     const transfer_buffer = sdl3.c.SDL_CreateGPUTransferBuffer(gpu, &.{
//         .usage = sdl3.c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
//         .size = @intCast(vertices_byte_size + indices_byte_size),
//     });
//     defer sdl3.c.SDL_ReleaseGPUTransferBuffer(gpu, transfer_buffer);
//     const transfer_memory_ptr = sdl3.c.SDL_MapGPUTransferBuffer(gpu, transfer_buffer, false);
//     const vertex_dest_ptr: [*]u8 = @ptrCast(transfer_memory_ptr.?);
//     const vertex_dest_slice = vertex_dest_ptr[0..vertices_byte_size];
//     const index_dest_ptr: [*]u8 = @ptrFromInt(@as(usize, @intFromPtr(vertex_dest_ptr)) + vertices_byte_size);
//     const index_dest_slice = index_dest_ptr[0..indices_byte_size];
//     const vertex_source_ptr: [*]const u8 = @ptrCast(vertices[0..].ptr);
//     const vertex_source_slice = vertex_source_ptr[0..vertices_byte_size];
//     const index_source_ptr: [*]const u8 = @ptrCast(indices[0..].ptr);
//     const index_source_slice = index_source_ptr[0..indices_byte_size];
//     @memcpy(vertex_dest_slice, vertex_source_slice);
//     @memcpy(index_dest_slice, index_source_slice);
//     sdl3.c.SDL_UnmapGPUTransferBuffer(gpu, transfer_buffer);
//
//     const texture_transfer_buffer = sdl3.c.SDL_CreateGPUTransferBuffer(gpu, &.{
//         .usage = sdl3.c.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
//         .size = @intCast(pixels_byte_size),
//     });
//     defer sdl3.c.SDL_ReleaseGPUTransferBuffer(gpu, texture_transfer_buffer);
//     const texture_transfer_memory_ptr = sdl3.c.SDL_MapGPUTransferBuffer(gpu, texture_transfer_buffer, false);
//     const texture_dest_ptr: [*]u8 = @ptrCast(texture_transfer_memory_ptr.?);
//     const texture_dest_slice = texture_dest_ptr[0..pixels_byte_size];
//     const texture_source_ptr: [*]const u8 = @ptrCast(image.data[0..].ptr);
//     const texture_source_slice = texture_source_ptr[0..pixels_byte_size];
//     @memcpy(texture_dest_slice, texture_source_slice);
//     sdl3.c.SDL_UnmapGPUTransferBuffer(gpu, texture_transfer_buffer);
//
//     //--------------------------
//     // - begin copy pass
//     const copy_cmd_buffer = sdl3.c.SDL_AcquireGPUCommandBuffer(gpu);
//     const copy_pass = sdl3.c.SDL_BeginGPUCopyPass(copy_cmd_buffer);
//     // - invoke upload commands
//     sdl3.c.SDL_UploadToGPUBuffer(
//         copy_pass,
//         &.{
//             .transfer_buffer = transfer_buffer,
//             .offset = 0,
//         },
//         &.{
//             .buffer = vertex_buffer,
//             .offset = 0,
//             .size = @intCast(vertices_byte_size),
//         },
//         false,
//     );
//     sdl3.c.SDL_UploadToGPUBuffer(
//         copy_pass,
//         &.{
//             .transfer_buffer = transfer_buffer,
//             .offset = vertices_byte_size,
//         },
//         &.{
//             .buffer = index_buffer,
//             .offset = 0,
//             .size = @intCast(indices_byte_size),
//         },
//         false,
//     );
//
//     sdl3.c.SDL_UploadToGPUTexture(
//         copy_pass,
//         &.{
//             .transfer_buffer = texture_transfer_buffer,
//         },
//         &.{
//             .texture = texture,
//             .w = image.width,
//             .h = image.height,
//             .d = 1,
//         },
//         false,
//     );
//     sdl3.c.SDL_EndGPUCopyPass(copy_pass);
//     assert(sdl3.c.SDL_SubmitGPUCommandBuffer(copy_cmd_buffer));
//
//     const sampler = sdl3.c.SDL_CreateGPUSampler(gpu, &.{});
//     defer sdl3.c.SDL_ReleaseGPUSampler(gpu, sampler);
//
//     const pipline = sdl3.c.SDL_CreateGPUGraphicsPipeline(
//         gpu,
//         &sdl3.c.SDL_GPUGraphicsPipelineCreateInfo{
//             .vertex_shader = vertex_shader,
//             .fragment_shader = fragment_shader,
//             .primitive_type = sdl3.c.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
//             .vertex_input_state = .{
//                 .num_vertex_buffers = vertex_buffer_descriptions.len,
//                 .vertex_buffer_descriptions = vertex_buffer_descriptions[0..].ptr,
//                 .num_vertex_attributes = vertex_attributes.len,
//                 .vertex_attributes = vertex_attributes[0..].ptr,
//             },
//             .target_info = .{
//                 .num_color_targets = 1,
//                 .color_target_descriptions = @ptrCast(&.{sdl3.c.SDL_GPUColorTargetDescription{
//                     .format = sdl3.c.SDL_GetGPUSwapchainTextureFormat(gpu, window.value),
//                 }}),
//             },
//         },
//     );
//     defer sdl3.c.SDL_ReleaseGPUGraphicsPipeline(gpu, pipline);
//
//     var w_cint: c_int = undefined;
//     var h_cint: c_int = undefined;
//     assert(sdl3.c.SDL_GetWindowSize(window.value, &w_cint, &h_cint));
//
//     const w = @as(f32, @floatFromInt(w_cint));
//     const h = @as(f32, @floatFromInt(h_cint));
//
//     var clear_color: [3]f32 = .{ 0.1, 0.2, 0.3 };
//     var rotation: f32 = 0;
//     const rotation_speed: f32 = std.math.degreesToRadians(100);
//
//     const proj_mat = zmath.perspectiveFovRh(std.math.degreesToRadians(70), w / h, 0.0001, 1000);
//
//     var paused = false;
//     while (true) {
//         var c_sdl_event: sdl3.c.SDL_Event = undefined;
//         while (sdl3.c.SDL_PollEvent(&c_sdl_event)) {
//             const guiConsumed = zgui_sdl.processEvent(&c_sdl_event);
//             _ = guiConsumed;
//
//             const io = zgui.io;
//             if (io.getWantCaptureMouse() or io.getWantCaptureKeyboard() or io.getWantTextInput()) {
//                 continue;
//             }
//
//             switch (sdl3.events.Event.fromSdl(c_sdl_event)) {
//                 .quit => return,
//                 .key_down => |key| {
//                     if (key.key) |k| {
//                         switch (k) {
//                             .space => paused = !paused,
//                             .escape => return,
//                             .ac_back => return,
//                             else => {},
//                         }
//                     }
//                 },
//                 .finger_down => |f| {
//                     _ = f;
//                     paused = !paused;
//                 },
//                 else => {},
//             }
//         }
//         // Update game state
//         fps_manager.tick();
//
//         if (!paused) rotation += rotation_speed * fps_manager.getDelta();
//         const rot = zmath.rotationY(rotation);
//         const trans = zmath.translation(0.0, 0.0, -2.6);
//         const model_mat = zmath.mul(rot, trans);
//         const ubo = UBO{
//             .mvp = zmath.mul(model_mat, proj_mat),
//         };
//
//         // render
//         //zgui
//         zgui_sdl.newFrame(@intCast(w_cint), @intCast(w_cint), 1);
//
//         const viewport_size = zgui.getMainViewport().getSize();
//         zgui.setNextWindowSize(.{ .cond = .always, .w = viewport_size[0] / 4, .h = viewport_size[1] / 4 });
//         zgui.setNextWindowBgAlpha(.{ .alpha = 0.1 });
//         zgui.setNextWindowPos(.{ .cond = .always, .x = viewport_size[0] - viewport_size[0] / 4, .y = 0 });
//
//         if (zgui.begin("Debug", .{ .flags = .{
//             .no_resize = true,
//             .no_collapse = true,
//             .no_title_bar = true,
//             .no_scrollbar = true,
//             .no_docking = true,
//             .no_nav_inputs = true,
//         } })) {
//             zgui.textUnformattedColored(.{ 0.1, 1, 0.1, 1 }, "Debug");
//             zgui.text("GPU: {s}", .{driver_name});
//             zgui.text("FPS: {d:.4}", .{fps_manager.getFps()});
//             zgui.text("Delta: {d:.4} ms", .{fps_manager.getDelta() * 1000});
//         }
//         zgui.end();
//
//         if (zgui.begin("Settings", .{})) {
//             _ = zgui.colorEdit3("Clear Color", .{ .col = &clear_color });
//         }
//         zgui.end();
//
//         const cmd_buffer = sdl3.c.SDL_AcquireGPUCommandBuffer(gpu);
//         var swapchain_texture: ?*sdl3.c.SDL_GPUTexture = undefined;
//         assert(sdl3.c.SDL_WaitAndAcquireGPUSwapchainTexture(cmd_buffer, window.value, &swapchain_texture, null, null));
//
//         zgui.render(); //--------------------Render Zgui----------------------
//
//         //Begin render pass
//         if (swapchain_texture) |swapchain_tex| {
//             const color_target = sdl3.c.SDL_GPUColorTargetInfo{
//                 .texture = swapchain_tex,
//                 .load_op = sdl3.c.SDL_GPU_LOADOP_CLEAR,
//                 .clear_color = .{ .r = clear_color[0], .g = clear_color[1], .b = clear_color[2], .a = 1 },
//                 .store_op = sdl3.c.SDL_GPU_STOREOP_STORE,
//             };
//
//             const render_pass = sdl3.c.SDL_BeginGPURenderPass(cmd_buffer, &color_target, 1, null);
//
//             sdl3.c.SDL_BindGPUGraphicsPipeline(render_pass, pipline);
//             const bindings = [_]sdl3.c.SDL_GPUBufferBinding{.{ .buffer = vertex_buffer }};
//             sdl3.c.SDL_BindGPUVertexBuffers(render_pass, 0, bindings[0..].ptr, 1);
//             const index_binding: sdl3.c.SDL_GPUBufferBinding = .{ .buffer = index_buffer };
//             sdl3.c.SDL_BindGPUIndexBuffer(render_pass, &index_binding, sdl3.c.SDL_GPU_INDEXELEMENTSIZE_16BIT);
//             sdl3.c.SDL_PushGPUVertexUniformData(cmd_buffer, 0, &ubo, @sizeOf(@TypeOf(ubo)));
//             const fragment_samplers_bindings = [_]sdl3.c.SDL_GPUTextureSamplerBinding{.{ .texture = texture, .sampler = sampler }};
//             sdl3.c.SDL_BindGPUFragmentSamplers(render_pass, 0, fragment_samplers_bindings[0..].ptr, 1);
//             sdl3.c.SDL_DrawGPUIndexedPrimitives(render_pass, indices.len, 1, 0, 0, 0);
//             sdl3.c.SDL_EndGPURenderPass(render_pass);
//
//             //----------------------Zgui RenderPass----------------------
//             zgui_sdl.prepareDrawData(cmd_buffer.?);
//             const zgui_color_target = [_]sdl3.c.SDL_GPUColorTargetInfo{.{
//                 .texture = swapchain_tex,
//                 .load_op = sdl3.c.SDL_GPU_LOADOP_LOAD,
//             }};
//             const zgui_render_pass = sdl3.c.SDL_BeginGPURenderPass(cmd_buffer, zgui_color_target[0..].ptr, 1, null);
//             zgui_sdl.renderDrawData(cmd_buffer.?, zgui_render_pass.?, null);
//             sdl3.c.SDL_EndGPURenderPass(zgui_render_pass);
//             //------------------------------------------------------------
//         }
//         assert(sdl3.c.SDL_SubmitGPUCommandBuffer(cmd_buffer));
//     }
// }
//
// fn loadShader(device: ?*sdl3.c.SDL_GPUDevice, code: []const u8, stage: sdl3.c.SDL_GPUShaderStage, num_uniform_buffers: u32, num_samplers: u32) ?*sdl3.c.SDL_GPUShader {
//     return sdl3.c.SDL_CreateGPUShader(
//         device,
//         &sdl3.c.SDL_GPUShaderCreateInfo{
//             .code_size = code.len,
//             .code = @ptrCast(code),
//             .entrypoint = "main",
//             .format = sdl3.c.SDL_GPU_SHADERFORMAT_SPIRV,
//             .stage = stage,
//             .num_uniform_buffers = num_uniform_buffers,
//             .num_samplers = num_samplers,
//         },
//     );
// }
//
// fn zgui_style_init(window: sdl3.video.Window) !void {
//     _ = zgui.io.addFontFromMemory(assets.fonts.@"Candara.ttf", std.math.floor(19 * try window.getDisplayScale()));
//     zgui.io.setIniFilename(null);
//     zgui.io.setConfigFlags(.{ .dock_enable = true });
//     var style = zgui.getStyle();
//     style.window_rounding = 12;
//     style.child_rounding = 12;
//     style.frame_rounding = 12;
//     style.scrollbar_rounding = 12;
//     style.grab_rounding = 12;
//     style.tab_rounding = 12;
//     style.popup_rounding = 12;
// }
