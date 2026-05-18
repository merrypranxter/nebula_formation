#!/usr/bin/env python3
"""
reference_calculations.py
──────────────────────────
Astrophysical reference calculations for nebula_formation rendering.

Covers:
  1. Strömgren radius (ionization equilibrium)
  2. H-alpha luminosity → Star Formation Rate
  3. Jeans mass / Jeans length (gravitational instability)
  4. Sedov-Taylor blast wave radius (supernova remnant)
  5. Dust-to-gas ratio and visual extinction
  6. FBM / turbulence power spectrum parameters
  7. Emission line intensity ratios (temperature / density diagnostics)

Run directly:   python python/reference_calculations.py
Or import:      from python.reference_calculations import stromgren_radius

All quantities in CGS unless noted.  Physical constants at top.
"""

import math

# ─────────────────────────────────────────────────────────────────────────────
# Physical constants (CGS)
# ─────────────────────────────────────────────────────────────────────────────
c_light   = 2.998e10        # cm/s
k_B       = 1.381e-16       # erg/K  (Boltzmann)
m_H       = 1.673e-24       # g      (hydrogen mass)
m_e       = 9.109e-28       # g      (electron mass)
G         = 6.674e-8        # cm³/(g·s²)
pc        = 3.086e18        # cm/pc  (parsec)
M_sun     = 1.989e33        # g
L_sun     = 3.828e33        # erg/s
yr        = 3.156e7         # s/yr

# Case B recombination coefficient at T_e = 10^4 K
alpha_B   = 2.6e-13         # cm³/s


# ─────────────────────────────────────────────────────────────────────────────
# 1. Strömgren Radius
# ─────────────────────────────────────────────────────────────────────────────

def stromgren_radius(Q_H: float, n_H: float, alpha_B: float = alpha_B) -> float:
    """
    Strömgren radius of an H II region in parsecs.

    Parameters
    ----------
    Q_H     : float  — ionizing photon rate [s⁻¹]
                       O3V star: ~2×10⁵⁰  |  O5V: ~5×10⁴⁹  |  B0V: ~2×10⁴⁷
    n_H     : float  — hydrogen number density [cm⁻³]
    alpha_B : float  — Case B recombination coefficient [cm³/s], default 2.6×10⁻¹³

    Returns
    -------
    R_S : float  — Strömgren radius [pc]

    Physics
    -------
    In ionization equilibrium: ionization rate = recombination rate
        Q_H = (4/3)π R_S³ α_B n_H²
        R_S = (3 Q_H / 4π α_B n_H²)^(1/3)
    """
    R_cm = (3.0 * Q_H / (4.0 * math.pi * alpha_B * n_H**2)) ** (1.0/3.0)
    return R_cm / pc


def ionization_front_velocity(R_S_pc: float, t_yr: float) -> float:
    """
    Approximate D-type ionization front velocity at time t after Strömgren sphere forms.
    Uses the analytical solution for isothermal expansion.

    Returns velocity in km/s.
    """
    c_II  = 11.0       # km/s — isothermal sound speed in H II region at 10^4 K
    # R(t) = R_S * (1 + 7/4 * c_II * t / R_S)^(4/7)
    # dR/dt = c_II * (1 + 7/4 * c_II*t/R_S)^(-3/7)
    R_S_km = R_S_pc * pc / 1e5
    t_s    = t_yr * yr
    factor = 1.0 + (7.0/4.0) * c_II * t_s / R_S_km
    return c_II * factor**(-3.0/7.0)


# ─────────────────────────────────────────────────────────────────────────────
# 2. H-alpha Luminosity → Star Formation Rate
# ─────────────────────────────────────────────────────────────────────────────

def halpha_luminosity_to_sfr(L_halpha_erg_s: float) -> float:
    """
    Star Formation Rate from H-alpha luminosity.

    Calibration: Kennicutt 1998, ApJ 498, 541
        SFR [M☉/yr] = 7.9×10⁻⁴² × L(H-alpha) [erg/s]

    Valid for standard Salpeter IMF (0.1–100 M☉), solar metallicity.
    For Chabrier/Kroupa IMF, multiply by 0.63.
    """
    return 7.9e-42 * L_halpha_erg_s


def sfr_to_ionizing_luminosity(sfr_msun_yr: float) -> float:
    """
    Inverse: SFR → Q_H (ionizing photon rate).
    Q_H [s⁻¹] = SFR [M☉/yr] / 7.9×10⁻⁴² / (1.37×10⁻¹²)
    """
    return sfr_msun_yr * 7.31e53


# ─────────────────────────────────────────────────────────────────────────────
# 3. Jeans Mass and Jeans Length
# ─────────────────────────────────────────────────────────────────────────────

