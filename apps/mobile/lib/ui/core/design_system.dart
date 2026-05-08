import 'dart:math' as math;

import 'package:flutter/material.dart';

class FreshColors {
  const FreshColors._();

  static const appBg = Color(0xfff0f0ef);
  static const screen = Color(0xfff7f7f5);
  static const surface = Color(0xfffbfbf8);
  static const surfaceSoft = Color(0xfff3f3f1);
  static const surfaceMuted = Color(0xffecedea);
  static const ink = Color(0xff080907);
  static const inkSoft = Color(0xff2f312d);
  static const inkMuted = Color(0xff72756f);
  static const rule = Color(0xffe3e5df);
  static const ruleSoft = Color(0xffeef0eb);
  static const lime = Color(0xff9ad32a);
  static const limeDeep = Color(0xff78a51b);
  static const limeSoft = Color(0xffd8f3a0);
  static const limeWash = Color(0xffedf8d2);
  static const leaf = Color(0xff4f9b1f);
  static const water = Color(0xff10c7f5);
  static const orange = Color(0xfff08b2b);
  static const mint = Color(0xff4fd6a2);
  static const coral = Color(0xffe94f5f);
  static const yellow = Color(0xfffff0b6);
}

class FreshSpacing {
  const FreshSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class FreshRadii {
  const FreshRadii._();

  static const sm = 10.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

const _softShadow = [
  BoxShadow(
    color: Color(0x14080907),
    blurRadius: 28,
    offset: Offset(0, 12),
  ),
];

class FreshPage extends StatelessWidget {
  const FreshPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.subtitle,
    this.maxWidth = 760,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: FreshHeader(
                    title: title,
                    subtitle: subtitle,
                    actions: actions,
                    leading: leading,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                sliver: SliverToBoxAdapter(child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FreshHeader extends StatelessWidget {
  const FreshHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: FreshSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: FreshColors.inkMuted,
                    height: 1.1,
                  ),
                ),
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: FreshColors.ink,
                ),
              ),
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: FreshSpacing.md),
          Wrap(spacing: FreshSpacing.sm, children: actions),
        ],
      ],
    );
  }
}

class FreshCard extends StatelessWidget {
  const FreshCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = FreshColors.surface,
    this.radius = FreshRadii.lg,
    this.onTap,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        boxShadow: shadow ? _softShadow : null,
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: decorated,
      ),
    );
  }
}

class FreshIconButton extends StatelessWidget {
  const FreshIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.backgroundColor = FreshColors.surface,
    this.foregroundColor = FreshColors.ink,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: size >= 48 ? 22 : 18),
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: FreshColors.surfaceMuted,
          disabledForegroundColor: FreshColors.inkMuted,
          shape: const CircleBorder(),
          elevation: 0,
        ),
      ),
    );
  }
}

class FreshIconChip extends StatelessWidget {
  const FreshIconChip({
    super.key,
    required this.icon,
    required this.color,
    this.backgroundColor,
    this.size = 42,
  });

  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class FreshMetricCard extends StatelessWidget {
  const FreshMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.sparkline,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final Widget? sparkline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FreshCard(
      padding: const EdgeInsets.all(16),
      radius: FreshRadii.lg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FreshIconChip(icon: icon, color: color),
              const SizedBox(width: FreshSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(color: FreshColors.ink),
                ),
              ),
            ],
          ),
          if (sparkline != null) ...[
            const SizedBox(height: FreshSpacing.md),
            sparkline!,
          ],
          const Spacer(),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 4,
            children: [
              Text(
                value,
                style: textTheme.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(unit, style: textTheme.bodyMedium),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FreshStatusBanner extends StatelessWidget {
  const FreshStatusBanner({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.color = FreshColors.lime,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FreshCard(
      color: color.withValues(alpha: 0.16),
      shadow: false,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FreshIconChip(icon: icon, color: color),
          const SizedBox(width: FreshSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                if (message != null) ...[
                  const SizedBox(height: FreshSpacing.xs),
                  Text(message!, style: textTheme.bodyMedium),
                ],
                if (action != null) ...[
                  const SizedBox(height: FreshSpacing.sm),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FreshProgressRing extends StatelessWidget {
  const FreshProgressRing({
    super.key,
    required this.progress,
    required this.center,
    this.size = 90,
    this.color = FreshColors.lime,
    this.trackColor = FreshColors.surface,
  });

  final double progress;
  final Widget center;
  final double size;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: progress.clamp(0, 1).toDouble(),
              color: color,
              trackColor: trackColor,
            ),
          ),
          center,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = Offset.zero & size;
    final insetRect = rect.deflate(stroke / 2);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(insetRect, -math.pi / 2, math.pi * 2, false, trackPaint);
    canvas.drawArc(
      insetRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class FreshMiniBars extends StatelessWidget {
  const FreshMiniBars({
    super.key,
    required this.values,
    this.color = FreshColors.mint,
    this.height = 46,
  });

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, math.max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final value in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FractionallySizedBox(
                  heightFactor: maxValue == 0
                      ? 0
                      : (value / maxValue).clamp(0.08, 1).toDouble(),
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FreshFoodStack extends StatelessWidget {
  const FreshFoodStack({
    super.key,
    this.assets = const [
      'assets/images/meal_breakfast.webp',
      'assets/images/meal_lunch.webp',
    ],
    this.size = 38,
  });

  final List<String> assets;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + (assets.length - 1) * (size * 0.62),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < assets.length; i++)
            Positioned(
              left: i * size * 0.62,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: FreshColors.surface, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(assets[i], fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }
}

class FreshEmptyState extends StatelessWidget {
  const FreshEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FreshCard(
      shadow: false,
      color: FreshColors.surfaceSoft,
      child: Column(
        children: [
          FreshIconChip(icon: icon, color: FreshColors.limeDeep),
          const SizedBox(height: FreshSpacing.md),
          Text(title,
              style: textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: FreshSpacing.sm),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(color: FreshColors.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class FreshSectionTitle extends StatelessWidget {
  const FreshSectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
