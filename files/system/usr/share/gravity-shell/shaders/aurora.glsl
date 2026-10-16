// Aurora: soft bands of light drifting over a night sky, with faint stars.
// Light on purpose: a few sines per pixel and a three-step loop, nothing more.
// Shadertoy-style: write mainImage(); iTime and iResolution are provided.

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    float t = iTime * 0.06;

    // Night sky, a little lighter towards the horizon.
    vec3 col = mix(vec3(0.05, 0.05, 0.13), vec3(0.015, 0.015, 0.05), uv.y);

    // Stars that twinkle slowly; only in the upper part of the sky.
    vec2 cell = floor(fragCoord / 3.0);
    float star = step(0.9975, hash(cell));
    col += star * (0.5 + 0.5 * sin(iTime * 1.5 + hash(cell + 7.0) * 6.28)) * 0.6 * smoothstep(0.35, 0.9, uv.y);

    // Three curtains of light, each with its own colour, sway and speed.
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float y = 0.62 - fi * 0.07
            + 0.10 * sin(uv.x * (2.2 + fi * 0.7) + t * (1.0 + 0.4 * fi) + fi * 1.9)
            + 0.04 * sin(uv.x * 6.5 - t * 2.3 + fi * 3.1);
        float d = uv.y - y;
        // Sharp lower edge, long soft glow upwards, like real aurora.
        float band = d > 0.0 ? exp(-d * 9.0) : exp(-d * d * 900.0);
        band *= 0.55 + 0.45 * sin(uv.x * 9.0 + t * 4.0 + fi * 2.3);
        vec3 c = mix(vec3(0.15, 0.95, 0.65), vec3(0.55, 0.35, 1.0), fi * 0.5);
        col += c * band * 0.42;
    }

    fragColor = vec4(col, 1.0);
}
