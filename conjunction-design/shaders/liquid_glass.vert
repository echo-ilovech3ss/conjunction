#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 u_tintColor; // sRGB rgba (a = 0 if untinted)
    vec4 u_params0;   // x = variant (0 Reg, 1 Clear), y = darkMode, z = reduceTransparency, w = highContrast
    vec4 u_geom;      // x = widthPt, y = heightPt, z = cornerRadiusPt, w = captureMarginPt
    vec4 u_bgInfo;    // x = backdropWidthPt, y = backdropHeightPt, z = scrollPocketMode (0 off, 1 soft, 2 hard), w = pocketHeightPt
    vec4 u_extra;     // x = hasBackdrop (1 yes, 0 fallback), y = fallbackMidY, z = rimIntensityScale, w = pocketFlipped (0 bottom edge, 1 top edge)
};

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
