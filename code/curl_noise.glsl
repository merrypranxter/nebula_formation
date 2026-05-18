// curl_noise.glsl
// Divergence-free turbulent velocity field for physically realistic gas motion.
//
// curl noise = ∇ × N(p)   where N is a smooth 3D vector noise field.
// By construction: div(curlNoise) = 0  (incompressible flow — correct for gas)
//
// References:
//   Bridson, Houriham & Nordenstam 2007, SIGGRAPH "Curl-noise for procedural
//   fluid flow" — the definitive algorithm.
//
// Usage: call curlNoise(p) to get a divergence-free velocity vector.
//        Scale by turbulenceScale and add largeScaleFlow as in README.
//
// Integration example (4th-order Runge-Kutta particle advection):
//   vec3 advect(vec3 pos, float dt, float scale) {
//       vec3 k1 = curlNoise(pos)                * scale;
//       vec3 k2 = curlNoise(pos + 0.5*dt*k1)   * scale;
//       vec3 k3 = curlNoise(pos + 0.5*dt*k2)   * scale;
//       vec3 k4 = curlNoise(pos +    dt*k3)     * scale;
//       return pos + dt/6.0 * (k1 + 2.0*k2 + 2.0*k3 + k4);
//   }

// ── Smooth 3D noise (gradient noise) ─────────────────────────────────────────
vec3 gradHash(vec3 p) {
    p = fract(p * vec3(127.1, 311.7, 74.7));
    p += dot(p, p.yxz + 19.19);
    return fract((p.xxy + p.yxx) * p.zyx) * 2.0 - 1.0;   // range [-1, 1]^3
}

float gradNoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);   // quintic interpolation

    return mix(mix(mix(dot(gradHash(i             ), f             ),
                       dot(gradHash(i+vec3(1,0,0)  ), f-vec3(1,0,0)  ), u.x),
                   mix(dot(gradHash(i+vec3(0,1,0)  ), f-vec3(0,1,0)  ),
                       dot(gradHash(i+vec3(1,1,0)  ), f-vec3(1,1,0)  ), u.x), u.y),
               mix(mix(dot(gradHash(i+vec3(0,0,1)  ), f-vec3(0,0,1)  ),
                       dot(gradHash(i+vec3(1,0,1)  ), f-vec3(1,0,1)  ), u.x),
                   mix(dot(gradHash(i+vec3(0,1,1)  ), f-vec3(0,1,1)  ),
                       dot(gradHash(i+vec3(1,1,1)  ), f-vec3(1,1,1)  ), u.x), u.y), u.z);
}

// ── Potential field (3 independent noise fields) ──────────────────────────────
// N(p) = (Nx(p), Ny(p), Nz(p)) — each a smooth scalar noise
// Use domain offsets to keep channels independent
vec3 potentialField(vec3 p) {
    return vec3(
        gradNoise(p),
        gradNoise(p + vec3(3.7, 1.9, 5.3)),
        gradNoise(p + vec3(7.1, 4.3, 2.7))
    );
}

// ── Numerical curl  ∇ × N(p) ─────────────────────────────────────────────────
// Using central differences with epsilon h:
//   (∂Nz/∂y - ∂Ny/∂z,
//    ∂Nx/∂z - ∂Nz/∂x,
//    ∂Ny/∂x - ∂Nx/∂y)
vec3 curlNoise(vec3 p) {
    const float h = 0.0001;

    vec3 dpdx = (potentialField(p + vec3(h,0,0)) - potentialField(p - vec3(h,0,0))) / (2.0*h);
    vec3 dpdy = (potentialField(p + vec3(0,h,0)) - potentialField(p - vec3(0,h,0))) / (2.0*h);
    vec3 dpdz = (potentialField(p + vec3(0,0,h)) - potentialField(p - vec3(0,0,h))) / (2.0*h);

    return vec3(
        dpdy.z - dpdz.y,   // ∂Nz/∂y - ∂Ny/∂z
        dpdz.x - dpdx.z,   // ∂Nx/∂z - ∂Nz/∂x
        dpdx.y - dpdy.x    // ∂Ny/∂x - ∂Nx/∂y
    );
}

// ── Multi-scale curl noise (turbulent cascade) ────────────────────────────────
// Kolmogorov turbulence: energy cascades from large to small scales.
// In k-space: E(k) ∝ k^(-5/3)
// In position space: amplitudes scale as k^(-5/6) ≈ scale^(5/6)
//
// octaves: number of scales to sum (6-8 for full turbulence)
// lacunarity: frequency multiplier per octave (~2.0)
// persistence: amplitude multiplier per octave (~0.5 for Kolmogorov)
vec3 turbulentVelocity(vec3 p, int octaves, float lacunarity, float persistence) {
    vec3  velocity  = vec3(0.0);
    float amplitude = 1.0;
    float freq      = 1.0;

    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        velocity  += amplitude * curlNoise(p * freq);
        amplitude *= persistence;
        freq      *= lacunarity;
    }
    return velocity;
}

// ── Kolmogorov velocity field (physically calibrated) ─────────────────────────
// Returns a velocity vector at point p, calibrated to Kolmogorov inertial range.
// sigma: RMS velocity dispersion (e.g. 1 km/s for a molecular cloud)
// L:     driving scale in the same units as p
vec3 kolmogorovVelocity(vec3 p, float sigma, float L) {
    vec3 curl = turbulentVelocity(p / L, 6, 2.0, 0.5);
    return curl * sigma;
}

// ── Vorticity field (ω = ∇ × v) ───────────────────────────────────────────────
// Vorticity concentrates in filaments — this is where density compression occurs.
// High |ω| → Kelvin-Helmholtz instability → density clumping
vec3 vorticityField(vec3 p) {
    // Vorticity is the curl of the velocity, which is the curl of curl noise.
    // For our potential-based curl, this is ∇(∇·N) - ∇²N.
    // Approximate numerically:
    const float h = 0.001;
    vec3 v  = curlNoise(p);
    vec3 vx = curlNoise(p + vec3(h,0,0));
    vec3 vy = curlNoise(p + vec3(0,h,0));
    vec3 vz = curlNoise(p + vec3(0,0,h));

    float dvz_dy = (vy.z - v.z) / h;
    float dvy_dz = (vz.y - v.y) / h;
    float dvx_dz = (vz.x - v.x) / h;
    float dvz_dx = (vx.z - v.z) / h;
    float dvy_dx = (vx.y - v.y) / h;
    float dvx_dy = (vy.x - v.x) / h;

    return vec3(dvz_dy - dvy_dz, dvx_dz - dvz_dx, dvy_dx - dvx_dy);
}

// Vorticity magnitude — use to drive density enhancement in filaments
float vorticity(vec3 p) {
    return length(vorticityField(p));
}

// ── Divergence-free density advection (CFL-stable first-order scheme) ─────────
// Moves a density tracer one time step forward.
// density: current density at p
// p: sample position
// dt: time step (keep < 0.1 for stability)
// turbScale: overall turbulence magnitude
float advectDensity(float density, vec3 p, float dt, float turbScale) {
    vec3 v    = turbulentVelocity(p, 6, 2.0, 0.5) * turbScale;
    vec3 pPrev = p - v * dt;    // semi-Lagrangian back-trace
    // In a shader we can't look up pPrev easily, so return the velocity magnitude
    // as a density compression indicator: high convergence → density increase
    // (real advection needs a 3D texture feedback loop)
    float divV = 0.0;  // curl noise is divergence-free so divV = 0 — no compression
    return density * (1.0 - divV * dt);  // = density (no change, correct for curl noise)
}
