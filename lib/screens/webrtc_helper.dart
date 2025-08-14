import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class WebRTCService {
  MediaStream? localStream;
  MediaStream? remoteStream;
  RTCPeerConnection? _peerConnection;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isInitialized = false;
  String? roomId;
  Function()? onRemoteStreamUpdated;
  Set<String> iceCandidateCache = {}; // Store ICE candidates to prevent duplicates

  /// Initializes WebRTC and connects to Firestore
  Future<void> initialize({String? existingRoomId}) async {
    roomId = existingRoomId ?? _generateRoomId();
    print("📢 Initializing WebRTC for Room: $roomId");

    Map<String, dynamic> config = {
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]
    };

    _peerConnection = await createPeerConnection(config);

    // ✅ Handle Remote Stream (Fixed)
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print("📢 Track Event Received: ${event.track.kind}");

      if (event.streams.isNotEmpty) {
        if (remoteStream == null) {
          remoteStream = event.streams.first;
          print("✅ Remote stream initialized successfully!");
        }

        for (var track in event.streams.first.getTracks()) {
          if (!remoteStream!.getTracks().contains(track)) {
            remoteStream!.addTrack(track);
            print("📢 Track added to remote stream: ${track.kind}");
          }
        }

        // ✅ Notify UI to update remote video
        if (onRemoteStreamUpdated != null) {
          onRemoteStreamUpdated!();
        }
      } else {
        print("❌ No streams found in Track Event!");
      }
    };

    // ✅ Start local stream
    await _initializeLocalStream();

    // ✅ Setup signaling (listen to SDP & ICE candidates)
    _setupSignaling();

    isInitialized = true;
  }

  /// Creates a new room and generates an SDP offer (for doctors)
  Future<void> createCall(String doctorId, String patientId) async {
    if (_peerConnection == null) {
      print("❌ _peerConnection is NULL! Did you call initialize()?");
      return;
    }
    if (roomId == null) {
      print("❌ roomId is NULL! Initialization failed?");
      return;
    }

    print("📢 Creating SDP Offer...");
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    DocumentReference roomRef = _firestore.collection('calls').doc(roomId);
    await roomRef.set({
      'doctorId': doctorId,
      'patientId': patientId,
      'status': 'calling',
      'timestamp': FieldValue.serverTimestamp(),
      'offer': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    }, SetOptions(merge: true));

    print("✅ SDP Offer stored in Firestore.");
  }

  /// Joins an existing call by reading SDP Offer (for patients)
  Future<void> joinCall(String roomId, String patientId) async {
    if (_peerConnection == null) {
      await initialize(existingRoomId: roomId);
    }

    this.roomId = roomId;
    DocumentReference roomRef = _firestore.collection('calls').doc(roomId);
    var roomSnapshot = await roomRef.get();

    if (!roomSnapshot.exists) {
      print("❌ Room does not exist!");
      return;
    }

    var data = roomSnapshot.data() as Map<String, dynamic>;
    if (data.containsKey('offer')) {
      var offerData = data['offer'];
      RTCSessionDescription offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
      await _peerConnection!.setRemoteDescription(offer);
      print("📢 SDP Offer received and set.");

      // ✅ Generate and send SDP Answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      await roomRef.update({
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
        'patientId': patientId,
      });
      print("✅ SDP Answer sent.");
    }
  }

  Future<void> handleAnswer(String sdp) async {
    if (_peerConnection == null) {
      print("❌ Cannot set remote SDP: PeerConnection is NULL!");
      return;
    }

    RTCSessionDescription answer = RTCSessionDescription(sdp, "answer");

    await _peerConnection!.setRemoteDescription(answer);
    print("✅ Remote SDP (Answer) Set Successfully!");
  }

  /// Sets up signaling to exchange SDP and ICE candidates
  void _setupSignaling() {
    DocumentReference roomRef = _firestore.collection('calls').doc(roomId);

    // ✅ Listen for SDP Answer
    roomRef.snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;

        if (data.containsKey('answer')) {
          var answerData = data['answer'];
          RTCSessionDescription answer = RTCSessionDescription(answerData['sdp'], answerData['type']);

          if ((await _peerConnection!.getRemoteDescription()) == null) {
            await _peerConnection!.setRemoteDescription(answer);
            print("✅ SDP Answer set. Remote video should be visible.");
          } else {
            print("⚠️ Remote Description already set!");
          }
        }
      }
    });

    // ✅ Listen for ICE Candidates (Ensure remote SDP is set before adding)
    roomRef.collection('candidates').snapshots().listen((snapshot) async {
      for (var doc in snapshot.docs) {
        var data = doc.data();
        String candidateKey = data['candidate'];

        if (!iceCandidateCache.contains(candidateKey)) {
          iceCandidateCache.add(candidateKey);
          RTCIceCandidate candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );

          // ✅ Ensure remote SDP is set before adding ICE candidates
          var remoteDesc = await _peerConnection!.getRemoteDescription();
          if (remoteDesc == null) {
            print("❌ Remote description is NULL! Waiting before adding ICE Candidate.");
            await Future.delayed(Duration(seconds: 2)); // Wait for SDP
            remoteDesc = await _peerConnection!.getRemoteDescription(); // Re-check
          }

          if (remoteDesc != null) {
            await _peerConnection!.addCandidate(candidate);
            print("✅ ICE Candidate added: ${data['candidate']}");
          } else {
            print("❌ Still NULL, skipping ICE Candidate.");
          }
        }
      }
    });

    // ✅ Send local ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (roomId != null) {
        roomRef.collection('candidates').add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
        print("📢 ICE Candidate sent.");
      }
    };
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) {
      print("❌ Cannot add ICE Candidate: PeerConnection is NULL!");
      return;
    }

    // 🔹 Ensure the remote description is set before adding candidates
    var remoteDesc = await _peerConnection!.getRemoteDescription();
    if (remoteDesc == null) {
      print("❌ Remote description is NULL! Delaying ICE Candidate addition.");
      await Future.delayed(Duration(seconds: 2)); // Wait for remote SDP
      remoteDesc = await _peerConnection!.getRemoteDescription(); // Re-check
      if (remoteDesc == null) {
        print("❌ Still NULL, skipping ICE Candidate.");
        return;
      }
    }

    print("✅ Adding ICE Candidate: ${candidate.candidate}");
    await _peerConnection!.addCandidate(candidate);
  }
  /// Ensures local stream is added correctly
  Future<void> _initializeLocalStream() async {
    localStream = await navigator.mediaDevices.getUserMedia({
      'video': true,
      'audio': true,
    });

    // ✅ Properly attach local stream
    for (var track in localStream!.getTracks()) {
      _peerConnection!.addTrack(track, localStream!);
    }

    print("✅ Local stream initialized and tracks added.");
  }

  /// Generates a random room ID
  String _generateRoomId() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  /// Ends the call
  Future<void> endCall() async {
    if (roomId != null) {
      await _firestore.collection('calls').doc(roomId).delete();
      print("❌ Call ended. Room deleted.");
    }
    await _peerConnection?.close();
    _peerConnection = null;
    isInitialized = false;
  }
}
