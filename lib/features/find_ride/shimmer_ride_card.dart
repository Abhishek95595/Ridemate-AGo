import 'package:flutter/material.dart';

class ShimmerRideCard extends StatelessWidget {
  const ShimmerRideCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C23) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ShimmerBox(
                width: 50,
                height: 50,
                radius: 25,
                baseColor: baseColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(
                      width: 120,
                      height: 16,
                      radius: 4,
                      baseColor: baseColor,
                    ),
                    const SizedBox(height: 6),
                    _ShimmerBox(
                      width: 80,
                      height: 12,
                      radius: 4,
                      baseColor: baseColor,
                    ),
                  ],
                ),
              ),
              _ShimmerBox(
                width: 60,
                height: 24,
                radius: 4,
                baseColor: baseColor,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ShimmerBox(
            width: double.infinity,
            height: 60,
            radius: 12,
            baseColor: baseColor,
          ),
          const SizedBox(height: 16),
          _ShimmerBox(
            width: double.infinity,
            height: 45,
            radius: 15,
            baseColor: baseColor,
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Color baseColor;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
