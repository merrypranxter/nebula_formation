#!/usr/bin/env python3
"""
emission_spectrum.py
────────────────────
Full optical emission spectrum calculator for ionized nebulae.

Given electron temperature T_e, electron density n_e, and ionic abundances,
computes the relative intensities of all major optical emission lines.
Outputs a spectrum that can be directly used to calibrate shader emission colors.

Covers:
  1. Hydrogen recombination lines (Balmer series)
  2. [O III] collisionally excited lines (500.7 + 495.9 + auroral 436.3 nm)
  3. [O II] collisionally excited lines (372.7 nm doublet)
  4. [N II] lines (654.8 + 658.4 nm)
  5. [S II] doublet (671.6 + 673.1 nm)
  6. [S III] near-IR lines
  7. He I and He II recombination
  8. [O I] forbidden line (630.0 nm)

All emissivities relative to H-beta = 1.0 (standard astronomical convention).
Includes intrinsic Balmer decrement and reddening correction.

Run:    python python/emission_spectrum.py
        python python/emission_spectrum.py --Te 12000 --ne 500 --plot

References:
  Osterbrock & Ferland (2006) Astrophysics of Gaseous Nebulae (AGN2)
  Storey & Hummer (1995) MNRAS 272, 41 — Hydrogen recombination coefficients
  Luridiana, Morisset & Shaw (2015) PASP 127, 1 — PyNeb
"""

import math
import argparse

# ─────────────────────────────────────────────────────────────────────────────
# Physical constants
# ─────────────────────────────────────────────────────────────────────────────
k_B     = 1.381e-16    # erg/K
h_plank = 6.626e-27    # erg·s
c_light = 2.998e10     # cm/s


def photon_energy(lambda_nm: float) -> float:
    """Energy of a photon at wavelength lambda [nm] in erg."""
    return h_plank * c_light / (lambda_nm * 1e-7)


# ─────────────────────────────────────────────────────────────────────────────
# Line data: (name, lambda_nm, type)
# ─────────────────────────────────────────────────────────────────────────────

LINES = [
    # Hydrogen Balmer series
    ("H_alpha",  656.28, "H_recomb"),
    ("H_beta",   486.13, "H_recomb"),
    ("H_gamma",  434.05, "H_recomb"),
    ("H_delta",  410.17, "H_recomb"),

    # Oxygen forbidden
    ("[O III] 500.7", 500.68, "OIII"),
    ("[O III] 495.9", 495.89, "OIII"),
    ("[O III] 436.3", 436.32, "OIII_auroral"),
    ("[O II] 372.7",  372.70, "OII"),
    ("[O II] 372.9",  372.98, "OII"),
    ("[O I] 630.0",   630.03, "OI"),
    ("[O I] 636.4",   636.38, "OI"),

    # Nitrogen
    ("[N II] 658.3", 658.34, "NII"),
    ("[N II] 654.8", 654.80, "NII"),
    ("[N II] 575.5", 575.46, "NII_auroral"),

    # Sulfur
    ("[S II] 671.6", 671.64, "SII"),
    ("[S II] 673.1", 673.08, "SII"),
    ("[S III] 906.9", 906.86, "SIII"),
    ("[S III] 953.1", 953.10, "SIII"),

    # Argon
    ("[Ar III] 713.6", 713.58, "ArIII"),
    ("[Ar IV] 471.1",  471.11, "ArIV"),

    # Helium
    ("He I 587.6",  587.56, "HeI"),
    ("He I 447.1",  447.15, "HeI"),
    ("He II 468.6", 468.57, "HeII"),
    ("He II 164.0", 164.00, "HeII"),
]


# ─────────────────────────────────────────────────────────────────────────────
# 1. Hydrogen recombination emissivities
# ─────────────────────────────────────────────────────────────────────────────

