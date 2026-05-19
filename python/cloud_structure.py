#!/usr/bin/env python3
"""
cloud_structure.py
──────────────────
Molecular cloud structure calculations for nebula_formation rendering.

Covers:
  1. Clump mass function (CMF): distribution of clump masses
  2. Column density grid: 2D projected density map for visualization
  3. Turbulent density field: lognormal density statistics
  4. Filament model: line-mass, critical line-mass (Inutsuka & Miyama 1997)
  5. Jeans hierarchy: nested fragmentation structure
  6. Cloud mass spectrum: Larson's mass-size relation
  7. Self-similar cloud structure for shader parameter derivation

Run directly:   python python/cloud_structure.py
Or import:      from python.cloud_structure import MolecularCloud

All physical quantities in CGS unless noted.
References:
  Larson 1981, MNRAS 194, 809
  McKee & Ostriker 2007, ARA&A 45, 565
  André et al. 2014, Protostars and Planets VI
  Padoan & Nordlund 2011, ApJ 730, 40 (turbulent density PDF)
"""

import math
import random
import sys

# ─────────────────────────────────────────────────────────────────────────────
# Physical constants
# ─────────────────────────────────────────────────────────────────────────────
k_B   = 1.381e-16    # erg/K
m_H   = 1.673e-24    # g
G     = 6.674e-8     # cm³/(g·s²)
pc    = 3.086e18     # cm/pc
M_sun = 1.989e33     # g
yr    = 3.156e7      # s/yr


# ─────────────────────────────────────────────────────────────────────────────
# 1. Clump Mass Function
# ─────────────────────────────────────────────────────────────────────────────

def clump_mass_function(M: float, alpha: float = 1.7, M_min: float = 0.1,
                        M_max: float = 1000.0) -> float:
    """
    Clump mass function dN/dM ∝ M^(-alpha) for a molecular cloud.

    Parameters
    ----------
    M     : float — clump mass in solar masses
    alpha : float — power law slope.  Observed: 1.5–2.0 (Blitz 1993, Kramer 1998)
                    alpha ~ 1.7 for most molecular clouds.
                    alpha ~ 2.35 (Salpeter) for stellar mass function.
    M_min, M_max : float — mass range limits [M☉]

    Returns dN/dM (unnormalized).

    Note: The Bonnell-Bate competitive accretion model and IMF origin:
    The CMF shapes the IMF through fragmentation and accretion.
    CMF slope alpha ~ 1.7 translates to stellar IMF slope gamma ~ 2.35 after
    a ~30% accretion efficiency.
    """
    if M < M_min or M > M_max:
        return 0.0
    return M**(-alpha)


def sample_clump_masses(n_clumps: int, alpha: float = 1.7,
                        M_min: float = 0.1, M_max: float = 100.0,
                        seed: int = 42) -> list:
    """
    Sample N clump masses from a power-law CMF using the inverse CDF method.

    Returns list of masses in solar masses.

    Method: For dN/dM ∝ M^(-alpha), the CDF:
        CDF(M) = (M^(1-alpha) - M_min^(1-alpha)) / (M_max^(1-alpha) - M_min^(1-alpha))
    Invert: M = [u * (M_max^(1-alpha) - M_min^(1-alpha)) + M_min^(1-alpha)]^(1/(1-alpha))
    """
    rng  = random.Random(seed)
    beta = 1.0 - alpha    # note: alpha > 1 → beta < 0

    # Handle alpha = 1 separately (log uniform)
    if abs(beta) < 1e-6:
        masses = [M_min * math.exp(rng.random() * math.log(M_max/M_min))
                  for _ in range(n_clumps)]
    else:
        cdf_lo  = M_min**beta
        cdf_hi  = M_max**beta
        masses  = []
        for _ in range(n_clumps):
            u = rng.random()
            M = (u * (cdf_hi - cdf_lo) + cdf_lo) ** (1.0 / beta)
            masses.append(M)

    return sorted(masses, reverse=True)


# ─────────────────────────────────────────────────────────────────────────────
# 2. Turbulent Density Statistics (lognormal PDF)
# ─────────────────────────────────────────────────────────────────────────────

