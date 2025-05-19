// lib/map_view.dart

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'ros_service.dart';

// TFTransform helper (unchanged)
class TFTransform {
  final double x, y, yaw;
  TFTransform(this.x, this.y, this.yaw);
  factory TFTransform.fromJson(Map j) {
    final t = j['transform'];
    final trans = t['translation'];
    final ori = t['rotation'];
    double qx = ori['x'], qy = ori['y'], qz = ori['z'], qw = ori['w'];
    double ysqr = qy * qy;
    double t3 = 2.0 * (qw * qz + qx * qy);
    double t4 = 1.0 - 2.0 * (ysqr + qz * qz);
    double yaw = atan2(t3, t4);
    return TFTransform(trans['x'], trans['y'], yaw);
  }
}

class MapView extends StatefulWidget {
  const MapView({super.key});
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  List<List<int>> occupancyGrid = [];
  List<TFTransform> transforms = [];
  List<Offset> planPoints = [];
  Offset? goalPoint;
  Offset robotPos = Offset.zero;
  List<double> scanRanges = [];
  double scanAngleMin = 0, scanAngleInc = 0;

  // For AMCL initializer
  Offset? initTap, dragPos;

  StreamSubscription? mapSub, tfSub, planSub, goalSub, scanSub, amclSub;

  @override
  void initState() {
    super.initState();
    final ros = RosService();

    mapSub = ros.subscribe('/map', 'nav_msgs/OccupancyGrid').listen((m) {
      final info = m['msg']['info'];
      final data = (m['msg']['data'] as List).cast<int>();
      setState(() {
        occupancyGrid = List.generate(
          info['height'],
          (r) => data.sublist(
            r * info['width'] as int,
            (r + 1) * info['width'] as int,
          ),
        );
      });
    });

    tfSub = ros.subscribe('/tf', 'tf2_msgs/TFMessage').listen((m) {
      final tfs = (m['msg']['transforms'] as List).cast<Map>();
      setState(() {
        transforms = tfs.map((j) => TFTransform.fromJson(j)).toList();
      });
    });

    planSub = ros.subscribe('/planned_path', 'nav_msgs/Path').listen((m) {
      final poses = (m['msg']['poses'] as List).cast<Map>();
      setState(() {
        planPoints =
            poses.map((p) {
              final pos = p['pose']['position'];
              return Offset(pos['x'], pos['y']);
            }).toList();
      });
    });

    goalSub = ros.subscribe('/goal_pose', 'geometry_msgs/PoseStamped').listen((
      m,
    ) {
      final p = m['msg']['pose']['position'];
      setState(() => goalPoint = Offset(p['x'], p['y']));
    });

    scanSub = ros.subscribe('/scan', 'sensor_msgs/LaserScan').listen((m) {
      setState(() {
        scanRanges = (m['msg']['ranges'] as List).cast<double>();
        scanAngleMin = m['msg']['angle_min'];
        scanAngleInc = m['msg']['angle_increment'];
      });
    });

    amclSub = ros
        .subscribe('/amcl_pose', 'geometry_msgs/PoseWithCovarianceStamped')
        .listen((m) {
          final p = m['msg']['pose']['pose']['position'];
          setState(() => robotPos = Offset(p['x'], p['y']));
        });
  }

  @override
  void dispose() {
    mapSub?.cancel();
    tfSub?.cancel();
    planSub?.cancel();
    goalSub?.cancel();
    scanSub?.cancel();
    amclSub?.cancel();
    super.dispose();
  }

  Offset screenToWorld(Offset p, Size s) => Offset(
    (p.dx / s.width) * 10 - 5,
    ((s.height - p.dy) / s.height) * 10 - 5,
  );

  Offset worldToScreen(Offset w, Size s) {
    return Offset(
      (w.dx + 5) * s.width / 10,
      s.height - (w.dy + 5) * s.height / 10,
    );
  }

  void _onTapDown(TapDownDetails d, Size s) {
    setState(() {
      initTap = screenToWorld(d.localPosition, s);
      dragPos = null;
    });
  }

  void _onPanUpdate(DragUpdateDetails d, Size s) {
    setState(() {
      dragPos = screenToWorld(d.localPosition, s);
    });
  }

