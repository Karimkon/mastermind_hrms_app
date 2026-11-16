/// The shared vocabulary.
///
/// Before this, a "card" was hand-rolled per screen: twelve different corner
/// radii, four border colours, shadows on some and not others. None of it was
/// wrong on its own; together it read as several apps stapled together, which
/// is the difference between software that looks finished and software that
/// looks assembled.
library;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';



/// The surface everything sits on.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// A hairline of colour down the leading edge. Used sparingly — it is how
  /// a card says "this one is different" without needing a second style.
  final Color? accent;

  final bool raised;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.accent,
    this.raised = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding ?? const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: raised ? AppColors.shadowMd : AppColors.shadowSm,
      ),
      child: child,
    );

    final withAccent = accent == null
        ? body
        : Stack(children: [
            body,
            Positioned(
              left: 0,
              top: AppSpace.lg,
              bottom: AppSpace.lg,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ]);

    if (onTap == null) return withAccent;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: withAccent),
    );
  }
}

/// A small-caps label above a group. Quieter than a heading, which lets the
/// content below it be the loudest thing on screen.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

/// A figure with a name, and optionally somewhere to go.
///
/// The chevron appears only when tapping does something — an affordance that
/// lies is worse than none.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 19, color: tone),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.25,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
          ],
        ),
      );
}

/// A status word. Never wraps — the attendance table read "Prese nt" because
/// a chip was allowed to.
class AppChip extends StatelessWidget {
  final String label;
  final Color tone;
  final IconData? icon;

  const AppChip({super.key, required this.label, required this.tone, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: tone),
              const SizedBox(width: 4),
            ],
            // Flexible, so a long status can give ground on a narrow
            // screen instead of running off it. "Pending supervisor
            // approval" overflowed a 320pt phone by 34pt without this.
            Flexible(
              child: Text(
                label,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Nothing here — said in a way that tells somebody whether that is a
/// problem. "No leave requests" is information; a blank screen is a worry.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpace.xxxl + AppSpace.lg, horizontal: AppSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: AppSpace.xs + 2),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpace.xl),
                action!,
              ],
            ],
          ),
        ),
      );
}

/// A page heading with room for an action beside it.
class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const PageTitle(this.title, {super.key, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    // A 22pt heading and a real button do not fit on one line at 320pt;
    // it overflowed by 1.5pt, which is enough for the striped bars.
    // Under this width the action goes underneath instead.
    final narrow = MediaQuery.sizeOf(context).width < 360;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: action == null
          ? heading
          : narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    heading,
                    const SizedBox(height: AppSpace.md),
                    action!,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: AppSpace.md),
                    Flexible(child: action!),
                  ],
                ),
    );
  }
}

/// The shimmer placeholder, one shape for the whole app.
class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.cardBorder,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// A row of equal columns that reflows instead of overflowing.
///
/// WHY THIS EXISTS
///
/// Most of this app's screens were laid out for a desktop window and then
/// shipped to phones unchanged. The pattern is always the same:
///
///     Row(children: [
///       Expanded(child: card), SizedBox(width: 16), Expanded(child: card),
///     ])
///
/// A Row divides whatever width it is given, however little that is. Three
/// Expanded columns inside a 360pt phone leave roughly 66pt of text each -
/// narrower than the word "Balances" - so headings rendered one letter per
/// line and the buttons under them spilled out of their cards.
///
/// CardGrid takes the SAME children a Row took, Expanded wrappers and gap
/// SizedBoxes included, so converting a screen is a one-word change at the
/// call site. It then lays them out in as many columns as actually fit,
/// wrapping onto further rows, and falls to a single column on a phone.
///
/// [minItemWidth] is the narrowest a column may be before it is better to
/// use fewer columns. The default suits a card with a heading and a button;
/// pass something smaller for a row of figures.
class CardGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double gap;

  /// Whether a last row with fewer items than the rest stretches to fill the
  /// width. False keeps a lone trailing card the same width as the others,
  /// which reads better in a grid of figures.
  final bool stretchLastRow;

  const CardGrid({
    super.key,
    required this.children,
    this.minItemWidth = 230,
    this.gap = AppSpace.lg,
    this.stretchLastRow = true,
  });

  @override
  Widget build(BuildContext context) {
    // The gap SizedBoxes are the caller's spacing between columns. This
    // widget decides the spacing itself, so they are dropped here and
    // reinstated as real gaps below.
    final items = _unwrap(children);

    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;

      // How many columns of at least minItemWidth fit, counting the gaps
      // between them. At least one, never more than there are items.
      final fit = ((width + gap) / (minItemWidth + gap)).floor();
      final perRow = fit.clamp(1, items.length);

      if (perRow == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              items[i],
            ],
          ],
        );
      }

      final rows = <Widget>[];

      for (var start = 0; start < items.length; start += perRow) {
        final end = (start + perRow) > items.length ? items.length : start + perRow;
        final slice = items.sublist(start, end);
        final isLast = end >= items.length;

        if (rows.isNotEmpty) rows.add(SizedBox(height: gap));

        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < perRow; j++) ...[
              if (j > 0) SizedBox(width: gap),
              if (j < slice.length)
                Expanded(child: slice[j])
              else if (!(isLast && stretchLastRow))
                const Expanded(child: SizedBox())
              else
                const SizedBox.shrink(),
            ],
          ],
        ));
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
    });
  }

  /// Strip the flex wrappers and spacing the caller inherited from the Row
  /// this replaces. An Expanded outside a flex throws; a gap SizedBox would
  /// become a stray empty cell.
  static List<Widget> _unwrap(List<Widget> children) {
    final out = <Widget>[];

    for (final child in children) {
      // A column gap, as written at the call site: a bare SizedBox with
      // a width and nothing else. Anything carrying a key, a child or a
      // height is somebody's actual content and is kept - an earlier
      // version tested `width > 0 || height > 0` and silently swallowed
      // fixed-height cards.
      if (child is SizedBox &&
          child.child == null &&
          child.key == null &&
          child.height == null &&
          (child.width ?? 0) > 0) {
        continue;
      }
      if (child is Expanded) {
        out.add(child.child);
        continue;
      }
      if (child is Flexible) {
        out.add(child.child);
        continue;
      }
      out.add(child);
    }

    return out;
  }
}