def lognormal_sigma(mach: float, b: float = 0.33) -> float:
    """
    Standard deviation of the lognormal density PDF for supersonic turbulence.

    σ_s² = ln(1 + b² M²)    (Padoan & Nordlund 1997, Price & Federrath 2010)

    Parameters
    ----------
    mach : float — sonic Mach number M = σ_v / c_s
    b    : float — driving parameter. b = 1/3 (solenoidal, curl-type forcing)
                                       b = 1   (compressive, divergence-type forcing)

    Returns σ_s = std of ln(ρ/ρ_0).
    """
    return math.sqrt(math.log(1.0 + b*b * mach*mach))


def lognormal_mean(mach: float, b: float = 0.33) -> float:
    """
    Mean of the lognormal density PDF (mass-weighted).
    For a lognormal with σ_s: mean(ln ρ) = -σ_s²/2 (to conserve mass).
    """
    sigma = lognormal_sigma(mach, b)
    return -sigma**2 / 2.0


def density_contrast(mach: float, b: float = 0.33, percentile: float = 0.99) -> float:
    """
    Density contrast for the given percentile of the PDF.
    Returns ρ/ρ_0 at the specified percentile.

    For mach=10 (typical massive cloud): 99th percentile can reach ρ/ρ_0 ~ 1000.
    This justifies the large density range in our shaders.
    """
    import math
    sigma = lognormal_sigma(mach, b)
    mu    = lognormal_mean(mach, b)
    # Inverse of normal CDF at percentile (using a simple rational approximation)
    # For standard normal: p → z
    # Simple lookup: p=0.99 → z=2.326, p=0.999 → z=3.090, p=0.9999 → z=3.719
    z_table = {0.75: 0.674, 0.90: 1.282, 0.95: 1.645,
               0.99: 2.326, 0.999: 3.090, 0.9999: 3.719}
    z = z_table.get(percentile, 2.326)
    ln_rho = mu + sigma * z
    return math.exp(ln_rho)


# ─────────────────────────────────────────────────────────────────────────────
# 3. Filament Structure (Inutsuka-Miyama Isothermal Cylinder)
# ─────────────────────────────────────────────────────────────────────────────

def filament_critical_line_mass(c_s_kms: float) -> float:
    """
    Critical line-mass of an isothermal self-gravitating filament.
    
    (M/L)_crit = 2 c_s² / G

    Above this, the filament is gravitationally unstable and fragments.
    Below this, it is stable against radial collapse.

    Parameters
    ----------
    c_s_kms : float — isothermal sound speed [km/s].
                       At T=10K: c_s = sqrt(kT/mu*mH) = 0.19 km/s for mu=2.3

    Returns critical line-mass in M☉/pc.
    """
    c_s_cgs = c_s_kms * 1e5    # km/s → cm/s
    ML_cgs  = 2.0 * c_s_cgs**2 / G    # g/cm
    ML_sunpc = ML_cgs * pc / M_sun     # M☉/pc
    return ML_sunpc


def filament_fragmentation_spacing(c_s_kms: float, n_c: float) -> float:
    """
    Preferred fragmentation spacing along a critical filament.
    λ_frag ≈ 4 × (2 c_s² / G ρ_c)^(1/2) = 4 × Jeans length at central density.

    Returns fragmentation wavelength in pc.

    This sets the spacing of prestellar cores along the filament —
    the "beads on a string" observed by Herschel.
    """
    c_s_cgs = c_s_kms * 1e5
    rho_c   = n_c * 2.3 * m_H     # mass density at filament center
    # Jeans length at filament center density
    l_J     = c_s_cgs * math.sqrt(math.pi / (G * rho_c))
    return (4.0 * l_J / pc)       # fragmentation spacing ≈ 4 × Jeans length


def filament_radial_profile(r_pc: float, r_flat_pc: float, n_c: float) -> float:
    """
    Ostriker (1964) isothermal cylinder radial profile.
    n(r) = n_c / (1 + (r / r_flat)²)²

    Parameters
    ----------
    r_pc     : float — radius from filament spine [pc]
    r_flat_pc: float — flat inner radius (~0.03–0.05 pc; the observed ~0.1pc width
                       corresponds to r_flat where the profile begins to fall off)
    n_c      : float — central number density [cm⁻³]

    Returns number density at radius r [cm⁻³].
    """
    x = r_pc / r_flat_pc
    return n_c / (1.0 + x*x)**2


