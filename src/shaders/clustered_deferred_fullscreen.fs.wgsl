// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage> lightIndices: array<u32>;
@group(${bindGroup_scene}) @binding(3) var<storage> lightNum: array<u32>;

@group(1) @binding(0) var positionTex: texture_2d<f32>;
@group(1) @binding(1) var normalTex: texture_2d<f32>;
@group(1) @binding(2) var colorTex: texture_2d<f32>;
@group(1) @binding(3) var bufferSampler: sampler;

struct FragmentInput {
    @location(0) uv : vec2f
};

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let pos = textureSample(positionTex, bufferSampler, in.uv).rgb;
    let nor = textureSample(normalTex, bufferSampler, in.uv).rgb;
    let color = textureSample(colorTex, bufferSampler, in.uv).rgb;

    let viewMat = cameraUniforms.viewMat;

    // calculate the cluster's z-index
    let viewPos = (viewMat * vec4(pos, 1)).xyz;
    let zFar = cameraUniforms.farPlane;
    let zNear = cameraUniforms.nearPlane;
    let sliceZ = u32(floor(log(-viewPos.z / zNear) / log(zFar / zNear) * f32(cameraUniforms.dimSlicesZ)));

    // calculate NDC x and y
    let clipPos = cameraUniforms.viewProjMat * vec4(pos, 1);
    let ndcPos = clipPos.xyz / clipPos.w;
    let sliceX = u32(floor((ndcPos.x + 1.0) / 2.0 * f32(cameraUniforms.dimSlicesX)));
    let sliceY = u32(floor((ndcPos.y + 1.0) / 2.0 * f32(cameraUniforms.dimSlicesY)));
    let clusterIdx = sliceZ * u32(cameraUniforms.dimSlicesX * cameraUniforms.dimSlicesY) +
                     sliceY * u32(cameraUniforms.dimSlicesX) +
                     sliceX;

    var totalLightContrib = vec3f(0, 0, 0);
    for (var i = 0u; i < lightNum[clusterIdx]; i++) {
        let light = lightSet.lights[lightIndices[clusterIdx * ${maxLightsPerCluster}u + i]];
        totalLightContrib += calculateLightContrib(light, pos, normalize(nor));
    }

    var finalColor = color * totalLightContrib;
    return vec4(finalColor, 1);
}