def jeans_length(T: float, n_H: float, mu: float = 2.3) -> float:
    """
    Jeans length λ_J in parsecs.

    Parameters
    ----------
    T   : float  — gas temperature [K]
    n_H : float  — number density of H nuclei [cm⁻³]
    mu  : float  — mean molecular weight (2.3 for molecular H₂+He, 0.5 for ionized H+He)

    λ_J = c_s × sqrt(π / G ρ)
        where c_s = sqrt(k_B T / μ m_H)  and  ρ = μ m_H n_H
    """
    c_s   = math.sqrt(k_B * T / (mu * m_H))   # isothermal sound speed [cm/s]
    rho   = mu * m_H * n_H                     # mass density [g/cm³]
    lJ_cm = c_s * math.sqrt(math.pi / (G * rho))
    return lJ_cm / pc


def jeans_mass(T: float, n_H: float, mu: float = 2.3) -> float:
    """
    Jeans mass M_J in solar masses.

    M_J = (4/3) π ρ (λ_J/2)³
        = (π/6) ρ λ_J³
    """
    rho  = mu * m_H * n_H
    lJ_cm = jeans_length(T, n_H, mu) * pc
    MJ_g  = (math.pi / 6.0) * rho * lJ_cm**3
    return MJ_g / M_sun


def freefall_time(n_H: float, mu: float = 2.3) -> float:
    """
    Free-fall time t_ff in years.
    t_ff = sqrt(3π / 32 G ρ)
    """
    rho  = mu * m_H * n_H
    tff_s = math.sqrt(3.0 * math.pi / (32.0 * G * rho))
    return tff_s / yr


# ─────────────────────────────────────────────────────────────────────────────
# 4. Sedov-Taylor Blast Wave
# ─────────────────────────────────────────────────────────────────────────────

def sedov_radius(E_51: float, n_0: float, t_yr: float) -> float:
    """
    Sedov-Taylor blast wave radius in parsecs.

    Parameters
    ----------
    E_51  : float  — explosion energy in units of 10⁵¹ erg (typical SN: 1.0)
    n_0   : float  — ambient density [cm⁻³]
    t_yr  : float  — time since explosion [yr]

    R ∝ (E/ρ)^(1/5) t^(2/5)   (Sedov 1959)
    """
    E_erg  = E_51 * 1e51
    rho_0  = n_0 * m_H             # g/cm³ (pure H approximation)
    t_s    = t_yr * yr
    R_cm   = 0.3 * (E_erg / rho_0)**0.2 * t_s**0.4    # Sedov solution constant ~0.3
    return R_cm / pc


def sedov_velocity(E_51: float, n_0: float, t_yr: float) -> float:
    """
    Sedov-Taylor blast wave velocity in km/s.
    V = (2/5) R / t
    """
    R_pc  = sedov_radius(E_51, n_0, t_yr)
    R_km  = R_pc * pc / 1e5
    t_s   = t_yr * yr
    return 0.4 * R_km / t_s


def sedov_temperature(E_51: float, n_0: float, t_yr: float) -> float:
    """
    Post-shock temperature in Kelvin.
    T_s = (3/16) mu m_H V²/k_B  (strong shock Rankine-Hugoniot)
    """
    V_cms = sedov_velocity(E_51, n_0, t_yr) * 1e5
    T = (3.0/16.0) * m_H * V_cms**2 / k_B     # assume mu=1 (pure H)
    return T


# ─────────────────────────────────────────────────────────────────────────────
# 5. Dust Extinction
# ─────────────────────────────────────────────────────────────────────────────

def visual_extinction_to_H_column(A_V: float) -> float:
    """
    Convert visual extinction A_V [mag] to H nucleon column density N_H [cm⁻²].
    Standard ISM: N_H / A_V ≈ 1.8×10²¹ cm⁻² mag⁻¹
    (Bohlin, Savage & Drake 1978; updated by Güver & Özel 2009: 2.21×10²¹)
    """
    return 2.21e21 * A_V