# ─────────────────────────────────────────────────────────────────────────────
# 4. Larson's Mass-Size Relation
# ─────────────────────────────────────────────────────────────────────────────

def larson_velocity(R_pc: float, sigma_0_kms: float = 1.0, R_0_pc: float = 1.0) -> float:
    """
    Larson (1981) velocity-size relation: σ_v ∝ R^0.38.
    Returns 1D velocity dispersion in km/s.
    """
    return sigma_0_kms * (R_pc / R_0_pc) ** 0.38


def larson_mass(R_pc: float, M_0_msun: float = 500.0, R_0_pc: float = 1.0) -> float:
    """
    Larson (1981) mass-size relation: M ∝ R^1.97.
    Returns cloud mass in solar masses.
    """
    return M_0_msun * (R_pc / R_0_pc) ** 1.97


def mean_column_density(M_msun: float, R_pc: float) -> float:
    """
    Mean H column density N_H from cloud mass and radius.
    N_H = M / (pi * R² * mu * m_H)

    Returns N_H [cm⁻²].
    """
    M_g   = M_msun * M_sun
    R_cm  = R_pc * pc
    return M_g / (math.pi * R_cm**2 * 2.3 * m_H)


def visual_extinction_from_column(N_H: float) -> float:
    """
    Visual extinction A_V from H column density.
    N_H / A_V ≈ 2.21×10²¹ cm⁻² mag⁻¹ (Güver & Özel 2009).
    Returns A_V [mag].
    """
    return N_H / 2.21e21


# ─────────────────────────────────────────────────────────────────────────────
# 5. MolecularCloud class: self-contained cloud structure model
# ─────────────────────────────────────────────────────────────────────────────

class MolecularCloud:
    """
    Simple 1D/analytical model of a molecular cloud for shader parameterization.

    Computes:
      - Cloud mass, size, temperature, Mach number
      - Density statistics (lognormal PDF)
      - Filament and core properties
      - Derived shader parameters

    Example usage:
        cloud = MolecularCloud(mass_msun=1000, radius_pc=5.0, T_K=15)
        params = cloud.shader_params()
        print(params)
    """

    def __init__(self, mass_msun: float = 1000.0, radius_pc: float = 5.0,
                 T_K: float = 15.0, mach: float = 8.0, mu: float = 2.3):
        self.mass    = mass_msun   # M☉
        self.radius  = radius_pc   # pc
        self.T       = T_K         # K
        self.mach    = mach        # sonic Mach number
        self.mu      = mu          # mean molecular weight

    @property
    def sound_speed(self) -> float:
        """Isothermal sound speed [km/s]"""
        c = math.sqrt(k_B * self.T / (self.mu * m_H))
        return c / 1e5    # cm/s → km/s

    @property
    def mean_density(self) -> float:
        """Volume-average number density [cm⁻³]"""
        M_g  = self.mass * M_sun
        R_cm = self.radius * pc
        rho  = M_g / (4.0/3.0 * math.pi * R_cm**3)
        return rho / (self.mu * m_H)

    @property
    def sigma_v(self) -> float:
        """3D velocity dispersion [km/s]"""
        return self.mach * self.sound_speed

    @property
    def density_sigma(self) -> float:
        """σ_s: std of lognormal density distribution"""
        return lognormal_sigma(self.mach)

    @property
    def density_contrast_99(self) -> float:
        """99th percentile density relative to mean"""
        return density_contrast(self.mach, percentile=0.99)

    @property
    def critical_line_mass(self) -> float:
        """Critical filament line-mass [M☉/pc]"""
        return filament_critical_line_mass(self.sound_speed)

    @property
    def freefall_time(self) -> float:
        """Free-fall time [Myr]"""
        n    = self.mean_density
        rho  = n * self.mu * m_H
        tff  = math.sqrt(3.0 * math.pi / (32.0 * G * rho))
        return tff / yr / 1e6   # s → Myr

    @property
    def alpha_vir(self) -> float:
        """Virial parameter: α = 5σ_v² R / G M"""
        sigma_v_cms = self.sigma_v * 1e5
        R_cm        = self.radius * pc
        M_g         = self.mass * M_sun
        return 5.0 * sigma_v_cms**2 * R_cm / (G * M_g)

    @property
    def star_formation_efficiency(self) -> float:
        """
        Estimated star formation efficiency per free-fall time.
        Multi-freefall model (Padoan & Nordlund 2011):
        SFE_ff ≈ 0.01 × exp(-1.6/alpha_vir^0.5)
        """
        return 0.01 * math.exp(-1.6 / max(self.alpha_vir, 0.01)**0.5)

    def shader_params(self) -> dict:
        """
        Derive recommended shader parameters for this cloud.
        Maps physical cloud properties to uTurbulence, uDensityScale, etc.
        """
        # Turbulence scale: higher Mach → more turbulence → higher uTurbulence
        turb = 0.5 + (self.mach - 2.0) / 20.0 * 2.0   # maps M=2→0.5, M=22→2.5
        turb = max(0.1, min(3.0, turb))

        # Density scale: higher mean density → higher uDensityScale
        dens = 0.5 + math.log10(max(self.mean_density, 1.0)) / 5.0
        dens = max(0.1, min(5.0, dens))

        # Dust opacity: A_V from mean column density
        N_H = mean_column_density(self.mass, self.radius)
        A_V = visual_extinction_from_column(N_H)
        dust = min(A_V / 3.0, 2.0)   # A_V=3 → uDustOpacity=1.0

        # Emission: star formation rate proxy (young cloud = lower emission)
        emission = 0.5 + self.star_formation_efficiency * 100.0
        emission = min(emission, 3.0)

        return {
            'uTurbulence':   round(turb, 2),
            'uDensityScale': round(dens, 2),
            'uDustOpacity':  round(dust, 2),
            'uEmission':     round(emission, 2),
            'cloud_mass_msun': self.mass,
            'radius_pc':       self.radius,
            'mean_density_cm3': round(self.mean_density, 1),
            'sound_speed_kms':  round(self.sound_speed, 3),
            'sigma_v_kms':      round(self.sigma_v, 2),
            'freefall_Myr':     round(self.freefall_time, 2),
            'alpha_vir':        round(self.alpha_vir, 2),
            'density_contrast99x': round(self.density_contrast_99, 0),
            'sfe_per_ff':       f"{self.star_formation_efficiency:.4f}",
        }

    def __repr__(self) -> str:
        return (f"MolecularCloud({self.mass:.0f} M☉, R={self.radius} pc, "
                f"T={self.T}K, M={self.mach})")


