// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage> lightIndices: array<u32>;
@group(${bindGroup_scene}) @binding(3) var<storage> lightNum: array<u32>;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let viewMat = cameraUniforms.viewMat;

    // calculate the cluster's z-index
    let viewPos = (viewMat * vec4(in.pos, 1)).xyz;
    let zFar = cameraUniforms.farPlane;
    let zNear = cameraUniforms.nearPlane;
    let sliceZ = u32(floor(log(-viewPos.z / zNear) / log(zFar / zNear) * f32(cameraUniforms.dimSlicesZ)));

    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let sliceX = u32(floor(in.fragPos.x / f32(cameraUniforms.canvasWidth) * f32(cameraUniforms.dimSlicesX)));
    let sliceY = u32(floor(in.fragPos.y / f32(cameraUniforms.canvasHeight) * f32(cameraUniforms.dimSlicesY)));
    let clusterIdx = sliceZ * u32(cameraUniforms.dimSlicesX * cameraUniforms.dimSlicesY) +
                     sliceY * u32(cameraUniforms.dimSlicesX) +
                     sliceX;

    // show slice index as color
    // let sliceIdx = (sliceZ + sliceX + sliceY) % 8u;
    // var color: vec3f;
    // if (sliceIdx == 0u) {
    //     color = vec3f(0,0,0);
    // } else if (sliceIdx == 1u) {
    //     color = vec3f(1,0,0);
    // } else if (sliceIdx == 2u) {
    //     color = vec3f(0,1,0);
    // } else if (sliceIdx == 3u) {
    //     color = vec3f(0,0,1);
    // } else if (sliceIdx == 4u) {
    //     color = vec3f(1,1,0);
    // } else if (sliceIdx == 5u) {
    //     color = vec3f(0,1,1);
    // } else if (sliceIdx == 6u) {
    //     color = vec3f(1,0,1);
    // } else {
    //     color = vec3f(1,1,1);
    // }
    // return vec4f(color, 1);

    var totalLightContrib = vec3f(0, 0, 0);
    for (var i = 0u; i < lightNum[clusterIdx]; i++) {
        let light = lightSet.lights[lightIndices[clusterIdx * ${maxLightsPerCluster}u + i]];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}
