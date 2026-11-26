#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

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

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;
}
