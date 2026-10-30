import 'package:flutter/material.dart';

/// The palette.
///
/// The blue stays. It was briefly swapped for the logo's terracotta on the
/// grounds that the brand should appear in its own software; the call was
/// that blue reads as more professional for an HR system, which is the right
/// call to make on taste rather than consistency. The logo keeps its own
/// colours wherever it appears.
///
/// What changed here is everything around the hue: a documented scale of
/// tints, shadows that are tinted rather than pure black, and spacing and
/// radius scales so those stop being whatever number was typed that day.
class AppColors {
  // ── Primary ──────────────────────────────────────────────────────
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primaryLight = Color(0xFF3B82F6);

  /// Tints, for surfaces that need the accent without shouting.
  static const primaryTint = Color(0xFFEFF6FF);
  static const primaryTintStrong = Color(0xFFDBEAFE);

  /// Kept for the logo and anywhere the brand mark is drawn rather than
  /// placed — sampled from public/images/logo.png, not guessed.
  static const brand = Color(0xFFCF5E38);
  static const brandInk = Color(0xFF0F172A);

  // ── Sidebar ──────────────────────────────────────────────────────
  static const sidebarBg = Color(0xFF0F172A);
  static const sidebarActive = Color(0xFF1D4ED8);
  static const sidebarText = Color(0xFF94A3B8);
  static const sidebarTextActive = Color(0xFFFFFFFF);

  // ── Surfaces ─────────────────────────────────────────────────────
  static const surface = Color(0xFFF8FAFC);
  static const cardBg = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFF1F5F9);
  static const inputBorder = Color(0xFFE2E8F0);
  static const divider = Color(0xFFF1F5F9);

  // ── Text ─────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  // ── Status ───────────────────────────────────────────────────────
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFEFF6FF);

  // ── Charts ───────────────────────────────────────────────────────
  static const chart1 = Color(0xFF2563EB);
  static const chart2 = Color(0xFF10B981);
  static const chart3 = Color(0xFFF59E0B);
  static const chart4 = Color(0xFFEF4444);
  static const chart5 = Color(0xFF8B5CF6);

  /// Shadows, tinted toward the ink rather than pure black. Pure black
  /// shadows are what make a card look cut out and pasted on; a tinted one
  /// looks like the surface is actually lifting off the page.
  static List<BoxShadow> shadowSm = [
    BoxShadow(
      color: brandInk.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMd = [
    BoxShadow(
      color: brandInk.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> shadowLg = [
    BoxShadow(
      color: brandInk.withValues(alpha: 0.10),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
  ];

  /// For the one or two surfaces that carry colour outright — the greeting
  /// card, the clock-in dial. Two stops close in hue, because a gradient
  /// that travels too far reads as decoration rather than depth.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E6BF0), Color(0xFF1A42B8)],
  );
}

/// Spacing, radii and motion.
///
/// One scale, 4-based, because that is what the eye reads as rhythm.
class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Page padding. Tighter on a phone than the flat 24 the app used
  /// everywhere, which cost a sixth of the usable width on a 390pt screen.
  static double page(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 480 ? lg : xxl;
}

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const curve = Curves.easeOutCubic;
}
