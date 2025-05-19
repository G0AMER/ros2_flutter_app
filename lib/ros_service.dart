import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:math' as math;

class RosService {
  static final RosService _instance = RosService._internal();
  factory RosService() => _instance;
  RosService._internal();

  late WebSocketChannel _channel;
  late Stream<dynamic> _broadcastStream;
  final _topicStreams = <String, Stream<Map<String, dynamic>>>{};

  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    // make broadcast so multiple listeners can subscribe
    _broadcastStream = _channel.stream.asBroadcastStream();
  }

  Stream<Map<String, dynamic>> subscribe(String topic, String type) {
    if (_topicStreams.containsKey(topic)) return _topicStreams[topic]!;
    _channel.sink.add(
      jsonEncode({'op': 'subscribe', 'topic': topic, 'type': type}),
    );
    final stream =
        _broadcastStream
            .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
            .where((m) => m['topic'] == topic)
            .cast<Map<String, dynamic>>();
    _topicStreams[topic] = stream;
    return stream;
  }

  void publish(String topic, Map<String, dynamic> msg) {
    _channel.sink.add(
      jsonEncode({'op': 'publish', 'topic': topic, 'msg': msg}),
    );
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

  void dispose() => _channel.sink.close();
}
