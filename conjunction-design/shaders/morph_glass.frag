#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 u_params0;    // x = variant, y = darkMode, z = reduceTransparency, w = highContrast
    vec4 u_geom;       // x = w, y = h, z = spacingPt, w = itemCount
    vec4 u_bgInfo;     // x = backdropW, y = backdropH, z = captureMarginPt, w = hasBackdrop
    vec4 u_pill0;      // x = cx, y = cy, z = halfW, w = halfH
    vec4 u_pill1;
    vec4 u_pill2;
    vec4 u_pill3;
    vec4 u_radii;      // corner radius of pill 0..3
};

layout(binding = 1) uniform sampler2D u_backdropBlur;

float rectSDFOut(vec2 p, vec4 pill, float r) {
    vec2 halfSize = max(pill.zw, vec2(1.0));
    float minHalf = min(halfSize.x, halfSize.y);
    float effR = min(r, minHalf);
    vec2 d = abs(p - pill.xy) - halfSize + vec2(effR);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - effR;
}

float sminQuad(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / max(k, 1.0), 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Polynomial smooth-min + calibrated meniscus bridge within container spacing (SPEC §1.4)
float glassSmin(float d1, float d2, vec2 c1, vec2 c2, vec2 h1, vec2 h2, vec2 pt, float spacing) {
    float k = spacing * 0.60;
    float dBase = sminQuad(d1, d2, k);

    float distCenters = length(c2 - c1);
    float gap = max(0.0, distCenters - (h1.x + h2.x));
    if (gap < spacing - 4.0) {
        vec2 axis = (distCenters > 1e-4) ? ((c2 - c1) / distCenters) : vec2(1.0, 0.0);
        vec2 perp = vec2(-axis.y, axis.x);
        vec2 mid = 0.5 * (c1 + c2);
        vec2 rel = pt - mid;
        float along = abs(dot(rel, axis));
        float across = abs(dot(rel, perp));

        // Calibrated 56pt height neck: 34.0 (gap=0), 30.5 (gap=4), 15.0 (gap=10), <=1 (gap>=20)
        float halfBridgeY = (gap <= 4.0)
            ? mix(17.0, 15.25, clamp(gap / 4.0, 0.0, 1.0))
            : mix(15.25, 0.0, smoothstep(4.0, 16.0, gap));

        float halfSpanX = max(distCenters * 0.55, 8.0);
        float profileX = 1.0 - smoothstep(0.0, halfSpanX, along);
        if (halfBridgeY > 0.25 && along < halfSpanX) {
            float dBridge = across - halfBridgeY * pow(profileX, 0.45);
            float dEnd = along - distCenters * 0.5;
            dBase = min(dBase, max(dBridge, dEnd));
        }
    }
    return dBase;
}

float evalScene(vec2 pt) {
    int count = int(u_geom.w + 0.5);
    float d = 1e6;
    if (count >= 1) d = rectSDFOut(pt, u_pill0, u_radii.x);
    if (count >= 2) {
        float d1 = rectSDFOut(pt, u_pill1, u_radii.y);
        d = glassSmin(d, d1, u_pill0.xy, u_pill1.xy, u_pill0.zw, u_pill1.zw, pt, u_geom.z);
    }
    if (count >= 3) {
        float d2 = rectSDFOut(pt, u_pill2, u_radii.z);
        d = glassSmin(d, d2, u_pill1.xy, u_pill2.xy, u_pill1.zw, u_pill2.zw, pt, u_geom.z);
    }
    if (count >= 4) {
        float d3 = rectSDFOut(pt, u_pill3, u_radii.w);
        d = glassSmin(d, d3, u_pill2.xy, u_pill3.xy, u_pill2.zw, u_pill3.zw, pt, u_geom.z);
    }
    return -d; // positive INSIDE
}

vec2 evalNormal(vec2 pt) {
    const float eps = 0.25;
    float dx = evalScene(pt + vec2(eps, 0.0)) - evalScene(pt - vec2(eps, 0.0));
    float dy = evalScene(pt + vec2(0.0, eps)) - evalScene(pt - vec2(0.0, eps));
    vec2 g = vec2(dx, dy);
    float l = length(g);
    return l > 1e-5 ? g / l : vec2(0.0, 1.0);
}

void main() {
    vec2 sizePt = max(u_geom.xy, vec2(1.0));
    vec2 pt = qt_TexCoord0 * sizePt;
    float d = evalScene(pt);
    float aa = clamp(d + 0.5, 0.0, 1.0);
    if (aa <= 0.0) discard;

    bool isClear = u_params0.x > 0.5;
    bool isDark = u_params0.y > 0.5;
    bool reduceTrans = u_params0.z > 0.5;
    bool highContrast = u_params0.w > 0.5;

    if (reduceTrans) {
        vec3 c = isDark ? vec3(0.1569) : vec3(0.9255);
        if (highContrast && d < 1.0) c = isDark ? vec3(0.58) : vec3(0.28);
        fragColor = vec4(c * aa, aa) * qt_Opacity;
        return;
    }

    vec2 normal = evalNormal(pt);
    float refrAmp = isClear ? 45.21 : 31.5;
    float dr = (d < 24.0) ? refrAmp * exp(-max(d, 0.0) / 6.79) : 0.0;

    vec3 blurRGB;
    if (u_bgInfo.w > 0.5 && u_bgInfo.x > 1.0 && u_bgInfo.y > 1.0) {
        vec2 samplePt = vec2(u_bgInfo.z) + pt - normal * dr;
        vec2 uvRefr = clamp(samplePt / u_bgInfo.xy, 0.001, 0.999);
        vec4 s = texture(u_backdropBlur, uvRefr);
        blurRGB = (s.a > 0.001) ? clamp(s.rgb / s.a, 0.0, 1.0) : s.rgb;
    } else {
        blurRGB = vec3(mix(isDark ? 0.16 : 0.90, isDark ? 0.24 : 0.78, qt_TexCoord0.y));
    }

    float m = min(2.0 * u_pill0.w, sizePt.y);
    float maxLuma = isClear ? 1.0 : (isDark ? (0.60 - 0.25 * clamp((m - 64.0) / 40.0, 0.0, 1.0)) : 0.94);
    vec3 clamped = min(blurRGB, vec3(maxLuma));

    float Y = dot(clamped, vec3(0.2126, 0.7152, 0.0722));
    float sat = isClear ? 1.0 : (isDark ? 1.30 : 1.20);
    float blackLvl = isClear ? (isDark ? 0.05 : 0.20) : (isDark ? 0.08 : 0.40);
    float whiteLvl = isClear ? (isDark ? 0.80 : 0.95) : (isDark ? 1.125 : 0.96);
    vec3 satRGB = vec3(Y) + sat * (clamped - vec3(Y));
    vec3 face = clamp(mix(vec3(blackLvl), vec3(whiteLvl), satRGB), 0.0, 1.0);

    vec4 faceFill = isClear
        ? (isDark ? vec4(1.0, 1.0, 1.0, 0.05) : vec4(1.0, 1.0, 1.0, 0.10))
        : (isDark ? vec4(0.0, 0.0, 0.0, 0.00) : vec4(1.0, 1.0, 1.0, 0.20));
    face = mix(face, faceFill.rgb, faceFill.a);

    float rimMask = 1.0 - smoothstep(0.0, 1.25, max(d, 0.0));
    float specTop = smoothstep(0.0, isClear ? 0.50 : 0.86, abs(-normal.y));
    vec3 rimColor = isDark
        ? mix(vec3(0.29), clamp(0.3125 * face + 0.9375, 0.0, 1.25) * 0.55, specTop)
        : mix(vec3(0.73), vec3(1.0), specTop);
    face = mix(face, clamp(rimColor, 0.0, 1.0), rimMask * (isClear ? 0.40 : 0.50));

    if (highContrast && d < 1.0) {
        face = isDark ? vec3(0.58) : vec3(0.28);
    }

    fragColor = vec4(face * aa, aa) * qt_Opacity;
}