  void _onPanEnd(Size s) {
    if (initTap != null && dragPos != null) {
      final dx = dragPos!.dx - initTap!.dx;
      final dy = dragPos!.dy - initTap!.dy;
      final yaw = atan2(dy, dx);
      RosService().publishInitialPose(x: initTap!.dx, y: initTap!.dy, yaw: yaw);
    }
    setState(() {
      initTap = null;
      dragPos = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            constrained: true,
            boundaryMargin: EdgeInsets.all(double.infinity),
            minScale: 0.1,
            maxScale: 10,
            child: LayoutBuilder(
              builder: (ctx, cons) {
                return GestureDetector(
                  onTapDown: (d) => _onTapDown(d, cons.biggest),
                  onPanUpdate: (d) => _onPanUpdate(d, cons.biggest),
                  onPanEnd: (_) => _onPanEnd(cons.biggest),
                  child: CustomPaint(
                    size: cons.biggest,
                    painter: _MapPainter(
                      occupancyGrid: occupancyGrid,
                      transforms: transforms,
                      planPoints: planPoints,
                      goalPoint: goalPoint,
                      robot: robotPos,
                      scanRanges: scanRanges,
                      scanAngleMin: scanAngleMin,
                      scanAngleInc: scanAngleInc,
                      initTap: initTap,
                      dragPos: dragPos,
                      worldToScreen: (w) => worldToScreen(w, cons.biggest),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<List<int>> occupancyGrid;
  final List<TFTransform> transforms;
  final List<Offset> planPoints;
  final Offset? goalPoint;
  final Offset robot;
  final List<double> scanRanges;
  final double scanAngleMin, scanAngleInc;
  final Offset? initTap, dragPos;
  final Offset Function(Offset) worldToScreen;

  _MapPainter({
    required this.occupancyGrid,
    required this.transforms,
    required this.planPoints,
    this.goalPoint,
    required this.robot,
    required this.scanRanges,
    required this.scanAngleMin,
    required this.scanAngleInc,
    this.initTap,
    this.dragPos,
    required this.worldToScreen,
  });

  @override
  void paint(Canvas c, Size s) {
    // 1) Occupancy grid
    final rows = occupancyGrid.length;
    final cols = rows > 0 ? occupancyGrid[0].length : 0;
    final cellW = s.width / cols;
    final cellH = s.height / rows;
    final paintOcc = Paint();
    for (int r = 0; r < rows; r++) {
      for (int j = 0; j < cols; j++) {
        final v = occupancyGrid[r][j];
        paintOcc.color =
            v == 0 ? Colors.white : (v < 0 ? Colors.grey : Colors.black);
        c.drawRect(Rect.fromLTWH(j * cellW, r * cellH, cellW, cellH), paintOcc);
      }
    }

    // 2) Laser scan, clipped to canvas
    final scanPaint =
        Paint()
          ..color = Colors.orange.withOpacity(0.5)
          ..strokeWidth = 1;
    final Rect bounds = Offset.zero & s;
    for (int i = 0; i < scanRanges.length; i++) {
      final ang = scanAngleMin + i * scanAngleInc;
      final r = scanRanges[i];
      // raw endpoint
      Offset end = robot + Offset(r * cos(ang), r * sin(ang));
      // convert to screen
      Offset p1 = worldToScreen(robot);
      Offset p2 = worldToScreen(end);
      // clip line to bounds
      final clipped = _clipLine(bounds, p1, p2);
      if (clipped != null) {
        c.drawLine(clipped.item1, clipped.item2, scanPaint);
      }
    }

    // 3) Planned path
    final pathPaint =
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 3;
    for (int i = 0; i + 1 < planPoints.length; i++) {
      c.drawLine(
        worldToScreen(planPoints[i]),
        worldToScreen(planPoints[i + 1]),
        pathPaint,
      );
    }

    // 4) Goal marker
    if (goalPoint != null) {
      c.drawCircle(worldToScreen(goalPoint!), 8, Paint()..color = Colors.green);
    }

    // 5) TF frames
    for (var tf in transforms) {
      final origin = worldToScreen(Offset(tf.x, tf.y));
      final xend = worldToScreen(
        Offset(tf.x + cos(tf.yaw) * 0.5, tf.y + sin(tf.yaw) * 0.5),
      );
      final yend = worldToScreen(
        Offset(tf.x - sin(tf.yaw) * 0.5, tf.y + cos(tf.yaw) * 0.5),
      );
      c.drawLine(
        origin,
        xend,
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2,
      );
      c.drawLine(
        origin,
        yend,
        Paint()
          ..color = Colors.green
          ..strokeWidth = 2,
      );
    }

    // 6) AMCL initializer crosshair & arrow
    final initPaint =
        Paint()
          ..color = Colors.green
          ..strokeWidth = 2;
    if (initTap != null) {
      final p = worldToScreen(initTap!);
      c.drawLine(p + Offset(-10, 0), p + Offset(10, 0), initPaint);
      c.drawLine(p + Offset(0, -10), p + Offset(0, 10), initPaint);
    }
    if (initTap != null && dragPos != null) {
      final p1 = worldToScreen(initTap!);
      final p2 = worldToScreen(dragPos!);
      c.drawLine(p1, p2, initPaint);
      final ang = (p2 - p1).direction;
      const head = 8.0;
      final left = p2 + Offset.fromDirection(ang + pi * 3 / 4, head);
      final right = p2 + Offset.fromDirection(ang - pi * 3 / 4, head);
      c.drawLine(p2, left, initPaint);
      c.drawLine(p2, right, initPaint);
    }

    // 7) Robot pose
    c.drawCircle(worldToScreen(robot), 6, Paint()..color = Colors.red);
  }

  /// Cohen–Sutherland or Liang–Barsky would be ideal, but for simplicity:
  /// Clip by simply clamping endpoints to bounds rectangle.
  /// Returns a tuple of clipped points if at least one end was inside originally.
  Tuple2<Offset, Offset>? _clipLine(Rect bounds, Offset a, Offset b) {
    // If both points are outside on the same side, skip
    if (!_pointInOrOn(bounds, a) && !_pointInOrOn(bounds, b)) {
      return null;
    }
    // Clamp each point
    Offset ca = Offset(
      a.dx.clamp(bounds.left, bounds.right),
      a.dy.clamp(bounds.top, bounds.bottom),
    );
    Offset cb = Offset(
      b.dx.clamp(bounds.left, bounds.right),
      b.dy.clamp(bounds.top, bounds.bottom),
    );
    return Tuple2(ca, cb);
  }

  bool _pointInOrOn(Rect r, Offset p) =>
      p.dx >= r.left && p.dx <= r.right && p.dy >= r.top && p.dy <= r.bottom;

  @override
  bool shouldRepaint(covariant _MapPainter o) =>
      o.occupancyGrid != occupancyGrid ||
      o.transforms != transforms ||
      o.planPoints != planPoints ||
      o.goalPoint != goalPoint ||
      o.robot != robot ||
      o.scanRanges != scanRanges ||
      o.initTap != initTap ||
      o.dragPos != dragPos;
}

/// Simple tuple since Flutter lacks one
class Tuple2<A, B> {
  final A item1;
  final B item2;
  Tuple2(this.item1, this.item2);
}
