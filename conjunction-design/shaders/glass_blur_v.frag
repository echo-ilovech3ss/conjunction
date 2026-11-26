#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 u_blurParams; // x = sigmaPt, y = invTexW, z = invTexH, w = stepPt
};

layout(binding = 1) uniform sampler2D source;

void main() {
    float sigma = max(u_blurParams.x, 0.01);
    float stepPt = max(u_blurParams.w, 1.0);
    if (sigma <= 0.5) {
        fragColor = texture(source, qt_TexCoord0) * qt_Opacity;
        return;
    }

    vec2 invTex = vec2(u_blurParams.y, u_blurParams.z);
    float inv2Sigma2 = 1.0 / (2.0 * sigma * sigma);

    vec4 accum = texture(source, qt_TexCoord0);
    float wSum = 1.0;

    for (int k = 1; k <= 15; ++k) {
        float nA = float(2 * k - 1);
        float nB = float(2 * k);
        float xA = nA * stepPt;
        float xB = nB * stepPt;
        float wA = exp(-(xA * xA) * inv2Sigma2);
        float wB = exp(-(xB * xB) * inv2Sigma2);
        float wPair = wA + wB;
        if (wPair > 1e-6) {
            float t = nA + wB / wPair;
            float dv = t * invTex.y;
            accum += texture(source, clamp(qt_TexCoord0 + vec2(0.0, dv), 0.001, 0.999)) * wPair;
            accum += texture(source, clamp(qt_TexCoord0 - vec2(0.0, dv), 0.001, 0.999)) * wPair;
            wSum += 2.0 * wPair;
        }
    }

    fragColor = (accum / wSum) * qt_Opacity;
}