def extinction_wavelength(A_V: float, lambda_nm: float, R_V: float = 3.1) -> float:
    """
    Extinction at arbitrary wavelength using Cardelli, Clayton & Mathis (1989) law.
    Returns A(λ)/A(V) × A_V = A(λ) in magnitudes.

    Parameters
    ----------
    A_V       : float  — V-band extinction [mag]
    lambda_nm : float  — wavelength [nm]
    R_V       : float  — total-to-selective extinction ratio (ISM: 3.1, dense cloud: 5-6)
    """
    x = 1.0 / (lambda_nm * 1e-3)    # x in μm⁻¹

    if 1.1 <= x <= 3.3:    # optical/NIR
        y = x - 1.82
        a = 1.0 + 0.17699*y - 0.50447*y**2 - 0.02427*y**3 + 0.72085*y**4 \
            + 0.01979*y**5 - 0.77530*y**6 + 0.32999*y**7
        b =       1.41338*y + 2.28305*y**2 + 1.07233*y**3 - 5.38434*y**4 \
            - 0.62251*y**5 + 5.30260*y**6 - 2.09002*y**7
    elif 3.3 < x <= 8.0:   # UV
        fa = -0.0447*(x-5.9)**2 - 0.00978*(x-5.9)**3 if x >= 5.9 else 0.0
        fb =  0.2130*(x-5.9)**2 + 0.1207*(x-5.9)**3 if x >= 5.9 else 0.0
        a  = 1.752 - 0.316*x - 0.104/((x-4.67)**2+0.341) + fa
        b  = -3.090 + 1.825*x + 1.206/((x-4.62)**2+0.263) + fb
    else:
        # Rough power law outside CCM range
        a, b = (0.574*x**1.61), (-0.527*x**1.61)

    return (a + b/R_V) * A_V


def dust_rgb_attenuation(A_V: float, R_V: float = 3.1) -> tuple:
    """
    Returns (transmission_R, transmission_G, transmission_B) through A_V magnitudes.
    Uses R=640nm, G=550nm, B=440nm.
    Transmission = 10^(-0.4 × A(λ))
    """
    A_R = extinction_wavelength(A_V, 640, R_V)
    A_G = extinction_wavelength(A_V, 550, R_V)
    A_B = extinction_wavelength(A_V, 440, R_V)
    return (10**(-0.4*A_R), 10**(-0.4*A_G), 10**(-0.4*A_B))


# ─────────────────────────────────────────────────────────────────────────────
# 6. Turbulence and FBM Parameters
# ─────────────────────────────────────────────────────────────────────────────

def kolmogorov_velocity_dispersion(sigma_0: float, L_0: float, l: float) -> float:
    """
    Velocity dispersion at scale l (Kolmogorov turbulence).
    σ(l) = σ₀ × (l/L₀)^(1/3)

    Parameters
    ----------
    sigma_0 : float  — velocity dispersion at driving scale L_0 [km/s]
    L_0     : float  — driving scale [pc]
    l       : float  — target scale [pc]

    Returns velocity dispersion σ(l) [km/s].

    Note: Larson (1981) found σ ∝ R^0.38 observationally — slightly steeper.
    For H = 1/3 (Kolmogorov): fbm persistence = 0.63 per octave.
    For H = 0.38 (Larson): persistence ≈ 2^(-H) = 2^(-0.38) ≈ 0.77 per octave.
    """
    return sigma_0 * (l / L_0) ** (1.0/3.0)


def fbm_persistence_from_hurst(H: float) -> float:
    """
    FBM persistence (amplitude multiplier per octave) from Hurst exponent H.
    persistence = 2^(-H)

    Kolmogorov: H = 1/3  → persistence ≈ 0.794
    Brownian:   H = 0.5  → persistence ≈ 0.707
    Larson:     H = 0.38 → persistence ≈ 0.770
    """
    return 2.0**(-H)


def power_spectrum_slope(H: float) -> float:
    """
    3D power spectrum slope β from Hurst exponent H.
    P(k) ∝ k^(-β)  where β = 2H + 3
    Kolmogorov: β = 2×(1/3) + 3 = 11/3 ≈ 3.67
    """
    return 2.0*H + 3.0


# ─────────────────────────────────────────────────────────────────────────────
# 7. Emission Line Diagnostics
# ─────────────────────────────────────────────────────────────────────────────

def oiii_temperature(R_oiii: float) -> float:
    """
    Electron temperature from [O III] auroral/nebular ratio.
    R_OIII = I(436.3) / I(495.9 + 500.7)

    From Osterbrock & Ferland (2006), Astrophysics of Gaseous Nebulae.
    Approximate analytical form:
    T_e ≈ 1.432×10⁴ / ln(0.00333 / R)

    Valid range: T_e ~ 7000–20000 K.
    """
    if R_oiii <= 0:
        raise ValueError("R_oiii must be positive")
    return 1.432e4 / math.log(0.00333 / R_oiii)


