import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The "Elevate YSF" logo image.
///
/// The source file is a JPG on a white background, and the whole app is on
/// white, so it drops in without any cut-out work.
class YsfLogo extends StatelessWidget {
  const YsfLogo({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/ysf-logo.jpg',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Elevate YSF',
    );
  }
}

/// Faint arc behind screen content, echoing the heavy brush stroke that
/// underlines "Elevate" in the logo. Purely decorative.
class CourtArcBackdrop extends StatelessWidget {
  const CourtArcBackdrop({
    super.key,
    required this.child,
    this.opacity = 0.045,
  });

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -30,
          left: -60,
          right: -60,
          height: 320,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: CustomPaint(painter: _ArcPainter()),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final brush = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;

    final arc = Path()
      ..moveTo(size.width * 0.02, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.5,
        -size.height * 0.15,
        size.width * 0.98,
        size.height * 0.92,
      );

    canvas.drawPath(arc, brush);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
