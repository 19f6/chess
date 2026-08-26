import 'package:flutter/material.dart';

/// Hand-drawn vector chess piece silhouettes -- real pictorial artwork
/// (king's cross, queen's crown, rook's battlements, bishop's mitre,
/// knight's horse head, pawn) rather than a font glyph or a letter badge.
/// Both colors render the exact same [Path], so there's no risk of the
/// per-font "white/black look like different pieces" issue -- only the
/// fill/outline paint differs.
class ChessPiecePainter extends CustomPainter {
  final String pieceType; // 'K', 'Q', 'R', 'B', 'N', 'P' (case-insensitive)
  final Color fill;
  final Color outline;
  final double strokeWidth;

  ChessPiecePainter({
    required this.pieceType,
    required this.fill,
    required this.outline,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _pathFor(pieceType.toUpperCase(), size);
    canvas.drawPath(path, Paint()..color = fill..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant ChessPiecePainter oldDelegate) =>
      oldDelegate.pieceType != pieceType ||
      oldDelegate.fill != fill ||
      oldDelegate.outline != outline ||
      oldDelegate.strokeWidth != strokeWidth;

  static Offset _p(double fx, double fy, Size size) => Offset(fx * size.width, fy * size.height);

  static Path _polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final pt in points.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  static void _addBase(Path path, Size size) {
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTRB(_p(0.20, 0.82, size).dx, _p(0, 0.82, size).dy, _p(0.80, 0.94, size).dx, _p(0, 0.94, size).dy),
      Radius.circular(size.width * 0.03),
    ));
  }

  Path _pathFor(String type, Size size) {
    switch (type) {
      case 'P':
        return _pawn(size);
      case 'R':
        return _rook(size);
      case 'B':
        return _bishop(size);
      case 'N':
        return _knight(size);
      case 'Q':
        return _queen(size);
      case 'K':
        return _king(size);
      default:
        return Path();
    }
  }

  Path _pawn(Size size) {
    final path = Path()..addOval(Rect.fromCircle(center: _p(0.5, 0.28, size), radius: size.width * 0.14));
    path.addPath(
        _polygon([
          _p(0.40, 0.40, size),
          _p(0.60, 0.40, size),
          _p(0.68, 0.52, size),
          _p(0.32, 0.52, size),
        ]),
        Offset.zero);
    path.addPath(
        _polygon([
          _p(0.36, 0.52, size),
          _p(0.64, 0.52, size),
          _p(0.74, 0.82, size),
          _p(0.26, 0.82, size),
        ]),
        Offset.zero);
    _addBase(path, size);
    return path;
  }

  Path _rook(Size size) {
    final path = Path();
    for (final xRange in [
      [0.20, 0.335],
      [0.4325, 0.5675],
      [0.665, 0.80],
    ]) {
      path.addRect(Rect.fromLTRB(
        _p(xRange[0], 0.12, size).dx,
        _p(0, 0.12, size).dy,
        _p(xRange[1], 0.30, size).dx,
        _p(0, 0.30, size).dy,
      ));
    }
    path.addRect(Rect.fromLTRB(
      _p(0.20, 0.28, size).dx,
      _p(0, 0.28, size).dy,
      _p(0.80, 0.35, size).dx,
      _p(0, 0.35, size).dy,
    ));
    path.addPath(
        _polygon([
          _p(0.30, 0.35, size),
          _p(0.70, 0.35, size),
          _p(0.66, 0.82, size),
          _p(0.34, 0.82, size),
        ]),
        Offset.zero);
    _addBase(path, size);
    return path;
  }

  Path _bishop(Size size) {
    final path = Path()..addOval(Rect.fromCircle(center: _p(0.5, 0.135, size), radius: size.width * 0.05));
    path.addPath(
        _polygon([
          _p(0.5, 0.19, size),
          _p(0.67, 0.56, size),
          _p(0.63, 0.70, size),
          _p(0.70, 0.78, size),
          _p(0.30, 0.78, size),
          _p(0.37, 0.70, size),
          _p(0.33, 0.56, size),
        ]),
        Offset.zero);
    _addBase(path, size);
    return path;
  }

