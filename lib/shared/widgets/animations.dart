import 'package:flutter/material.dart';

/// Small, one-shot motion helpers. Every effect is skipped when the user has
/// asked the system to reduce or remove animations.
bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades and slides [child] into place once, after an optional [delay].
/// Use [index] to stagger items in a list or grid.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.offset = const Offset(0, .08),
    this.duration = const Duration(milliseconds: 380),
  });

  final Widget child;
  final int index;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  // Stagger, but cap it so long lists never wait noticeably.
  late final Duration _wait =
      widget.delay + Duration(milliseconds: 45 * widget.index.clamp(0, 8));
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _wait + widget.duration,
  );
  // The delay is the start of the interval, so no timers are needed.
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _wait.inMicroseconds / (_wait + widget.duration).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(begin: widget.offset, end: Offset.zero).animate(_curve),
      child: widget.child,
    ),
  );
}

/// Pops [child] in with a gentle overshoot, for success marks and badges.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 650),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  late final double _start =
      widget.delay.inMicroseconds /
      (widget.delay + widget.duration).inMicroseconds;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(
      parent: _controller,
      curve: Interval(
        _start,
        _start + (1 - _start) * .4,
        curve: Curves.easeOut,
      ),
    ),
    child: ScaleTransition(
      scale: CurvedAnimation(
        parent: _controller,
        curve: Interval(_start, 1, curve: Curves.elasticOut),
      ),
      child: widget.child,
    ),
  );
}

/// Briefly scales [child] up whenever [value] changes, e.g. a cart count or a
/// favourite toggle, so the user sees their action land.
class BumpOnChange<T> extends StatefulWidget {
  const BumpOnChange({super.key, required this.value, required this.child});

  final T value;
  final Widget child;

  @override
  State<BumpOnChange<T>> createState() => _BumpOnChangeState<T>();
}

class _BumpOnChangeState<T> extends State<BumpOnChange<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.3,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.3,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 60,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant BumpOnChange<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_reduceMotion(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
