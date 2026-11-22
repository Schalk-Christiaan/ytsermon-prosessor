// @stelsel motion
//   soort: module
//   wanneer: oral waar iets bykom, kom of tel (Werk-rye, suksesmerke, statusbalk)
//   groep: app | App-raam
//   skryf: —
//   doel: klein bewegings-wyers deur die bewegingskonstantes: Reveal (rye vervaag en skuif in), PopIn (suksesmerk 0,9 na 1), CountText (getalle tel in 150 ms op); alles sonder beweging met disableAnimations
//   status: bou
import 'package:flutter/material.dart';

import 'theme.dart';

/// Fades and slides [child] up 8 px when it first appears; still when motion is reduced.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = motion(context);
    if (d == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: kMotionCurve,
      child: child,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 8), child: c),
      ),
    );
  }
}

/// A success mark that comes in from scale 0.9 to 1 (give it a key that changes when it appears).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = motion(context);
    if (d == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: d,
      curve: kMotionCurve,
      child: child,
      builder: (_, v, c) => Opacity(
        opacity: (v - 0.9) * 10,
        child: Transform.scale(scale: v, child: c),
      ),
    );
  }
}

/// A number in text that counts up to its new [value] in 150 ms (no animation at the first build).
class CountText extends StatelessWidget {
  const CountText({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });
  final int value;
  final String Function(int) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: motion(context, kMotionFast),
    builder: (_, v, _) => Text(format(v.round()), style: style),
  );
}
