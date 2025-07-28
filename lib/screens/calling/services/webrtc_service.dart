// screens/calling/services/webrtc_service.dart

import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final _remoteStreamController = StreamController<MediaStream>.broadcast();

  // Queue for ICE candidates that arrive before peer connection is ready
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _isInitialized = false;

  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;

  // Free STUN servers
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ]
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false,
    },
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final Map<String, dynamic> _audioConstraints = {
    'audio': true,
    'video': false,
  };

  // ICE Candidate callback
  Function(RTCIceCandidate)? onIceCandidate;
  Function()? onIceConnectionStateChange;

  Future<void> initialize() async {
    if (_isInitialized) {
      print('WebRTC already initialized');
      return;
    }

    // Create local stream first
    await _createLocalStream();
    // Then create peer connection
    await _createPeerConnection();

    _isInitialized = true;

    // Process any pending ICE candidates
    await _processPendingIceCandidates();
  }

  Future<void> _createLocalStream() async {
    try {
      print('Creating local stream...');
      _localStream = await navigator.mediaDevices.getUserMedia(_audioConstraints);

      final audioTracks = _localStream!.getAudioTracks();
      print('Got ${audioTracks.length} local audio tracks');

      for (final track in audioTracks) {
        track.enabled = true;
        // Set to earpiece by default (false = earpiece, true = speaker)
        track.enableSpeakerphone(false);
        print('Local audio track: ${track.label}, id: ${track.id}, enabled: ${track.enabled}, speaker: false');
      }
    } catch (e) {
      print('Error accessing microphone: $e');
      throw Exception('Microphone access denied: $e');
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      print('Creating peer connection...');
      _peerConnection = await createPeerConnection(_configuration);

      // Add local stream tracks to peer connection
      if (_localStream != null) {
        // Add all tracks from local stream
        _localStream!.getTracks().forEach((track) async {
          await _peerConnection!.addTrack(track, _localStream!);
          print('Added track to peer connection: ${track.kind}');
        });
      }

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          print('Got ICE candidate: ${candidate.candidate}');
          onIceCandidate?.call(candidate);
        }
      };

      // Listen for remote tracks
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('Got remote track: ${event.track.kind}');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams.first;
          print('Remote stream has ${_remoteStream!.getAudioTracks().length} audio tracks');

          // Set audio output to earpiece by default
          for (final track in _remoteStream!.getAudioTracks()) {
            track.enableSpeakerphone(false); // false = earpiece
            print('Remote audio track set to earpiece');
          }

          _remoteStreamController.add(_remoteStream!);
        }
      };

      // Monitor connection state
      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('ICE Connection State: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          print('ICE Connected! Audio should be flowing now.');
        }
        onIceConnectionStateChange?.call();
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('Connection State: $state');
      };

      _peerConnection!.onSignalingState = (RTCSignalingState state) {
        print('Signaling State: $state');
      };
    } catch (e) {
      print('Error creating peer connection: $e');
      throw Exception('Failed to create peer connection: $e');
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }

    print('Creating offer...');
    final RTCSessionDescription offer = await _peerConnection!.createOffer(_constraints);
    print('Offer SDP: ${offer.sdp}');

    await _peerConnection!.setLocalDescription(offer);
    print('Set local description (offer)');

    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }

    print('Creating answer...');
    final RTCSessionDescription answer = await _peerConnection!.createAnswer(_constraints);
    print('Answer SDP: ${answer.sdp}');

    await _peerConnection!.setLocalDescription(answer);
    print('Set local description (answer)');

    return answer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    if (_peerConnection == null) {
      throw Exception('Peer connection not initialized');
    }

    try {
      print('Setting remote description: ${description.type}');
      await _peerConnection!.setRemoteDescription(description);
      print('Remote description set successfully');

      // Process pending ICE candidates after setting remote description
      await _processPendingIceCandidates();
    } catch (e) {
      print('Error setting remote description: $e');
      throw e;
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    print('Adding ICE candidate...');

    // If peer connection is not ready or remote description not set, queue the candidate
    if (_peerConnection == null ||
        !_isInitialized ||
        _peerConnection!.signalingState != RTCSignalingState.RTCSignalingStateStable) {
      print('Peer connection not ready, queuing ICE candidate');
      _pendingIceCandidates.add(candidate);
      return;
    }

    try {
      await _peerConnection!.addCandidate(candidate);
      print('Successfully added ICE candidate');
    } catch (e) {
      print('Error adding ICE candidate: $e - queuing for later');
      _pendingIceCandidates.add(candidate);
    }
  }

  Future<void> _processPendingIceCandidates() async {
    if (_pendingIceCandidates.isEmpty) return;

    print('Processing ${_pendingIceCandidates.length} pending ICE candidates');

    for (final candidate in _pendingIceCandidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
        print('Successfully added pending ICE candidate');
      } catch (e) {
        print('Error adding pending ICE candidate: $e');
      }
    }

    _pendingIceCandidates.clear();
  }

  void toggleMute(bool mute) {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !mute;
        print('Local audio track muted: $mute');
      });
    }
  }

  void toggleSpeaker(bool speakerOn) {
    // Apply to local stream
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enableSpeakerphone(speakerOn);
        print('Local speaker enabled: $speakerOn');
      });
    }

    // Apply to remote stream
    if (_remoteStream != null) {
      _remoteStream!.getAudioTracks().forEach((track) {
        track.enableSpeakerphone(speakerOn);
        print('Remote speaker enabled: $speakerOn');
      });
    }
  }

  RTCPeerConnectionState? getConnectionState() {
    return _peerConnection?.connectionState;
  }

  Future<void> dispose() async {
    try {
      print('Disposing WebRTC resources...');
      _isInitialized = false;
      _pendingIceCandidates.clear();

      // Close local stream
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          track.stop();
        });
        await _localStream!.dispose();
        _localStream = null;
      }

      // Close peer connection
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }

      // Close stream controller
      if (!_remoteStreamController.isClosed) {
        await _remoteStreamController.close();
      }
    } catch (e) {
      print('Error disposing WebRTC resources: $e');
    }
  }

  // Get connection info for debugging
  Future<void> getConnectionInfo() async {
    if (_peerConnection == null) return;

    print('\n=== WebRTC Connection Info ===');
    print('Connection State: ${_peerConnection!.connectionState}');
    print('ICE Connection State: ${_peerConnection!.iceConnectionState}');
    print('ICE Gathering State: ${_peerConnection!.iceGatheringState}');
    print('Signaling State: ${_peerConnection!.signalingState}');

    if (_localStream != null) {
      print('Local audio tracks: ${_localStream!.getAudioTracks().length}');
      for (final track in _localStream!.getAudioTracks()) {
        print('  - Track: ${track.label}, enabled: ${track.enabled}');
      }
    }

    if (_remoteStream != null) {
      print('Remote audio tracks: ${_remoteStream!.getAudioTracks().length}');
      for (final track in _remoteStream!.getAudioTracks()) {
        print('  - Track: ${track.label}, enabled: ${track.enabled}');
      }
    }

    // Get stats
    try {
      final stats = await _peerConnection!.getStats();
      for (final stat in stats) {
        if (stat.type == 'candidate-pair' && stat.values['state'] == 'succeeded') {
          print('Active candidate pair found:');
          print('  - Local: ${stat.values['localCandidateId']}');
          print('  - Remote: ${stat.values['remoteCandidateId']}');
          print('  - Bytes sent: ${stat.values['bytesSent']}');
          print('  - Bytes received: ${stat.values['bytesReceived']}');
        }
      }
    } catch (e) {
      print('Error getting stats: $e');
    }
    print('==============================\n');
  }
}