def balmer_emissivity(upper_n: int, T_e: float, n_e: float) -> float:
    """
    Balmer line emissivity relative to H-beta, Case B recombination.
    
    Uses the power-law fit from Storey & Hummer (1995) for T_e = 5000–20000 K,
    n_e = 100–10^4 cm^-3:
    
    j(Hn) / j(Hβ) = A × (T_e/10^4)^(-B) × (n_e/100)^(C)
    
    For lines n > 7: scaling is essentially purely temperature-dependent.

    Parameters
    ----------
    upper_n : int   — upper level (3=Hα, 4=Hβ, 5=Hγ, 6=Hδ)
    T_e     : float — electron temperature [K]
    n_e     : float — electron density [cm⁻³]

    Returns emissivity relative to H-beta.
    """
    # Coefficients from AGN2 Table 4.2 + Hummer & Storey 1987
    # (A, T_power, n_power) for Balmer lines upper_n = 3..8
    # Values are j(Hn)/j(Hβ) at T=10^4 K, n_e=100 cm^-3
    # then multiplied by temperature and density correction
    coeffs = {
        3: (2.863, -0.114, 0.005),   # H-alpha
        4: (1.000,  0.000, 0.000),   # H-beta (reference)
        5: (0.469, +0.090, 0.003),   # H-gamma
        6: (0.259, +0.170, 0.003),   # H-delta
        7: (0.159, +0.230, 0.002),
        8: (0.104, +0.270, 0.001),
        9: (0.071, +0.300, 0.001),
    }
    if upper_n not in coeffs:
        # Approximate for high-n: j ∝ n^(-3) for Balmer series
        A = 2.863 / upper_n**3 * 9
        return A
    A, beta_T, beta_n = coeffs[upper_n]
    # Temperature correction
    T_corr = (T_e / 1e4) ** (-beta_T)
    # Density correction (small in low-density regime)
    n_corr = (n_e / 100.0) ** beta_n
    return A * T_corr * n_corr


def balmer_decrement(T_e: float, n_e: float) -> dict:
    """
    Returns the Balmer decrement: {line_name: I/I(Hβ)} for Hα through Hδ.
    """
    return {
        'H_alpha': balmer_emissivity(3, T_e, n_e),
        'H_beta':  1.000,
        'H_gamma': balmer_emissivity(5, T_e, n_e),
        'H_delta': balmer_emissivity(6, T_e, n_e),
    }


# ─────────────────────────────────────────────────────────────────────────────
# 2. Collisionally excited forbidden lines
# ─────────────────────────────────────────────────────────────────────────────

def collisional_emissivity(ion: str, T_e: float, n_e: float,
                           abundance: float, n_e_ref: float = 100.0) -> float:
    """
    Collisionally excited line emissivity relative to H-beta.

    The emissivity follows:
        j ∝ abundance × n_e × q_c(T_e) × exp(-E/kT)
    where q_c = A × T^(-0.5) is the collisional excitation rate.

    Includes density suppression for forbidden lines (quenching at n > n_crit).

    Parameters
    ----------
    ion       : str   — ion name: 'OIII', 'OII', 'OI', 'NII', 'SII', 'SIII', etc.
    T_e       : float — electron temperature [K]
    n_e       : float — electron density [cm⁻³]
    abundance : float — ionic abundance relative to H (e.g. O²⁺/H = 5e-4 × metallicity)
    n_e_ref   : float — reference density for normalization

    Returns j(line) / j(H-beta) at given conditions.
    """
    # Ion data: (excitation energy in eV, critical density cm^-3, rate coeff A_q)
    # From AGN2 and NIST atomic data
    ion_data = {
        'OIII':       (2.487, 6.8e5, 3.2e-8),   # [O III] 500.7nm, E=hc/500.7nm
        'OIII_aur':   (3.40,  6.8e5, 2.0e-8),   # [O III] 436.3nm (auroral)
        'OII':        (3.34,  3.2e3, 2.5e-8),   # [O II] 372.7nm
        'OI':         (1.97,  1.8e6, 1.8e-8),   # [O I] 630.0nm
        'NII':        (1.89,  8.6e4, 2.8e-8),   # [N II] 658.3nm
        'SII':        (1.84,  1.5e3, 3.0e-8),   # [S II] 671.6nm
        'SIII':       (1.34,  1.5e4, 3.5e-8),   # [S III] 906nm
        'ArIII':      (1.74,  1.3e5, 3.0e-8),   # [Ar III] 713nm
        'HeI':        (21.22, 1e8,   2.5e-11),  # He I 587nm (recomb-dominated, rough)
    }

    if ion not in ion_data:
        return 0.0

    E_eV, n_crit, A_q = ion_data[ion]
    E_erg = E_eV * 1.602e-12    # eV → erg

    # Collisional excitation rate: q ∝ T^(-0.5) exp(-E/kT)
    q = A_q * T_e**(-0.5) * math.exp(-E_erg / (k_B * T_e))

    # Density suppression of forbidden line (collisional de-excitation)
    density_factor = 1.0 / (1.0 + n_e / n_crit)

    # Emissivity: j_line ∝ abundance × n_e × q × E_line × density_factor
    j_line = abundance * n_e * q * E_erg * density_factor

    # H-beta emissivity for normalization
    # j(Hβ) = (h*nu_Hβ / 4π) × alpha_Hβ × n_e²
    E_Hb     = photon_energy(486.13)
    alpha_Hb = 3.03e-14 * (T_e / 1e4)**(-0.874)   # Case B Hβ recombination coefficient
    j_Hbeta  = E_Hb * alpha_Hb * n_e_ref**2 / (4.0 * math.pi)

    return j_line / max(j_Hbeta, 1e-100)