# ─────────────────────────────────────────────────────────────────────────────
# 6. Column density map (2D projection)
# ─────────────────────────────────────────────────────────────────────────────

def column_density_map(cloud: MolecularCloud, nx: int = 40, ny: int = 20,
                       seed: int = 42) -> list:
    """
    Generate a crude 2D column density map for ASCII display.
    Uses a simple Monte Carlo: sample random lines of sight through the cloud
    and integrate a Kolmogorov density field.

    Returns a list of nx*ny values, each = column density relative to mean.
    """
    rng = random.Random(seed)

    # Generate N density clumps
    n_clumps = 30
    clumps = []
    for _ in range(n_clumps):
        x  = rng.gauss(0, cloud.radius * 0.4)
        y  = rng.gauss(0, cloud.radius * 0.4)
        z  = rng.gauss(0, cloud.radius * 0.4)
        M  = rng.expovariate(1.0 / (cloud.mass / n_clumps))   # exponential mass dist
        r  = (M / (n_clumps * 0.1)) ** (1/3.0) * cloud.radius * 0.3
        clumps.append((x, y, z, M, r))

    grid = []
    half_x = cloud.radius * 0.8
    half_y = cloud.radius * 0.6
    for j in range(ny):
        for i in range(nx):
            xi = (i / (nx-1) - 0.5) * 2.0 * half_x
            yj = (j / (ny-1) - 0.5) * 2.0 * half_y
            # Integrate along z
            N = 0.0
            for (cx, cy, cz, cM, cr) in clumps:
                dx = xi - cx
                dy = yj - cy
                impact2 = dx*dx + dy*dy
                if impact2 < cr*cr:
                    chord = 2.0 * math.sqrt(max(0.0, cr*cr - impact2))
                    N += cM / (math.pi * cr*cr) * chord
            grid.append(N)
    return grid


