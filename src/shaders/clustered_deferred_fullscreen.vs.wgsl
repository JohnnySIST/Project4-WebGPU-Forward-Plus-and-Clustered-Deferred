// TODO-3: implement the Clustered Deferred fullscreen vertex shader

// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.
struct VertexOutput {
    @builtin(position) position : vec4f,
    @location(0) uv : vec2f
};

@vertex
fn main(@builtin(vertex_index) vertex_index : u32) -> VertexOutput {
    var positions = array<vec2f, 3>(
        vec2f(-4.0, -1.0),
        vec2f(4.0, -1.0),
        vec2f(0.0, 3.0)
    );
    var pos = positions[vertex_index];
    return VertexOutput(
        vec4f(pos, 0.0, 1.0),
        vec2f((pos.x + 1.0) * 0.5, (1.0 - pos.y) * 0.5)
    );
}