# ─────────────────────────────────────────────────────────────────────────────
# 3. Full spectrum computation
# ─────────────────────────────────────────────────────────────────────────────

# Default ionic abundances relative to H (solar, typical H II region)
SOLAR_ABUNDANCES = {
    'O2plus':  4.0e-4,   # O²⁺/H (O III): varies with ionization parameter
    'Oplus':   1.5e-4,   # O⁺/H (O II): in lower-ionization zones
    'O0':      1.0e-6,   # O⁰/H (O I): at ionization front only
    'N0':      3.0e-4,   # N total/H
    'Nplus':   2.5e-4,   # N⁺/H (N II)
    'S0':      3.0e-5,   # S total/H
    'Splus':   2.0e-5,   # S⁺/H (S II)
    'S2plus':  1.5e-5,   # S²⁺/H (S III)
    'Ar2plus': 6.3e-6,   # Ar²⁺/H (Ar III)
    'He':      0.10,     # He/H by number
}


def compute_spectrum(T_e: float, n_e: float,
                     metallicity: float = 1.0,
                     ionization_param: float = 0.5) -> list:
    """
    Compute full emission spectrum as list of (line_name, wavelength_nm, intensity/Hbeta).

    Parameters
    ----------
    T_e              : float — electron temperature [K] (8000–15000 typical)
    n_e              : float — electron density [cm⁻³] (10–10^4 typical)
    metallicity      : float — metallicity relative to solar (0.1–2.0)
    ionization_param : float — ionization state [0,1].
                                0 = low ionization (S II, N II dominate)
                                1 = high ionization (O III, He II dominate)

    Returns sorted list of (name, lambda_nm, intensity/Hβ).
    """
    abund = dict(SOLAR_ABUNDANCES)
    # Scale metal abundances
    for k in ['O2plus', 'Oplus', 'O0', 'N0', 'Nplus', 'S0', 'Splus', 'S2plus', 'Ar2plus']:
        abund[k] *= metallicity

    # Ionization structure: higher U → more O²⁺, less O⁺, less S⁺
    abund['O2plus'] *= ionization_param
    abund['Oplus']  *= (1.0 - ionization_param * 0.7)
    abund['Splus']  *= (1.0 - ionization_param * 0.8)
    abund['Nplus']  *= (1.0 - ionization_param * 0.5)
    abund['S2plus'] *= ionization_param * 0.5

    result = []

    # Hydrogen Balmer lines
    for upper_n, name, lam in [(3, "H_alpha", 656.28), (4, "H_beta", 486.13),
                                (5, "H_gamma", 434.05), (6, "H_delta", 410.17)]:
        I = balmer_emissivity(upper_n, T_e, n_e)
        result.append((name, lam, I))

    # [O III]
    I_oiii_main = (collisional_emissivity('OIII', T_e, n_e, abund['O2plus'])
                   * (1.0 + 1.0/3.0))   # 500.7 + 495.9 combined (ratio 3:1)
    I_oiii_500  = I_oiii_main * 0.75
    I_oiii_495  = I_oiii_main * 0.25
    I_oiii_aur  = collisional_emissivity('OIII_aur', T_e, n_e, abund['O2plus'])
    result.extend([
        ("[O III] 500.7", 500.68, I_oiii_500),
        ("[O III] 495.9", 495.89, I_oiii_495),
        ("[O III] 436.3", 436.32, I_oiii_aur),
    ])

    # [O II]
    I_oii = collisional_emissivity('OII', T_e, n_e, abund['Oplus'])
    result.extend([
        ("[O II] 372.7", 372.70, I_oii * 0.55),
        ("[O II] 372.9", 372.98, I_oii * 0.45),
    ])

    # [O I]
    I_oi = collisional_emissivity('OI', T_e, n_e, abund['O0'])
    result.extend([
        ("[O I] 630.0", 630.03, I_oi * 0.75),
        ("[O I] 636.4", 636.38, I_oi * 0.25),
    ])

    # [N II]
    I_nii = collisional_emissivity('NII', T_e, n_e, abund['Nplus'])
    result.extend([
        ("[N II] 658.3", 658.34, I_nii * 0.75),
        ("[N II] 654.8", 654.80, I_nii * 0.25),
    ])

    # [S II]
    I_sii = collisional_emissivity('SII', T_e, n_e, abund['Splus'])
    # [S II] ratio depends on density:
    r_sii = 1.45 - 1.01 * (n_e / (n_e + 3000.0))   # from n_e diagnostic
    result.extend([
        ("[S II] 671.6", 671.64, I_sii * r_sii / (1.0 + r_sii)),
        ("[S II] 673.1", 673.08, I_sii * 1.0   / (1.0 + r_sii)),
    ])

    # [S III]
    I_siii = collisional_emissivity('SIII', T_e, n_e, abund['S2plus'])
    result.extend([
        ("[S III] 906.9", 906.86, I_siii * 0.7),
        ("[S III] 953.1", 953.10, I_siii * 0.3),
    ])

    # [Ar III]
    I_ariii = collisional_emissivity('ArIII', T_e, n_e, abund['Ar2plus'])
    result.append(("[Ar III] 713.6", 713.58, I_ariii))

    # He I
    # He I 587.6nm: recombination. j(HeI)/j(Hβ) ≈ 0.104 × He/H at T=10^4 K
    I_HeI = 0.104 * abund['He'] * (T_e / 1e4)**(-0.14)
    result.append(("He I 587.6", 587.56, I_HeI))

    # He II (only present if T* > ~50,000 K → in very hot PNe)
    if ionization_param > 0.8 and T_e > 12000:
        I_HeII = 0.085 * abund['He'] * (T_e / 1e4)**(0.1)
        result.append(("He II 468.6", 468.57, I_HeII))

    # Sort by wavelength
    return sorted(result, key=lambda x: x[1])


