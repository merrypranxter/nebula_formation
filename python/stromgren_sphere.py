#!/usr/bin/env python3
"""
stromgren_sphere.py
───────────────────
Interactive visualization of a Strömgren sphere:
  - Radial ionization structure (H II → PDR → molecular cloud)
  - Ion fractions as function of radius
  - Temperature profile
  - Emission line emissivity profiles (H-alpha, O-III, S-II)

Outputs ASCII plots to terminal + optionally saves PNG via matplotlib.

Run:  python python/stromgren_sphere.py
      python python/stromgren_sphere.py --plot   (requires matplotlib)
"""

import math
import argparse
import sys


# ─────────────────────────────────────────────────────────────────────────────
# Simple 1-D Strömgren sphere model
# ─────────────────────────────────────────────────────────────────────────────
# This is a highly simplified model — a proper calculation would solve the
# ionization balance iteratively with photoionization cross-sections for each
# ion. Here we use analytical approximations sufficient for artistic reference.

# Physical constants
alpha_B = 2.6e-13   # cm³/s  Case B recombination coefficient (H)
pc      = 3.086e18  # cm/pc
m_H     = 1.673e-24 # g


def ionization_fraction(r: float, R_S: float, sharpness: float = 20.0) -> float:
    """
    H ionization fraction x(r) = n_H+/n_H.
    Uses an analytical sharp-front approximation.
    Inside R_S: x ≈ 1.0 (fully ionized)
    Outside:    x drops steeply to 0 (neutral)
    sharpness: how sharp the ionization front is (higher = sharper)
    """
    return 1.0 / (1.0 + math.exp(sharpness * (r - R_S) / R_S))


def electron_temperature(r: float, R_S: float) -> float:
    """
    Approximate electron temperature profile [K].
    Inside H II region: T_e ~ 8000–10000 K (radiation-hardened edges are hotter)
    PDR:                T_e drops to ~100–1000 K
    Molecular cloud:    T ~ 10–30 K
    """
    x    = ionization_fraction(r, R_S)
    T_HII = 9500.0                        # H II region temperature
    T_PDR = 200.0                         # PDR (photo-dissociation region)
    T_mol = 15.0                          # molecular cloud
    if x > 0.5:
        # Inside H II region: slight temperature rise near ionization front
        # (radiation hardening: harder photons deeper in)
        r_frac = r / R_S
        return T_HII * (1.0 + 0.15 * r_frac**2)
    elif x > 0.01:
        # PDR: warm, partially ionized/dissociated layer
        t = (0.5 - x) / 0.49
        return T_HII * (1.0 - t) + T_PDR * t
    else:
        # Molecular cloud: cold
        r_frac = (r - R_S) / R_S
        return T_PDR * math.exp(-r_frac * 2.0) + T_mol


def halpha_emissivity(n_H: float, x: float, T_e: float) -> float:
    """
    H-alpha volume emissivity [erg/cm³/s].
    j(Hα) = α_Hα^eff n_e n_p hν_Hα / (4π)
    n_e = n_p = x × n_H
    """
    E_Ha     = 3.028e-12    # erg per H-alpha photon
    alpha_Ha = 1.17e-13 * max(T_e / 1e4, 1e-3)**(-0.942)   # cm³/s
    n_e = x * n_H
    n_p = x * n_H
    return alpha_Ha * n_e * n_p * E_Ha / (4.0 * math.pi)


def oiii_emissivity(n_H: float, x: float, T_e: float, metallicity: float = 0.5) -> float:
    """
    [O III] 500.7 nm volume emissivity (simplified).
    O is doubly ionized in hot (T > ~8000 K), low-density regions.
    O/H ≈ 5×10⁻⁴ by number (solar); here default half-solar for a typical HII.
    Emissivity peaks where x ≈ 1, T > 9000 K.
    Collisional excitation rate: q_c ∝ T^(-1/2) exp(-hν/kT)
    """
    if x < 0.1 or T_e < 5000:
        return 0.0
    E_oiii  = 3.972e-12   # erg per [O III] photon (500.7 nm)
    n_O2plus = metallicity * 5e-4 * x * n_H       # O²⁺ traces fully ionized regions
    hnu_kT  = E_oiii / (1.38e-16 * T_e)
    q       = 2.5e-8 * T_e**(-0.5) * math.exp(-hnu_kT)   # excitation rate cm³/s
    n_e     = x * n_H
    return q * n_O2plus * n_e * E_oiii / (4.0 * math.pi)