  Path _queen(Size size) {
    final path = Path();
    for (final cx in [0.27, 0.385, 0.5, 0.615, 0.73]) {
      path.addOval(Rect.fromCircle(center: _p(cx, 0.165, size), radius: size.width * 0.05));
    }
    path.addRect(Rect.fromLTRB(
      _p(0.27, 0.19, size).dx,
      _p(0, 0.19, size).dy,
      _p(0.73, 0.28, size).dx,
      _p(0, 0.28, size).dy,
    ));
    path.addPath(
        _polygon([
          _p(0.34, 0.28, size),
          _p(0.66, 0.28, size),
          _p(0.70, 0.80, size),
          _p(0.30, 0.80, size),
        ]),
        Offset.zero);
    _addBase(path, size);
    return path;
  }

  Path _king(Size size) {
    final path = Path();
    path.addRect(Rect.fromLTRB(
      _p(0.465, 0.04, size).dx,
      _p(0, 0.04, size).dy,
      _p(0.535, 0.20, size).dx,
      _p(0, 0.20, size).dy,
    ));
    path.addRect(Rect.fromLTRB(
      _p(0.38, 0.095, size).dx,
      _p(0, 0.095, size).dy,
      _p(0.62, 0.145, size).dx,
      _p(0, 0.145, size).dy,
    ));
    path.addRect(Rect.fromLTRB(
      _p(0.38, 0.20, size).dx,
      _p(0, 0.20, size).dy,
      _p(0.62, 0.28, size).dx,
      _p(0, 0.28, size).dy,
    ));
    path.addPath(
        _polygon([
          _p(0.34, 0.28, size),
          _p(0.66, 0.28, size),
          _p(0.70, 0.80, size),
          _p(0.30, 0.80, size),
        ]),
        Offset.zero);
    _addBase(path, size);
    return path;
  }

  Path _knight(Size size) {
    // Simplified horse-head profile, facing right, with smooth curves for
    // the mane/chest instead of a jagged polygon.
    final path = Path()
      ..moveTo(_p(0.22, 0.88, size).dx, _p(0.22, 0.88, size).dy)
      ..lineTo(_p(0.70, 0.88, size).dx, _p(0.70, 0.88, size).dy)
      ..lineTo(_p(0.74, 0.58, size).dx, _p(0.74, 0.58, size).dy)
      ..quadraticBezierTo(
        _p(0.84, 0.52, size).dx,
        _p(0.84, 0.52, size).dy,
        _p(0.88, 0.42, size).dx,
        _p(0.88, 0.42, size).dy,
      )
      ..lineTo(_p(0.72, 0.40, size).dx, _p(0.72, 0.40, size).dy)
      ..lineTo(_p(0.80, 0.30, size).dx, _p(0.80, 0.30, size).dy)
      ..quadraticBezierTo(
        _p(0.72, 0.20, size).dx,
        _p(0.72, 0.20, size).dy,
        _p(0.58, 0.18, size).dx,
        _p(0.58, 0.18, size).dy,
      )
      ..lineTo(_p(0.66, 0.06, size).dx, _p(0.66, 0.06, size).dy)
      ..lineTo(_p(0.52, 0.20, size).dx, _p(0.52, 0.20, size).dy)
      ..quadraticBezierTo(
        _p(0.34, 0.16, size).dx,
        _p(0.34, 0.16, size).dy,
        _p(0.24, 0.42, size).dx,
        _p(0.24, 0.42, size).dy,
      )
      ..lineTo(_p(0.20, 0.62, size).dx, _p(0.20, 0.62, size).dy)
      ..close();
    _addBase(path, size);
    return path;
  }
}