# ─────────────────────────────────────────────────────────────────────────────
# 4. GLSL color vector from spectrum
# ─────────────────────────────────────────────────────────────────────────────

def wavelength_to_sRGB(lambda_nm: float) -> tuple:
    """
    Map wavelength to approximate sRGB values via CIE 1931 color matching.
    Simplified piecewise approximation (Bruton 1996, modified).
    Returns (R, G, B) in [0, 1].
    """
    lam = lambda_nm
    R = G = B = 0.0

    if 380 <= lam < 440:
        R = (440 - lam) / 60.0
        B = 1.0
    elif 440 <= lam < 490:
        G = (lam - 440) / 50.0
        B = 1.0
    elif 490 <= lam < 510:
        G = 1.0
        B = (510 - lam) / 20.0
    elif 510 <= lam < 580:
        R = (lam - 510) / 70.0
        G = 1.0
    elif 580 <= lam < 645:
        R = 1.0
        G = (645 - lam) / 65.0
    elif 645 <= lam <= 750:
        R = 1.0
        G = 0.0

    # Intensity fall-off at edges
    if 380 <= lam < 420:
        factor = 0.3 + 0.7 * (lam - 380) / 40.0
    elif 700 < lam <= 750:
        factor = 0.3 + 0.7 * (750 - lam) / 50.0
    else:
        factor = 1.0

    return (R * factor, G * factor, B * factor)


