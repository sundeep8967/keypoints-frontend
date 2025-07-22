import 'package:flutter/cupertino.dart';

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
      color: CupertinoColors.black,
      child: Column(
        children: [
          // Header shimmer
          Container(
            height: 60,
            margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: List.generate(4, (index) => 
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: _buildShimmerContainer(80, 36),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content shimmer
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildShimmerContainer(double.infinity, 200),
                  const SizedBox(height: 20),
                  _buildShimmerContainer(double.infinity, 20),
                  const SizedBox(height: 10),
                  _buildShimmerContainer(double.infinity, 20),
                  const SizedBox(height: 10),
                  _buildShimmerContainer(200, 20),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CupertinoActivityIndicator(
                        radius: 15,
                        color: CupertinoColors.white,
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Loading articles...',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerContainer(double width, double height) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
              colors: const [
                Color(0xFF2C2C2E),
                Color(0xFF3A3A3C),
                Color(0xFF2C2C2E),
              ],
            ),
          ),
        );
      },
    );
  }
}