def sii_emissivity(n_H: float, x: float, T_e: float, metallicity: float = 0.5) -> float:
    """
    [S II] 671.6+673.1 nm volume emissivity (simplified).
    S⁺ lives in the PDR: singly ionized, moderate temperature.
    Peaks just outside the H II region at the ionization front edge.
    """
    if T_e < 100 or x > 0.9:
        return 0.0
    E_sii   = 2.961e-12   # erg per [S II] photon (average of doublet)
    # S/H ≈ 2×10⁻⁵ (solar); S⁺ fraction peaks at x ~ 0.1–0.5
    x_Splus = metallicity * 2e-5 * n_H * 4.0 * x * (1.0 - x)   # peaks at x=0.5
    n_e     = x * n_H
    hnu_kT  = E_sii / (1.38e-16 * max(T_e, 100.0))
    q       = 3e-8 * T_e**(-0.5) * math.exp(-hnu_kT)
    return q * x_Splus * n_e * E_sii / (4.0 * math.pi)


# ─────────────────────────────────────────────────────────────────────────────
# Compute radial profiles
# ─────────────────────────────────────────────────────────────────────────────

def compute_profiles(Q_H: float, n_H: float, n_points: int = 100):
    """
    Returns radial profiles as lists of (r_pc, x, T_e, j_Ha, j_OIII, j_SII).
    """
    R_S = ((3.0 * Q_H) / (4.0 * math.pi * alpha_B * n_H**2))**(1.0/3.0) / pc
    R_max = R_S * 2.5

    profiles = []
    for i in range(n_points):
        r = (i + 0.5) / n_points * R_max
        x    = ionization_fraction(r, R_S)
        T_e  = electron_temperature(r, R_S)
        j_Ha  = halpha_emissivity(n_H, x, T_e)
        j_OIII = oiii_emissivity(n_H, x, T_e)
        j_SII  = sii_emissivity(n_H, x, T_e)
        profiles.append((r, x, T_e, j_Ha, j_OIII, j_SII))

    return R_S, R_max, profiles


# ─────────────────────────────────────────────────────────────────────────────
# ASCII bar chart
# ─────────────────────────────────────────────────────────────────────────────

def ascii_bar(value: float, max_value: float, width: int = 40, char: str = "█") -> str:
    n = int(value / max_value * width) if max_value > 0 else 0
    n = max(0, min(n, width))
    return char * n + "░" * (width - n)