def spectrum_to_glsl_color(spectrum: list, normalize: bool = True) -> tuple:
    """
    Compute the integrated sRGB color of an emission spectrum.

    Weights each line by its intensity and its sRGB color response.
    Returns (R, G, B) in [0, 1] (normalized to max=1 if normalize=True).

    This gives you the actual color of the nebula as it would appear to the human eye
    through a broadband filter, not through narrowband filters.
    """
    total_R = total_G = total_B = 0.0
    total_I = 0.0

    for name, lam, intensity in spectrum:
        r, g, b = wavelength_to_sRGB(lam)
        total_R += r * intensity
        total_G += g * intensity
        total_B += b * intensity
        total_I += intensity

    if normalize and total_I > 0:
        M = max(total_R, total_G, total_B, 1e-10)
        total_R /= M
        total_G /= M
        total_B /= M

    return (total_R, total_G, total_B)


def hubble_palette(spectrum: list) -> tuple:
    """
    Hubble SHO palette: assign [S II], H-alpha, [O III] to R, G, B.
    Returns (SII_intensity, Halpha_intensity, OIII_intensity) for vec3.
    """
    sii_I  = sum(I for n, l, I in spectrum if 'S II' in n and 670 < l < 675)
    ha_I   = sum(I for n, l, I in spectrum if 'H_alpha' in n)
    oiii_I = sum(I for n, l, I in spectrum if 'O III' in n and 499 < l < 502)

    M = max(sii_I, ha_I, oiii_I, 1e-10)
    return (sii_I/M, ha_I/M, oiii_I/M)


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

parser = argparse.ArgumentParser(description="Nebula emission spectrum calculator")
parser.add_argument("--Te",  type=float, default=10000.0, help="Electron temperature [K]")
parser.add_argument("--ne",  type=float, default=100.0,   help="Electron density [cm⁻³]")
parser.add_argument("--Z",   type=float, default=1.0,     help="Metallicity (solar=1.0)")
parser.add_argument("--U",   type=float, default=0.5,     help="Ionization parameter [0,1]")
parser.add_argument("--plot", action="store_true",         help="Show matplotlib bar chart")
args = parser.parse_args()

T_e  = args.Te
n_e  = args.ne
Z    = args.Z
U    = args.U

print("=" * 70)
print(f"NEBULA FORMATION — Emission Spectrum  T_e={T_e:.0f}K  n_e={n_e:.0f}cm⁻³  Z={Z}  U={U}")
print("=" * 70)

spec = compute_spectrum(T_e, n_e, metallicity=Z, ionization_param=U)

print(f"\n{'Line':20s}  {'λ (nm)':>8}  {'I/I(Hβ)':>10}  {'sRGB':>20}  Bar")
print("-" * 75)

max_I = max(I for _, _, I in spec)

for name, lam, I in spec:
    r, g, b  = wavelength_to_sRGB(lam)
    bar_len  = int(I / max_I * 30)
    bar      = "█" * bar_len
    rgb_str  = f"({r:.2f},{g:.2f},{b:.2f})"
    print(f"{name:20s}  {lam:8.2f}  {I:10.4f}  {rgb_str:20s}  {bar}")

# Integrated colors
print("\n── Integrated Colors ────────────────────────────────────────────")
r, g, b = spectrum_to_glsl_color(spec)
print(f"  Broadband (eye response):  vec3({r:.3f}, {g:.3f}, {b:.3f})")

sii, ha, oiii = hubble_palette(spec)
print(f"  Hubble palette (SHO):      vec3({sii:.3f}, {ha:.3f}, {oiii:.3f})")
print(f"  Hubble GLSL:  return vec3({sii:.3f} * SII, {ha:.3f} * Halpha, {oiii:.3f} * OIII);")

# Survey: how colors change with temperature
print("\n── Color vs. Temperature Survey (n_e=100 cm⁻³, Z=1, U=0.5) ────")
print(f"  {'T_e [K]':>8}  {'SHO R':>7}  {'SHO G':>7}  {'SHO B':>7}  "
      f"{'Eye R':>6}  {'Eye G':>6}  {'Eye B':>6}")
