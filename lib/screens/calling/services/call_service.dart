// screens/calling/services/call_service.dart

import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/call_models.dart';
import 'webrtc_service.dart';

class CallService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final WebRTCService _webRTCService = WebRTCService();
  final _uuid = const Uuid();

  RealtimeChannel? _signalChannel;
  RealtimeChannel? _callStatusChannel;
  Call? _currentCall;
  Timer? _callDurationTimer;
  bool _isEndingCall = false; // Add this flag

  // Callbacks
  Function(Call)? onIncomingCall;
  Function(CallStatus)? onCallStatusChanged;
  Function()? onCallEnded;

  String get currentUserId => _supabase.auth.currentUser!.id;
  Call? get currentCall => _currentCall;
  WebRTCService get webRTCService => _webRTCService;

  Future<void> initialize() async {
    await _setupRealtimeListeners();

    // Setup WebRTC callbacks
    _webRTCService.onIceCandidate = (candidate) {
      if (_currentCall != null) {
        _sendSignal(
          SignalType.iceCandidate,
          {
            'candidate': candidate.candidate,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'sdpMid': candidate.sdpMid,
          },
        );
      }
    };
  }

  Future<void> _setupRealtimeListeners() async {
    // Listen for incoming signals
    _signalChannel = _supabase
        .channel('call_signals:${currentUserId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'call_signals',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'to_user_id',
        value: currentUserId,
      ),
      callback: (payload) => _handleIncomingSignal(payload.newRecord as Map<String, dynamic>),
    )
        .subscribe();

    // Listen for call status updates
    _callStatusChannel = _supabase
        .channel('calls:${currentUserId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'calls',
      callback: (payload) => _handleCallStatusUpdate(payload.newRecord as Map<String, dynamic>),
    )
        .subscribe();
  }

  Future<void> _handleIncomingSignal(Map<String, dynamic> signalData) async {
    final signal = CallSignal.fromJson(signalData);

    switch (signal.signalType) {
      case SignalType.offer:
        await _handleIncomingCall(signal);
        break;
      case SignalType.answer:
        await _handleAnswer(signal);
        break;
      case SignalType.iceCandidate:
        await _handleIceCandidate(signal);
        break;
      case SignalType.endCall:
        await endCall();
        break;
      case SignalType.rejectCall:
        await _handleCallRejected();
        break;
    }
  }

  Future<void> _handleIncomingCall(CallSignal signal) async {
    // Check if this is a call to self (same device, different account)
    if (signal.fromUserId == currentUserId) {
      print('Ignoring self-call from same device');
      return;
    }

    // Check if there's already an active call
    if (_currentCall != null && _currentCall!.isActive) {
      // Busy - reject the call
      await _sendSignal(SignalType.rejectCall, {'reason': 'busy'}, callId: signal.callId);
      return;
    }

    // Get call details
    final callResponse = await _supabase
        .from('calls')
        .select()
        .eq('id', signal.callId)
        .single();

    _currentCall = Call.fromJson(callResponse);

    // Get caller info
    final callerResponse = await _supabase
        .from('users')
        .select('id, username, profile_image_url')
        .eq('id', _currentCall!.callerId)
        .single();

    final callerInfo = CallerInfo(
      userId: callerResponse['id'],
      username: callerResponse['username'],
      profileImageUrl: callerResponse['profile_image_url'],
    );

    // Initialize WebRTC
    await _webRTCService.initialize();

    // Set remote description
    final offer = RTCSessionDescription(
      signal.signalData['sdp'],
      signal.signalData['type'],
    );
    await _webRTCService.setRemoteDescription(offer);

    // Update call status to ringing
    await _updateCallStatus(CallStatus.ringing);

    // Notify UI about incoming call
    onIncomingCall?.call(_currentCall!);
  }

  Future<void> _handleAnswer(CallSignal signal) async {
    if (_currentCall == null) return;

    final answer = RTCSessionDescription(
      signal.signalData['sdp'],
      signal.signalData['type'],
    );
    await _webRTCService.setRemoteDescription(answer);

    // Process any pending ICE candidates after setting remote description
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _handleIceCandidate(CallSignal signal) async {
    try {
      final candidate = RTCIceCandidate(
        signal.signalData['candidate'],
        signal.signalData['sdpMid'],
        signal.signalData['sdpMLineIndex'],
      );
      await _webRTCService.addIceCandidate(candidate);
    } catch (e) {
      print('Error handling ICE candidate: $e');
    }
  }

  Future<void> _handleCallStatusUpdate(Map<String, dynamic> callData) async {
    if (_currentCall == null || callData['id'] != _currentCall!.id) return;

    final updatedCall = Call.fromJson(callData);
    _currentCall = updatedCall;

    onCallStatusChanged?.call(updatedCall.status);

    if (updatedCall.status == CallStatus.answered && _callDurationTimer == null) {
      _startCallDurationTimer();
    } else if (!updatedCall.isActive) {
      await endCall();
    }
  }

  Future<void> _handleCallRejected() async {
    _currentCall = await _updateCallStatus(CallStatus.declined);
    onCallStatusChanged?.call(CallStatus.declined);
    await Future.delayed(const Duration(seconds: 2));
    await endCall();
  }

  // Initiate a call
  Future<Call?> initiateCall(String receiverId) async {
    try {
      // Check for existing active call
      final activeCallResponse = await _supabase
          .rpc('get_active_call', params: {
        'user1_id': currentUserId,
        'user2_id': receiverId,
      });

      if (activeCallResponse != null && (activeCallResponse as List).isNotEmpty) {
        // There's already an active call
        return null;
      }

      // Create new call record
      final callId = _uuid.v4();
      final callResponse = await _supabase
          .from('calls')
          .insert({
        'id': callId,
        'caller_id': currentUserId,
        'receiver_id': receiverId,
        'status': CallStatus.initiated.name,
      })
          .select()
          .single();

      _currentCall = Call.fromJson(callResponse);

      // Initialize WebRTC
      await _webRTCService.initialize();

      // Create offer
      final offer = await _webRTCService.createOffer();

      // Send offer signal
      await _sendSignal(
        SignalType.offer,
        {
          'sdp': offer.sdp,
          'type': offer.type,
        },
      );

      return _currentCall;
    } catch (e) {
      print('Error initiating call: $e');
      await endCall();
      return null;
    }
  }

  // Accept incoming call
  Future<void> acceptCall() async {
    if (_currentCall == null) return;

    try {
      // Create answer
      final answer = await _webRTCService.createAnswer();

      // Send answer signal
      await _sendSignal(
        SignalType.answer,
        {
          'sdp': answer.sdp,
          'type': answer.type,
        },
      );

      // Update call status
      await _updateCallStatus(CallStatus.answered);

      // Start duration timer
      _startCallDurationTimer();
    } catch (e) {
      print('Error accepting call: $e');
      await endCall();
    }
  }

  // Reject incoming call
  Future<void> rejectCall() async {
    if (_currentCall == null) return;

    await _sendSignal(SignalType.rejectCall, {'reason': 'rejected'});
    await _updateCallStatus(CallStatus.declined);
    // await endCall();
  }

  // End call
  Future<void> endCall() async {
    // Modify the guard to check the new flag
    if (_currentCall == null || _isEndingCall) return;

    try {
      _isEndingCall = true; // Set the flag to true
      // Send end signal
      await _sendSignal(SignalType.endCall, {});

      // Calculate duration if call was answered
      int? duration;
      if (_currentCall!.status == CallStatus.answered && _currentCall!.answeredAt != null) {
        duration = DateTime.now().difference(_currentCall!.answeredAt!).inSeconds;
      }

      // Update call status
      await _supabase
          .from('calls')
          .update({
        'status': CallStatus.ended.name,
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'ended_by': currentUserId,
        'duration_seconds': duration,
      })
          .eq('id', _currentCall!.id);
    } catch (e) {
      print('Error ending call: $e');
    } finally {
      // Cleanup
      _callDurationTimer?.cancel();
      _callDurationTimer = null;
      await _webRTCService.dispose();
      _currentCall = null;
      onCallEnded?.call();
      _isEndingCall = false; // Reset the flag
    }
  }

  Future<void> _sendSignal(SignalType type, Map<String, dynamic> data, {String? callId}) async {
    if (_currentCall == null && callId == null) return;

    final targetUserId = _currentCall!.callerId == currentUserId
        ? _currentCall!.receiverId
        : _currentCall!.callerId;

    await _supabase.from('call_signals').insert({
      'call_id': callId ?? _currentCall!.id,
      'from_user_id': currentUserId,
      'to_user_id': targetUserId,
      'signal_type': _mapSignalTypeToDb(type),
      'signal_data': data,
    });
  }

  String _mapSignalTypeToDb(SignalType type) {
    switch (type) {
      case SignalType.iceCandidate:
        return 'ice_candidate';
      case SignalType.endCall:
        return 'end_call';
      case SignalType.rejectCall:
        return 'reject_call';
      default:
        return type.name;
    }
  }

  Future<Call> _updateCallStatus(CallStatus status) async {
    final updateData = <String, dynamic>{
      'status': status.name,
    };

    if (status == CallStatus.answered) {
      updateData['answered_at'] = DateTime.now().toUtc().toIso8601String();
    }

    final response = await _supabase
        .from('calls')
        .update(updateData)
        .eq('id', _currentCall!.id)
        .select()
        .single();

    _currentCall = Call.fromJson(response);
    return _currentCall!;
  }

  void _startCallDurationTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // You can emit duration updates here if needed
    });
  }

  void toggleMute(bool mute) {
    _webRTCService.toggleMute(mute);
  }

  void toggleSpeaker(bool speakerOn) {
    _webRTCService.toggleSpeaker(speakerOn);
  }

  Future<Call?> checkForActiveCall() async {
    // If we already have a call in memory, return it
    if (_currentCall != null && _currentCall!.isActive) {
      return _currentCall;
    }

    try {
      // Otherwise, check the database
      final response = await _supabase
          .from('calls')
          .select()
          .or('caller_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
          .inFilter('status', ['initiated', 'ringing', 'answered']) // Active call statuses
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        // If a call is found, update the state and return it
        _currentCall = Call.fromJson(response);
        print('Found active call from database: ${_currentCall!.id}');
        return _currentCall;
      }
    } catch (e) {
      print('Error checking for active call: $e');
    }

    return null; // No active call found
  }

  Future<CallSignal?> getInitialOfferForCall(String callId) async {
    try {
      final response = await _supabase
          .from('call_signals')
          .select()
          .eq('call_id', callId)
          .eq('signal_type', 'offer') // Look specifically for the 'offer' signal
          .order('created_at', ascending: true)
          .limit(1)
          .single();
      return CallSignal.fromJson(response);
    } catch (e) {
      print("Error fetching initial offer: $e");
      return null;
    }
  }

  Future<void> dispose() async {
    await endCall();
    await _signalChannel?.unsubscribe();
    await _callStatusChannel?.unsubscribe();
  }
}