def print_profiles(R_S: float, R_max: float, profiles: list, n_bins: int = 40):
    """Print ASCII visualization of radial profiles."""
    # Subsample to n_bins for display
    step = max(1, len(profiles) // n_bins)
    disp = profiles[::step][:n_bins]

    max_Ha   = max(p[3] for p in disp) or 1.0
    max_OIII = max(p[4] for p in disp) or 1.0
    max_SII  = max(p[5] for p in disp) or 1.0
    max_T    = max(p[2] for p in disp) or 1.0

    front_idx = min(range(len(disp)), key=lambda i: abs(disp[i][0] - R_S))

    print(f"  R_S = {R_S:.2f} pc  (ionization front marked with ↑)")
    print(f"  n_H = {n_H:.0f} cm⁻³  Q_H = {Q_H:.1e} s⁻¹")
    print()
    print(f"  {'r(pc)':>6}  H-alpha      [O III]      [S II]       T_e")

    for i, (r, x, T_e, j_Ha, j_OIII, j_SII) in enumerate(disp):
        marker = "←IF" if i == front_idx else "   "
        bar_Ha   = ascii_bar(j_Ha,   max_Ha,   8, "█")
        bar_OIII = ascii_bar(j_OIII, max_OIII, 8, "▓")
        bar_SII  = ascii_bar(j_SII,  max_SII,  8, "░")
        bar_T    = ascii_bar(T_e,    max_T,    8, "·")
        print(f"  {r:6.3f}  {bar_Ha}  {bar_OIII}  {bar_SII}  {bar_T} {T_e:6.0f}K {marker}")

    print()
    print("  Legend: H-alpha=█  [O III]=▓  [S II]=░  T_e=·")
    print()


# ─────────────────────────────────────────────────────────────────────────────
# matplotlib plot (optional)
# ─────────────────────────────────────────────────────────────────────────────

def matplotlib_plot(R_S: float, profiles: list, save_path: str = None):
    try:
        import matplotlib.pyplot as plt
        import matplotlib.gridspec as gridspec
    except ImportError:
        print("matplotlib not installed. Run: pip install matplotlib")
        return

    r_arr   = [p[0] for p in profiles]
    x_arr   = [p[1] for p in profiles]
    T_arr   = [p[2] for p in profiles]
    Ha_arr  = [p[3] for p in profiles]
    OIII_arr = [p[4] for p in profiles]
    SII_arr = [p[5] for p in profiles]

    fig, axes = plt.subplots(3, 1, figsize=(10, 10), facecolor='black')
    fig.suptitle("Strömgren Sphere — Radial Structure", color='white', fontsize=14)

    styles = dict(lw=1.5)
    for ax in axes:
        ax.set_facecolor('#050510')
        ax.spines['bottom'].set_color('#333')
        ax.spines['left'].set_color('#333')
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.tick_params(colors='#888')
        ax.axvline(R_S, color='#ffffff', lw=0.8, ls='--', alpha=0.5, label='R_S (IF)')

    # Ionization fraction + temperature
    ax1 = axes[0]
    ax1.plot(r_arr, x_arr, color='#4af', label='H ionization fraction x', **styles)
    ax1.set_ylabel('x = n(H⁺)/n(H)', color='#4af')
    ax1.set_ylim(0, 1.1)
    ax1a = ax1.twinx()
    ax1a.plot(r_arr, T_arr, color='#fa4', ls='--', label='T_e [K]', **styles)
    ax1a.set_ylabel('T_e [K]', color='#fa4')
    ax1a.tick_params(colors='#888')
    ax1.set_title('Ionization structure & Temperature', color='#ccc', fontsize=11)
    ax1.set_xlabel('Radius [pc]', color='#888')

    # Emission line emissivities
    ax2 = axes[1]
    ax2.plot(r_arr, Ha_arr,   color='#f43', label='H-alpha (656.3 nm)', **styles)
    ax2.plot(r_arr, OIII_arr, color='#4fb', label='[O III] (500.7 nm)', **styles)
    ax2.plot(r_arr, SII_arr,  color='#a32', label='[S II] (672 nm)',    **styles)
    ax2.set_yscale('log')
    ax2.set_ylabel('Emissivity [erg/cm³/s/sr]', color='#ccc')
    ax2.set_title('Emission Line Emissivity Profiles', color='#ccc', fontsize=11)
    ax2.legend(facecolor='black', edgecolor='#333', labelcolor='#ccc')
    ax2.set_xlabel('Radius [pc]', color='#888')

    # Hubble palette preview: normalize and show SHO color
    Ha_n   = [v/max(Ha_arr  or [1]) for v in Ha_arr  ]
    OIII_n = [v/max(OIII_arr or [1]) for v in OIII_arr]
    SII_n  = [v/max(SII_arr  or [1]) for v in SII_arr ]
    ax3 = axes[2]
    for i in range(len(r_arr)-1):
        rgb = (SII_n[i], Ha_n[i], OIII_n[i])     # SHO Hubble palette
        ax3.bar(r_arr[i], 1.0, width=r_arr[1]-r_arr[0], color=rgb, align='edge')
    ax3.set_yticks([])
    ax3.set_xlabel('Radius [pc]', color='#888')
    ax3.set_title('Hubble Palette Preview (SHO: S-II→R, Hα→G, O-III→B)', color='#ccc', fontsize=11)

    plt.tight_layout()
    if save_path:
        plt.savefig(save_path, dpi=150, bbox_inches='tight', facecolor='black')
        print(f"Saved to {save_path}")
    else:
        plt.show()


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

parser = argparse.ArgumentParser(description="Strömgren sphere ionization structure")
parser.add_argument("--Q_H",  type=float, default=5e49,  help="Ionizing photon rate [s⁻¹] (O5V star: 5e49)")
parser.add_argument("--n_H",  type=float, default=100.0, help="Hydrogen density [cm⁻³]")
parser.add_argument("--plot",  action="store_true",       help="Show matplotlib plot")
parser.add_argument("--save",  type=str,   default=None,  help="Save plot to file")
args = parser.parse_args()

Q_H = args.Q_H
n_H = args.n_H

print("=" * 65)
print("STRÖMGREN SPHERE — Ionization Structure")
print("=" * 65)

R_S, R_max, profiles = compute_profiles(Q_H, n_H)
print_profiles(R_S, R_max, profiles)

if args.plot or args.save:
    matplotlib_plot(R_S, profiles, save_path=args.save)