for T in [6000, 8000, 10000, 12000, 15000, 20000]:
    s = compute_spectrum(T, 100.0, 1.0, 0.5)
    sii_t, ha_t, oiii_t = hubble_palette(s)
    er, eg, eb = spectrum_to_glsl_color(s)
    print(f"  {T:8.0f}  {sii_t:7.3f}  {ha_t:7.3f}  {oiii_t:7.3f}  "
          f"{er:6.3f}  {eg:6.3f}  {eb:6.3f}")

# Survey: how colors change with ionization parameter
print("\n── Color vs. Ionization Parameter (T_e=10000K, n_e=100, Z=1) ─")
print(f"  {'U':>5}  {'SHO R [S II]':>13}  {'SHO G [Hα]':>12}  {'SHO B [O III]':>15}  Region")
regions = [(0.0, "PDR/HIM edge"), (0.2, "S II peak"), (0.4, "classical H II"),
           (0.6, "hot core"), (0.8, "high-ion zone"), (1.0, "Wolf-Rayet / PN")]
for U_val, region in regions:
    s = compute_spectrum(10000.0, 100.0, 1.0, U_val)
    sii_u, ha_u, oiii_u = hubble_palette(s)
    print(f"  {U_val:5.1f}  {sii_u:13.3f}  {ha_u:12.3f}  {oiii_u:15.3f}  {region}")

if args.plot:
    try:
        import matplotlib.pyplot as plt
        import matplotlib.patches as mpatches

        fig, axes = plt.subplots(2, 1, figsize=(14, 9), facecolor='black')
        fig.suptitle(f"Emission Spectrum  T_e={T_e:.0f}K  n_e={n_e:.0f}cm⁻³  Z={Z}",
                     color='white', fontsize=13)

        # Main spectrum plot
        ax1 = axes[0]
        ax1.set_facecolor('#050510')
        for sp in [ax1.spines['top'], ax1.spines['right']]:
            sp.set_visible(False)
        for sp in [ax1.spines['bottom'], ax1.spines['left']]:
            sp.set_color('#333')

        lams  = [lam for _, lam, _ in spec if 350 < lam < 750]
        intns = [I   for _, lam, I in spec if 350 < lam < 750]
        names_vis = [n for n, lam, I in spec if 350 < lam < 750]

        for lam, I, nm in zip(lams, intns, names_vis):
            r, g, b = wavelength_to_sRGB(lam)
            ax1.bar(lam, I, width=2.5, color=(r, g, b), alpha=0.9)
            if I > max_I * 0.05:
                ax1.text(lam, I * 1.05, nm.split()[0], color='white',
                         fontsize=7, ha='center', rotation=45)

        ax1.set_xlabel('Wavelength [nm]', color='#888')
        ax1.set_ylabel('I / I(Hβ)', color='#888')
        ax1.tick_params(colors='#888')
        ax1.set_xlim(350, 760)
        ax1.set_title('Emission Line Intensities (350–750 nm)', color='#ccc')

        # Hubble palette preview
        ax2 = axes[1]
        ax2.set_facecolor('#050510')
        ax2.set_title('Hubble SHO Color Map vs. Ionization Parameter',
                      color='#ccc', fontsize=11)
        ax2.tick_params(colors='#888')
        for sp in ax2.spines.values():
            sp.set_color('#333')

        U_vals = [i/20 for i in range(21)]
        SII_arr, HA_arr, OIII_arr = [], [], []
        for Uv in U_vals:
            s = compute_spectrum(T_e, n_e, Z, Uv)
            si, ha, oi = hubble_palette(s)
            SII_arr.append(si); HA_arr.append(ha); OIII_arr.append(oi)

        ax2.plot(U_vals, SII_arr,  color='#c44', lw=2, label='[S II] → R')
        ax2.plot(U_vals, HA_arr,   color='#4c4', lw=2, label='Hα → G')
        ax2.plot(U_vals, OIII_arr, color='#44c', lw=2, label='[O III] → B')
        ax2.set_xlabel('Ionization Parameter U', color='#888')
        ax2.set_ylabel('Relative Intensity (normalized)', color='#888')
        ax2.legend(facecolor='black', edgecolor='#333', labelcolor='white')

        plt.tight_layout()
        plt.show()
    except ImportError:
        print("\nmatplotlib not installed. Run: pip install matplotlib")

print()
