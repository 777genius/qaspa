import 'package:flutter/material.dart';

/// A text widget that animates when its value changes.
/// Shows a brief highlight animation to indicate the value has been updated.
class AnimatedValueText extends StatefulWidget {
  final String value;
  final TextStyle? style;
  final Color? highlightColor;
  final Duration animationDuration;

  const AnimatedValueText({
    super.key,
    required this.value,
    this.style,
    this.highlightColor,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<AnimatedValueText> createState() => _AnimatedValueTextState();
}

class _AnimatedValueTextState extends State<AnimatedValueText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _previousValue = '';
  bool _isFirstBuild = true;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
      value: 1.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(AnimatedValueText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _previousValue && !_isFirstBuild) {
      _previousValue = widget.value;
      _controller.forward(from: 0.0);
    }
    _isFirstBuild = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor =
        widget.highlightColor ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = 1.0 - _animation.value;
        final effectiveStyle = widget.style ?? const TextStyle();

        final baseWeight = effectiveStyle.fontWeight ?? FontWeight.w400;
        final boldWeight = FontWeight.w900;
        final animatedWeight = FontWeight.lerp(baseWeight, boldWeight, progress);

        final glowColor = highlightColor.withValues(alpha: progress * 0.6);

        final animatedStyle = effectiveStyle.copyWith(
          color: Color.lerp(
            effectiveStyle.color ??
                Theme.of(context).textTheme.bodyMedium?.color,
            highlightColor,
            progress * 0.7,
          ),
          fontWeight: animatedWeight,
          shadows: progress > 0.01
              ? [
                  Shadow(
                    color: glowColor,
                    blurRadius: 8 * progress,
                  ),
                  Shadow(
                    color: glowColor,
                    blurRadius: 16 * progress,
                  ),
                ]
              : null,
        );

        return Text(
          widget.value,
          style: animatedStyle,
        );
      },
    );
  }
}

/// A more compact version that just pulses the text color
class AnimatedValueTextCompact extends StatefulWidget {
  final String value;
  final TextStyle? style;
  final Color? highlightColor;
  final Duration animationDuration;

  const AnimatedValueTextCompact({
    super.key,
    required this.value,
    this.style,
    this.highlightColor,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedValueTextCompact> createState() =>
      _AnimatedValueTextCompactState();
}

class _AnimatedValueTextCompactState extends State<AnimatedValueTextCompact>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _previousValue = '';
  bool _isFirstBuild = true;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
      value: 1.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(AnimatedValueTextCompact oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _previousValue && !_isFirstBuild) {
      _previousValue = widget.value;
      _controller.forward(from: 0.0);
    }
    _isFirstBuild = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlightColor =
        widget.highlightColor ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = 1.0 - _animation.value;
        final effectiveStyle = widget.style ?? const TextStyle();

        final glowColor = highlightColor.withValues(alpha: progress * 0.5);

        final animatedStyle = effectiveStyle.copyWith(
          color: Color.lerp(
            effectiveStyle.color ?? Theme.of(context).textTheme.bodyMedium?.color,
            highlightColor,
            progress * 0.7,
          ),
          shadows: progress > 0.01
              ? [
                  Shadow(
                    color: glowColor,
                    blurRadius: 6 * progress,
                  ),
                  Shadow(
                    color: glowColor,
                    blurRadius: 12 * progress,
                  ),
                ]
              : null,
        );

        return Text(
          widget.value,
          style: animatedStyle,
        );
      },
    );
  }
}
