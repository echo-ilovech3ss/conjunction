#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 u_tintColor; // sRGB rgba (a = 0 if untinted)
    vec4 u_params0;   // x = variant (0 Reg, 1 Clear), y = darkMode, z = reduceTransparency, w = highContrast
    vec4 u_geom;      // x = widthPt, y = heightPt, z = cornerRadiusPt, w = captureMarginPt
    vec4 u_bgInfo;    // x = backdropWidthPt, y = backdropHeightPt, z = scrollPocketMode (0 off, 1 soft, 2 hard), w = pocketHeightPt
    vec4 u_extra;     // x = hasBackdrop (1 yes, 0 fallback), y = fallbackMidY, z = rimIntensityScale, w = pocketFlipped
};

layout(binding = 1) uniform sampler2D u_backdropBlur;

// Continuous curvature squircle / capsule SDF (SPEC §2.1: 1.528665 extension for non-pill corners)
float continuousRectSDF(vec2 p, vec2 halfSize, float r) {
    float minHalf = min(halfSize.x, halfSize.y);
    if (r <= 0.001 || minHalf <= 0.001) {
        vec2 q0 = abs(p) - halfSize;
        return -(length(max(q0, 0.0)) + min(max(q0.x, q0.y), 0.0));
    }
    // Smoothly transition from true circular capsule ends (r >= minHalf) to 1.528665x superellipse corners
    float pillBlend = clamp((minHalf - r) / max(0.35 * r, 1.0), 0.0, 1.0);
    float extR = min(r * mix(1.0, 1.528665, pillBlend), minHalf);
    float expN = mix(2.0, 3.2, pillBlend);
    vec2 q = abs(p) - halfSize + vec2(extR);
    vec2 k = max(q, 0.0);
    float cornerDist = pow(pow(k.x, expN) + pow(k.y, expN), 1.0 / expN);
    return -(min(max(q.x, q.y), 0.0) + cornerDist - extR);
}

vec2 continuousGrad(vec2 p, vec2 halfSize, float r) {
    const float eps = 0.25;
    float dx = continuousRectSDF(p + vec2(eps, 0.0), halfSize, r) - continuousRectSDF(p - vec2(eps, 0.0), halfSize, r);
    float dy = continuousRectSDF(p + vec2(0.0, eps), halfSize, r) - continuousRectSDF(p - vec2(0.0, eps), halfSize, r);
    vec2 g = vec2(dx, dy);
    float l = length(g);
    return l > 1e-5 ? g / l : vec2(0.0, 1.0);
}

