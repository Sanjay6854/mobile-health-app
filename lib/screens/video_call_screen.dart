import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_helper.dart';

class VideoCallScreen extends StatefulWidget {
  final WebRTCService webrtcService;
  VideoCallScreen(this.webrtcService);

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRenderers();
    });
  }

  void _onRemoteStream(MediaStream stream) {
    if (mounted) {
      setState(() {
        _remoteRenderer.srcObject = stream;  // Attach stream to UI
      });
    }
  }

  /// ✅ Initializes Renderers & Attaches Streams
  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // ✅ Attach local stream
    if (widget.webrtcService.localStream != null) {
      print("✅ Local stream attached.");
      setState(() {
        _localRenderer.srcObject = widget.webrtcService.localStream;
      });
    } else {
      print("❌ Local stream is NULL!");
    }

    // ✅ Ensure remote stream updates properly
    widget.webrtcService.onRemoteStreamUpdated = () {
      if (mounted) {
        print("📢 Updating remote stream in UI!");
        _onRemoteStream(widget.webrtcService.remoteStream!);  // ✅ Call the function
      }
    };

    // ✅ Attach remote stream if already available
    if (widget.webrtcService.remoteStream != null) {
      print("✅ Remote stream attached.");
      setState(() {
        _remoteRenderer.srcObject = widget.webrtcService.remoteStream;
      });
    } else {
      print("❌ Remote stream is NULL!");
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Video Consultation")),
      body: Column(
        children: [
          // 🔹 Remote Video (Doctor/Patient)
          Expanded(
            child: RTCVideoView(
              _remoteRenderer,
              mirror: false,
            ),
          ),

          // 🔹 Local Video (Self View)
          Expanded(
            child: RTCVideoView(
              _localRenderer,
              mirror: true, // Front camera correction
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              await widget.webrtcService.endCall();
              Navigator.pop(context);
            },
            child: const Text("End Call"),
          ),
        ],
      ),
    );
  }
}
