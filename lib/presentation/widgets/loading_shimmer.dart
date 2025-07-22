import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LoadingShimmer extends StatefulWidget {
  const LoadingShimmer({super.key});

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: CupertinoColors.black,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            children: [
              // Background shimmer
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        CupertinoColors.systemGrey6.withOpacity(0.1),
                        CupertinoColors.systemGrey5.withOpacity(0.2),
                        CupertinoColors.systemGrey6.withOpacity(0.1),
                      ],
                      stops: [
                        _animation.value - 0.3,
                        _animation.value,
                        _animation.value + 0.3,
                      ],
                    ),
                  ),
                ),
              ),
              
              // Content placeholders
              Positioned(
                left: 20,
                right: 20,
                bottom: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category placeholder
                    Container(
                      width: 80,
                      height: 24,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Title placeholders
                    Container(
                      width: double.infinity,
                      height: 28,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: 28,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Description placeholders
                    Container(
                      width: double.infinity,
                      height: 20,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: 20,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Button placeholder
                    Container(
                      width: 120,
                      height: 44,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Loading indicator
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(
                      radius: 20,
                      color: CupertinoColors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading news...',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}