def sii_density(R_sii: float) -> float:
    """
    Electron density from [S II] doublet ratio.
    R_SII = I(671.6) / I(673.1)

    Low-density limit: R → 1.45  (ne < 100 cm⁻³)
    High-density limit: R → 0.44 (ne > 10^4 cm⁻³)

    Approximate polynomial fit (valid 100 < ne < 10^4 cm⁻³):
    """
    R = R_sii
    R_lo, R_hi = 1.45, 0.44
    if R >= R_lo: return 10.0       # essentially zero density
    if R <= R_hi: return 1e5        # high density limit
    x = (R_lo - R) / (R_lo - R_hi)   # normalized 0→1 as n increases
    # Rough inversion of Osterbrock Table 5.3
    log_ne = x * 4.0                  # 10^0 to 10^4
    return 10**log_ne


def halpha_intensity(n_e: float, n_p: float, T_e: float) -> float:
    """
    H-alpha volume emissivity j(Hα) in erg/cm³/s/sr.
    j(Hα) = (hν_Hα / 4π) α_Hα^eff n_e n_p

    Parameters
    ----------
    n_e, n_p : float  — electron and proton densities [cm⁻³] (equal for pure H)
    T_e      : float  — electron temperature [K]

    Effective recombination coefficient (Case B, H-alpha):
    α_Hα^eff ≈ 1.17×10⁻¹³ × (T/10⁴)^(-0.942) cm³/s
    """
    E_halpha = 6.626e-27 * c_light / (656.3e-7)      # erg per photon
    alpha_Ha = 1.17e-13 * (T_e / 1e4)**(-0.942)       # cm³/s
    return (E_halpha / (4.0 * math.pi)) * alpha_Ha * n_e * n_p


# ─────────────────────────────────────────────────────────────────────────────
# CLI demo
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("NEBULA FORMATION — Reference Calculations")
    print("=" * 60)

    # ── Strömgren sphere ─────────────────────────────────────────────────────
    print("\n── Strömgren Sphere ─────────────────────────────────────")
    for star, Q_H in [("O3V",  2e50), ("O5V",  5e49), ("B0V",  2e47)]:
        for n, n_H in [("n=10", 10), ("n=100", 100), ("n=1000", 1000)]:
            R = stromgren_radius(Q_H, n_H)
            print(f"  {star} {n:8s}: R_S = {R:.2f} pc")

    # ── Jeans collapse ───────────────────────────────────────────────────────
    print("\n── Jeans Instability (molecular cloud, T=10K) ──────────")
    for nH in [100, 1000, 10000, 1e5]:
        MJ = jeans_mass(T=10, n_H=nH)
        lJ = jeans_length(T=10, n_H=nH)
        tff = freefall_time(nH)
        print(f"  n={nH:.0e} cm⁻³: M_J={MJ:.2f} M☉  λ_J={lJ*1000:.0f} mpc  t_ff={tff/1e6:.2f} Myr")

    # ── Supernova remnant ────────────────────────────────────────────────────
    print("\n── Sedov-Taylor Blast Wave (E=10⁵¹ erg, n₀=1 cm⁻³) ────")
    for t_yr in [100, 1000, 10000, 50000]:
        R  = sedov_radius(1.0, 1.0, t_yr)
        V  = sedov_velocity(1.0, 1.0, t_yr)
        T  = sedov_temperature(1.0, 1.0, t_yr)
        print(f"  t={t_yr:6d} yr: R={R:.1f} pc  V={V:.0f} km/s  T={T:.1e} K")

    # ── Dust extinction ──────────────────────────────────────────────────────
    print("\n── Dust Extinction ──────────────────────────────────────")
    print("  A_V  | T_R   T_G   T_B   (transmission per channel)")
    for AV in [0.5, 1.0, 2.0, 5.0, 10.0]:
        TR, TG, TB = dust_rgb_attenuation(AV)
        print(f"  {AV:4.1f}  | {TR:.3f}  {TG:.3f}  {TB:.3f}")

    # ── FBM parameters ───────────────────────────────────────────────────────
    print("\n── FBM Turbulence Parameters ────────────────────────────")
    for H, name in [(1/3, "Kolmogorov"), (0.38, "Larson"), (0.5, "Brownian")]:
        p = fbm_persistence_from_hurst(H)
        beta = power_spectrum_slope(H)
        print(f"  {name:12s}: H={H:.3f}  persistence={p:.4f}  β={beta:.3f}")

    # ── Kolmogorov velocity dispersion ───────────────────────────────────────
    print("\n── Kolmogorov Velocity Dispersion (σ₀=3 km/s at L₀=10 pc) ─")
    for l in [0.01, 0.1, 1.0, 10.0]:
        sigma = kolmogorov_velocity_dispersion(3.0, 10.0, l)
        print(f"  l={l:5.2f} pc:  σ = {sigma:.3f} km/s")

    print("\n")
