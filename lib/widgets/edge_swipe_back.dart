import 'package:flutter/material.dart';

class EdgeSwipeBack extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPop;
  final double edgeWidth;
  final double triggerRatio;
  final double velocityThreshold;
  final bool enabled;

  const EdgeSwipeBack({
    super.key,
    required this.child,
    this.onPop,
    this.edgeWidth = 28.0,
    this.triggerRatio = 0.35,
    this.velocityThreshold = 600.0,
    this.enabled = true,
  });

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  double _maxWidth = 0.0;
  bool _tracking = false;
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() => _dragOffset = _animation.value);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    if (details.localPosition.dx > widget.edgeWidth) {
      _tracking = false;
      return;
    }
    _controller.stop();
    _tracking = true;
    setState(() => _dragOffset = 0.0);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_tracking) return;
    final next = (_dragOffset + details.delta.dx).clamp(0.0, _maxWidth);
    setState(() => _dragOffset = next);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_tracking) return;
    _tracking = false;
    final velocity = details.primaryVelocity ?? 0;
    final shouldPop = _dragOffset > _maxWidth * widget.triggerRatio ||
        velocity > widget.velocityThreshold;
    if (shouldPop) {
      _animateTo(_maxWidth, then: _handlePop);
    } else {
      _animateTo(0);
    }
  }

  void _animateTo(double target, {VoidCallback? then}) {
    _animation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        if (then != null) then();
      });
  }

  void _handlePop() {
    if (widget.onPop != null) {
      widget.onPop!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _maxWidth = size.width;
    final progress =
        _maxWidth == 0 ? 0.0 : (_dragOffset / _maxWidth).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Stack(
          children: [
            if (progress > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.15 * (1 - progress)),
                  ),
                ),
              ),
            widget.child,
          ],
        ),
      ),
    );
  }
}