void main() {
    vec2 sizePt = max(u_geom.xy, vec2(1.0));
    vec2 halfSize = 0.5 * sizePt;
    float cornerR = max(u_geom.z, 0.0);
    vec2 p = (qt_TexCoord0 - 0.5) * sizePt;

    float d = continuousRectSDF(p, halfSize, cornerR);
    float aa = clamp(d + 0.5, 0.0, 1.0);
    if (aa <= 0.0) discard;

    bool isClear = u_params0.x > 0.5;
    bool isDark = u_params0.y > 0.5;
    bool reduceTrans = u_params0.z > 0.5;
    bool highContrast = u_params0.w > 0.5;

    if (reduceTrans) {
        // SPEC §1.5 Light Chrome #ECECEC (0.925) / Dark Chrome #282828 (0.1569)
        vec3 opaqueBg = isDark ? vec3(0.1569) : vec3(0.9255);
        if (u_tintColor.a > 0.001) {
            opaqueBg = mix(opaqueBg, u_tintColor.rgb, u_tintColor.a * 0.25);
        }
        if (highContrast && d < 1.0) {
            opaqueBg = isDark ? vec3(0.58) : vec3(0.28);
        }
        fragColor = vec4(opaqueBg * aa, aa) * qt_Opacity;
        return;
    }

    float m = min(sizePt.x, sizePt.y);

    // 1. Inward radial refraction displacement dr(d)
    vec2 normal = continuousGrad(p, halfSize, cornerR); // points inward (+y at top edge)
    float refrAmp = isClear ? 45.21 : 31.5;
    float dr = (d < 24.0) ? refrAmp * exp(-max(d, 0.0) / 6.79) : 0.0;

    vec3 blurRGB;
    if (u_extra.x > 0.5 && u_bgInfo.x > 1.0 && u_bgInfo.y > 1.0) {
        vec2 marginPt = vec2(u_geom.w);
        vec2 localPt = qt_TexCoord0 * sizePt;
        vec2 samplePt = marginPt + localPt - normal * dr;
        vec2 uvRefr = clamp(samplePt / max(u_bgInfo.xy, vec2(1.0)), 0.001, 0.999);
        vec4 s = texture(u_backdropBlur, uvRefr);
        blurRGB = (s.a > 0.001) ? clamp(s.rgb / s.a, 0.0, 1.0) : s.rgb;
    } else {
        // Calibrated ambient glass luminance when overlay lacks live backdrop source
        float grad = mix(isDark ? 0.16 : 0.90, isDark ? 0.24 : 0.78, qt_TexCoord0.y);
        blurRGB = vec3(grad);
    }

    // 2. SDR Highlight Clamp before tone matrix
    float maxLuma = 1.0;
    if (!isClear) {
        maxLuma = isDark
            ? (0.60 - 0.25 * clamp((m - 64.0) / 40.0, 0.0, 1.0))
            : 0.94;
    }
    vec3 clamped = min(blurRGB, vec3(maxLuma));

    // 3. Saturation + Black/White Lift Matrix (sRGB)
    float Y = dot(clamped, vec3(0.2126, 0.7152, 0.0722));
    float sat = isClear ? 1.0 : (isDark ? 1.30 : 1.20);
    float blackLvl = isClear ? (isDark ? 0.05 : 0.20) : (isDark ? 0.08 : 0.40);
    float whiteLvl = isClear ? (isDark ? 0.80 : 0.95) : (isDark ? 1.125 : 0.96);
    vec3 satRGB = vec3(Y) + sat * (clamped - vec3(Y));
    vec3 face = clamp(mix(vec3(blackLvl), vec3(whiteLvl), satRGB), 0.0, 1.0);

    // 4. FaceFill overlay
    vec4 faceFill = isClear
        ? (isDark ? vec4(1.0, 1.0, 1.0, 0.05) : vec4(1.0, 1.0, 1.0, 0.10))
        : (isDark ? vec4(0.0, 0.0, 0.0, 0.00) : vec4(1.0, 1.0, 1.0, 0.20));
    face = mix(face, faceFill.rgb, faceFill.a);

    // 5. Optional Tint
    if (u_tintColor.a > 0.001) {
        if (!isClear) {
            float lumaM = dot(face, vec3(0.7638, 0.2145, 0.0217)) + (isDark ? 0.10 : -0.10);
            face = mix(face, vec3(clamp(lumaM, 0.0, 1.0)), u_tintColor.a * 0.70);
        } else {
            vec3 tinted = u_tintColor.rgb * mix(1.0, Y + 0.35, 0.45);
            face = mix(face, clamp(tinted, 0.0, 1.0), u_tintColor.a);
        }
    }

    // 6. Specular Key-Fill Rim Highlight (90 deg top vector, 0.5-1.0 pt rim)
    float rimMask = 1.0 - smoothstep(0.0, 1.25, max(d, 0.0));
    float dirDot = -normal.y; // +1 at top edge, -1 at bottom, 0 at sides
    float specTop = smoothstep(0.0, isClear ? 0.50 : 0.86, abs(dirDot));
    float sideShade = 1.0 - smoothstep(0.3, 0.9, 1.0 - abs(dirDot));
    vec3 rimColor = isDark
        ? mix(vec3(0.29), clamp(0.3125 * face + 0.9375, 0.0, 1.35) * 0.62, specTop)
        : mix(vec3(0.73), vec3(1.0), specTop);
    float rimAmt = (isClear ? 0.40 : 0.50) * clamp(u_extra.z, 0.0, 1.5);
    face = mix(face, clamp(rimColor, 0.0, 1.0), rimMask * rimAmt * (0.45 + 0.55 * max(specTop, sideShade)));

    // 7. ScrollPocket edge transition if active
    float scrollMode = u_bgInfo.z;
    float pocketH = max(u_bgInfo.w, 1.0);
    float outAlpha = aa;
    if (scrollMode > 0.5) {
        float yFromEdge = (u_extra.w > 0.5) ? (qt_TexCoord0.y * sizePt.y) : ((1.0 - qt_TexCoord0.y) * sizePt.y);
        if (scrollMode < 1.5) {
            // Soft Pocket: top-to-bottom fade over pocketH near leading/trailing scroll seam
            float fadeMask = clamp(yFromEdge / pocketH, 0.0, 1.0);
            outAlpha *= mix(0.8245, 1.0, fadeMask);
        } else {
            // Hard Pocket: 0.5-1.0 pt hairline along seam
            if (yFromEdge <= 0.75) {
                vec3 hairline = isDark ? vec3(1.0) : vec3(0.0);
                float hAlpha = isDark ? 0.07 : 0.098;
                face = mix(face, hairline, highContrast ? 0.65 : hAlpha);
            }
        }
    }

    // 8. Increased Contrast 1.0 pt perimeter outline
    if (highContrast && d < 1.0) {
        vec3 borderRgb = isDark ? vec3(0.45 + 0.55 * Y) : vec3(0.0);
        face = mix(face, borderRgb, 0.45);
    }

    fragColor = vec4(face * outAlpha, outAlpha) * qt_Opacity;
}
