#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 u_fillColor;   // straight sRGB rgba
    vec4 u_borderColor; // straight sRGB rgba
    vec4 u_geom;        // x = w, y = h, z = radius, w = borderWidth
};

float continuousRectSDF(vec2 p, vec2 halfSize, float r) {
    float minHalf = min(halfSize.x, halfSize.y);
    if (r <= 0.001 || minHalf <= 0.001) {
        vec2 q0 = abs(p) - halfSize;
        return -(length(max(q0, 0.0)) + min(max(q0.x, q0.y), 0.0));
    }
    float pillBlend = clamp((minHalf - r) / max(0.35 * r, 1.0), 0.0, 1.0);
    float extR = min(r * mix(1.0, 1.528665, pillBlend), minHalf);
    float expN = mix(2.0, 3.2, pillBlend);
    vec2 q = abs(p) - halfSize + vec2(extR);
    vec2 k = max(q, 0.0);
    float cornerDist = pow(pow(k.x, expN) + pow(k.y, expN), 1.0 / expN);
    return -(min(max(q.x, q.y), 0.0) + cornerDist - extR);
}

void main() {
    vec2 sizePt = max(u_geom.xy, vec2(1.0));
    vec2 p = (qt_TexCoord0 - 0.5) * sizePt;
    float d = continuousRectSDF(p, 0.5 * sizePt, max(u_geom.z, 0.0));
    float aa = clamp(d + 0.5, 0.0, 1.0);
    if (aa <= 0.0) discard;

    float bw = max(u_geom.w, 0.0);
    float bMask = (bw > 0.01) ? (1.0 - smoothstep(bw - 0.5, bw + 0.5, max(d, 0.0))) : 0.0;

    vec4 col = mix(u_fillColor, u_borderColor, bMask * u_borderColor.a);
    float outA = max(u_fillColor.a, bMask * u_borderColor.a) * aa;
    fragColor = vec4(col.rgb * outA, outA) * qt_Opacity;
}
