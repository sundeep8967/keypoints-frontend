import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SwipeAnimationHandler extends StatefulWidget {
  final Widget child;
  final Function()? onSwipeLeft;
  final Function()? onSwipeRight;
  final Function()? onSwipeUp;
  final Function()? onSwipeDown;
  final double swipeThreshold;

  const SwipeAnimationHandler({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
    this.swipeThreshold = 100.0,
  });

  @override
  State<SwipeAnimationHandler> createState() => _SwipeAnimationHandlerState();
}

class _SwipeAnimationHandlerState extends State<SwipeAnimationHandler>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(2.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: _isDragging ? _dragOffset : _slideAnimation.value * MediaQuery.of(context).size.width,
            child: Transform.rotate(
              angle: _isDragging 
                ? _dragOffset.dx * 0.001 
                : _rotationAnimation.value,
              child: Transform.scale(
                scale: _isDragging 
                  ? (1.0 - (_dragOffset.distance * 0.0005)).clamp(0.8, 1.0)
                  : _scaleAnimation.value,
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Determine swipe direction and trigger callbacks
    if (_dragOffset.dx.abs() > widget.swipeThreshold) {
      if (_dragOffset.dx > 0) {
        // Swipe right
        _triggerSwipeAnimation();
        widget.onSwipeRight?.call();
      } else {
        // Swipe left
        _triggerSwipeAnimation();
        widget.onSwipeLeft?.call();
      }
    } else if (_dragOffset.dy.abs() > widget.swipeThreshold) {
      if (_dragOffset.dy > 0) {
        // Swipe down
        widget.onSwipeDown?.call();
      } else {
        // Swipe up
        widget.onSwipeUp?.call();
      }
      _resetPosition();
    } else {
      // Not enough movement, reset position
      _resetPosition();
    }
  }

  void _triggerSwipeAnimation() {
    _animationController.forward().then((_) {
      _animationController.reset();
      setState(() {
        _isDragging = false;
        _dragOffset = Offset.zero;
      });
    });
  }

  void _resetPosition() {
    setState(() {
      _isDragging = false;
      _dragOffset = Offset.zero;
    });
  }

  /// Programmatically trigger swipe animation
  void triggerSwipe({required SwipeDirection direction}) {
    switch (direction) {
      case SwipeDirection.left:
        widget.onSwipeLeft?.call();
        break;
      case SwipeDirection.right:
        widget.onSwipeRight?.call();
        break;
      case SwipeDirection.up:
        widget.onSwipeUp?.call();
        break;
      case SwipeDirection.down:
        widget.onSwipeDown?.call();
        break;
    }
    _triggerSwipeAnimation();
  }
}

enum SwipeDirection {
  left,
  right,
  up,
  down,
}