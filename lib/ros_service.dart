import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
class RosService {
  static final RosService _instance = RosService._internal();
  factory RosService() => _instance;
  RosService._internal();

  WebSocketChannel? _channel;
  Stream<dynamic>? _broadcastStream;
  final _topicStreams = <String, Stream<Map<String, dynamic>>>{};

  void connect(String url, Function onConnected, Function onError) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _broadcastStream = _channel!.stream.asBroadcastStream();
      onConnected();
    } catch (e) {
      onError(e.toString());
    }
  }

  void reconnect(String url, Function onConnected, Function onError) {
    dispose();
    Future.delayed(const Duration(seconds: 2), () {
      connect(url, onConnected, onError);
    });
  }

  Stream<Map<String, dynamic>> subscribe(String topic, String type) {
    if (_topicStreams.containsKey(topic)) return _topicStreams[topic]!;
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(
      jsonEncode({'op': 'subscribe', 'topic': topic, 'type': type}),
    );
    final stream = _broadcastStream!
        .map((m) {
      try {
        return jsonDecode(m as String) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Invalid message format: $e');
      }
    })
        .where((m) => m['topic'] == topic)
        .cast<Map<String, dynamic>>();
    _topicStreams[topic] = stream;
    return stream;
  }

  void publish(String topic, Map<String, dynamic> msg) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(
        jsonEncode({'op': 'publish', 'topic': topic, 'msg': msg}),
      );
    } catch (e) {
      // Handle publish error silently or log it
    }
  }

  void publishInitialPose({
    required double x,
    required double y,
    required double yaw,
  }) {
    final now = DateTime.now();
    final header = {
      'stamp': {
        'sec': now.millisecondsSinceEpoch ~/ 1000,
        'nanosec': (now.millisecondsSinceEpoch % 1000) * 1000000,
      },
      'frame_id': 'map',
    };
    final msg = {
      'header': header,
      'pose': {
        'pose': {
          'position': {'x': x, 'y': y, 'z': 0.0},
          'orientation': {
            'x': 0.0,
            'y': 0.0,
            'z': math.sin(yaw / 2),
            'w': math.cos(yaw / 2),
          },
        },
        'covariance': List<double>.filled(36, 0.0),
      },
    };
    publish('/initialpose', msg);
  }

  void publishGoalPose({
    required double x,
    required double y,
    required double yaw,
  }) {
    final now = DateTime.now();
    final header = {
      'stamp': {
        'sec': now.millisecondsSinceEpoch ~/ 1000,
        'nanosec': (now.millisecondsSinceEpoch % 1000) * 1000000,
      },
      'frame_id': 'map',
    };
    final msg = {
      'header': header,
      'pose': {
        'position': {'x': x, 'y': y, 'z': 0.0},
        'orientation': {
          'x': 0.0,
          'y': 0.0,
          'z': math.sin(yaw / 2),
          'w': math.cos(yaw / 2),
        },
      },
    };
    publish('/move_base_simple/goal', msg);
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
    _topicStreams.clear();
  }
}

class RosModel extends ChangeNotifier {
  final RosService _rosService = RosService();
  Map<String, dynamic>? robotPose;
  Map<String, dynamic>? mapData;
  List<dynamic>? scanData;
  bool isConnected = false;
  String mode = 'view'; // 'view', 'initial_pose', 'goal_pose'
  String? connectionError;

  RosModel() {
    connect();
    subscribeToTopics();
  }

  void connect() {
    _rosService.connect(
      'ws://192.168.0.6:9090',
          () {
        isConnected = true;
        connectionError = null;
        notifyListeners();
      },
          (error) {
        isConnected = false;
        connectionError = error;
        notifyListeners();
        reconnect();
      },
    );
  }

  void reconnect() {
    _rosService.reconnect(
      'ws://192.168.0.6:9090',
          () {
        isConnected = true;
        connectionError = null;
        subscribeToTopics();
        notifyListeners();
      },
          (error) {
        isConnected = false;
        connectionError = error;
        notifyListeners();
        reconnect();
      },
    );
  }

  void subscribeToTopics() {
    try {
      _rosService
          .subscribe('/amcl_pose', 'geometry_msgs/PoseWithCovarianceStamped')
          .listen(
            (msg) {
          robotPose = msg['msg']['pose']['pose'];
          notifyListeners();
        },
        onError: (e) {
          connectionError = e.toString();
          isConnected = false;
          notifyListeners();
          reconnect();
        },
      );

      _rosService.subscribe('/map', 'nav_msgs/OccupancyGrid').listen(
            (msg) {
          mapData = msg['msg'];
          notifyListeners();
        },
        onError: (e) {
          connectionError = e.toString();
          notifyListeners();
        },
      );

      _rosService.subscribe('/scan', 'sensor_msgs/LaserScan').listen(
            (msg) {
          scanData = msg['msg']['ranges'];
          notifyListeners();
        },
        onError: (e) {
          connectionError = e.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      connectionError = e.toString();
      isConnected = false;
      notifyListeners();
      reconnect();
    }
  }

  void setMode(String newMode) {
    mode = newMode;
    notifyListeners();
  }

  void setInitialPose(double x, double y, double yaw) {
    _rosService.publishInitialPose(x: x, y: y, yaw: yaw);
  }

  void setGoalPose(double x, double y, double yaw) {
    _rosService.publishGoalPose(x: x, y: y, yaw: yaw);
  }

  @override
  void dispose() {
    _rosService.dispose();
    super.dispose();
  }
}