def ascii_column_map(cloud: MolecularCloud, nx: int = 60, ny: int = 24) -> None:
    """Print an ASCII column density map of the molecular cloud."""
    grid = column_density_map(cloud, nx=nx, ny=ny)
    if not grid:
        return
    vmax = max(grid) or 1.0
    # Palette: empty → dense (false color: cold=·, warm=+, hot=★)
    chars = " .·:+*#★"
    print(f"\n  Column Density Map — {cloud}")
    print(f"  {'─'*nx}")
    for j in range(ny-1, -1, -1):
        row = ""
        for i in range(nx):
            v = grid[j*nx + i] / vmax
            idx = int(v * (len(chars)-1))
            row += chars[idx]
        print(f"  |{row}|")
    print(f"  {'─'*nx}")
    print(f"  Scale: ' '=0  '★'={vmax:.1f} M☉·pc⁻² (projected)")


# ─────────────────────────────────────────────────────────────────────────────
# CLI demo
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 65)
    print("NEBULA FORMATION — Molecular Cloud Structure")
    print("=" * 65)

    # ── Cloud survey ──────────────────────────────────────────────────────────
    print("\n── Molecular Cloud Parameter Survey ────────────────────────")
    print(f"  {'Cloud':20s}  {'n_mean':>8}  {'M':>5}  {'σ_v':>6}  {'α_vir':>6}  {'t_ff':>6}  "
          f"{'SFE_ff':>8}  {'ρ99/ρ0':>8}")
    clouds = [
        ("Low-mass (Taurus)",    MolecularCloud(100,   2.0,  10,  3)),
        ("Moderate (ρ Oph)",     MolecularCloud(1000,  5.0,  15,  6)),
        ("GMC (Orion A)",        MolecularCloud(1e5,  50.0,  20, 10)),
        ("Massive (Carina)",     MolecularCloud(1e6, 100.0,  25, 15)),
        ("Starburst (NGC 253)",  MolecularCloud(1e7, 300.0,  30, 20)),
    ]
    for name, c in clouds:
        print(f"  {name:20s}  {c.mean_density:8.1f}  {c.mach:5.0f}  {c.sigma_v:6.1f}  "
              f"{c.alpha_vir:6.2f}  {c.freefall_time:6.2f}  "
              f"{c.star_formation_efficiency:8.4f}  {c.density_contrast_99:8.0f}x")

    # ── Shader parameters for example clouds ─────────────────────────────────
    print("\n── Derived Shader Parameters ────────────────────────────────")
    for name, c in clouds[:3]:
        p = c.shader_params()
        print(f"\n  {name}:")
        for k, v in p.items():
            if not k.startswith('cloud') and not k.endswith('pc'):
                print(f"    {k:20s} = {v}")

    # ── Filament critical line masses ─────────────────────────────────────────
    print("\n── Filament Critical Line-Masses ────────────────────────────")
    print(f"  {'T [K]':>7}  {'c_s [km/s]':>11}  {'(M/L)_crit [M☉/pc]':>22}  "
          f"{'λ_frag (n=10⁴cm⁻³) [pc]':>25}")
    for T in [10, 15, 20, 30, 50, 100]:
        c_s = math.sqrt(k_B*T/(2.3*m_H)) / 1e5
        ML  = filament_critical_line_mass(c_s)
        lf  = filament_fragmentation_spacing(c_s, 1e4)
        print(f"  {T:7.0f}  {c_s:11.3f}  {ML:22.1f}  {lf:25.3f}")

    # ── Clump mass function ───────────────────────────────────────────────────
    print("\n── Clump Mass Function (alpha=1.7, 50 clumps in 0.1–100 M☉) ─")
    masses = sample_clump_masses(50, alpha=1.7, M_min=0.1, M_max=100.0)
    bins = [0.1, 0.5, 1.0, 3.0, 10.0, 30.0, 100.0]
    for lo, hi in zip(bins[:-1], bins[1:]):
        count = sum(1 for m in masses if lo <= m < hi)
        bar = "█" * count
        print(f"  {lo:5.1f}–{hi:5.1f} M☉: {bar} ({count})")

    # ── Column density map ────────────────────────────────────────────────────
    c_display = MolecularCloud(1000, 5.0, 15, 6)
    ascii_column_map(c_display, nx=60, ny=20)

    print()
