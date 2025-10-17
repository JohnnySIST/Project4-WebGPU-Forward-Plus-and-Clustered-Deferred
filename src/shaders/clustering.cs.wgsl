// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.
@group(${bindGroup_scene}) @binding(0) var<storage, read_write> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(3) var<storage, read_write> lightIndices: array<u32>;
@group(${bindGroup_scene}) @binding(4) var<storage, read_write> lightNum: array<u32>;

fn testAABB(aabbMin: vec3f, aabbMax: vec3f, lightPos: vec3f, lightRadius: f32) -> bool {
    var closestPos = lightPos;
    closestPos = clamp(closestPos, aabbMin, aabbMax);
    let distSq = dot(closestPos - lightPos, closestPos - lightPos);
    return distSq <= lightRadius * lightRadius;
}

@compute
@workgroup_size(${clusteringWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let index = globalIdx.x;
    if (index >= u32(cameraUniforms.numSlices)) {
        return;
    }
    let sliceZ = index / u32(cameraUniforms.dimSlicesX * cameraUniforms.dimSlicesY);
    let sliceY = (index / u32(cameraUniforms.dimSlicesX)) % u32(cameraUniforms.dimSlicesY);
    let sliceX = index % u32(cameraUniforms.dimSlicesX);
    const lightRadius = ${lightRadius}f;

    // calculate AABB for this cluster
    let zNear = cameraUniforms.nearPlane;
    let zFar = cameraUniforms.farPlane;
    let zMin = zNear * pow(zFar / zNear, f32(sliceZ) / f32(cameraUniforms.dimSlicesZ));
    let zMax = zNear * pow(zFar / zNear, f32(sliceZ + 1u) / f32(cameraUniforms.dimSlicesZ));
    let xMinNDC = f32(sliceX) / f32(cameraUniforms.dimSlicesX) * 2.f - 1.f;
    let xMaxNDC = f32(sliceX + 1u) / f32(cameraUniforms.dimSlicesX) * 2.f - 1.f;
    let yMinNDC = f32(sliceY) / f32(cameraUniforms.dimSlicesY) * 2.f - 1.f;
    let yMaxNDC = f32(sliceY + 1u) / f32(cameraUniforms.dimSlicesY) * 2.f - 1.f;
    let tanHalfFovY = tan(cameraUniforms.fovY * 0.5f);
    let tanHalfFovX = tanHalfFovY * cameraUniforms.aspect;
    let corner1 = vec3f(xMinNDC * zMin * tanHalfFovX, yMinNDC * zMin * tanHalfFovY, -zMin);
    let corner2 = vec3f(xMaxNDC * zMin * tanHalfFovX, yMaxNDC * zMin * tanHalfFovY, -zMin);
    let corner3 = vec3f(xMinNDC * zMin * tanHalfFovX, yMaxNDC * zMin * tanHalfFovY, -zMin);
    let corner4 = vec3f(xMaxNDC * zMin * tanHalfFovX, yMinNDC * zMin * tanHalfFovY, -zMin);
    let corner5 = vec3f(xMinNDC * zMax * tanHalfFovX, yMinNDC * zMax * tanHalfFovY, -zMax);
    let corner6 = vec3f(xMaxNDC * zMax * tanHalfFovX, yMaxNDC * zMax * tanHalfFovY, -zMax);
    let corner7 = vec3f(xMinNDC * zMax * tanHalfFovX, yMaxNDC * zMax * tanHalfFovY, -zMax);
    let corner8 = vec3f(xMaxNDC * zMax * tanHalfFovX, yMinNDC * zMax * tanHalfFovY, -zMax);
    let aabbMinView = min(min(min(corner1, corner2), min(corner3, corner4)), min(min(corner5, corner6), min(corner7, corner8)));
    let aabbMaxView = max(max(max(corner1, corner2), max(corner3, corner4)), max(max(corner5, corner6), max(corner7, corner8)));

    var count = 0u;
    for (var i = 0u; i < lightSet.numLights; i++) {
        let lightViewPos = (cameraUniforms.viewMat * vec4f(lightSet.lights[i].pos, 1.0)).xyz;
        if (testAABB(aabbMinView, aabbMaxView, lightViewPos, lightRadius)) {
            lightIndices[index * ${maxLightsPerCluster}u + count] = i;
            count = count + 1u;
        }
    }
    lightNum[index] = count;
}
