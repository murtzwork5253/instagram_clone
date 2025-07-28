// screens/calling/call_manager.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/call_service.dart';
import 'models/call_models.dart';
import 'outgoing_call_screen.dart';
import 'incoming_call_screen.dart';
import 'in_call_screen.dart';

class CallManager {
  static final CallManager _instance = CallManager._internal();
  factory CallManager() => _instance;
  CallManager._internal();

  final CallService _callService = CallService();
  bool _isInitialized = false;
  BuildContext? _context;

  // Track active call UI
  bool _isCallUIActive = false;
  String? _activeCallUserId;
  String? _activeCallUserName;
  String? _activeCallUserProfileUrl;

  // Public getters
  CallService get callService => _callService;
  bool get isCallUIActive => _isCallUIActive;

  // Initialize the call manager
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;

    _context = context;

    // Initialize call service
    await _callService.initialize();

    // Setup incoming call handler
    _callService.onIncomingCall = (Call call) async {
      await _handleIncomingCall(call);
    };

    _isInitialized = true;
  }

  // Make an outgoing call
  Future<void> makeCall({
    required BuildContext context,
    required String receiverId,
    required String receiverName,
    String? receiverProfileUrl,
  }) async {
    // Check if trying to call yourself
    if (receiverId == _callService.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot call yourself')),
      );
      return;
    }

    // Check if calling from same device (for multi-account scenarios)
    final deviceId = await _getDeviceId();
    final isCallingSameDevice = await _checkIfSameDevice(receiverId, deviceId);

    if (isCallingSameDevice) {
      _showSameDeviceWarning(context, receiverName);
      return;
    }

    // Check if there's already an active call
    if (_callService.currentCall != null && _callService.currentCall!.isActive) {
      // Check if it's the same user
      if (_callService.currentCall!.receiverId == receiverId ||
          _callService.currentCall!.callerId == receiverId) {
        // Return to existing call screen
        navigateToActiveCall(context);
        return;
      } else {
        // Different user, show error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already in a call')),
        );
        return;
      }
    }

    // Check microphone permission
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      _showPermissionDeniedDialog(context);
      return;
    }

    // Store call info
    _activeCallUserId = receiverId;
    _activeCallUserName = receiverName;
    _activeCallUserProfileUrl = receiverProfileUrl;
    _isCallUIActive = true;

    // Navigate to outgoing call screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutgoingCallScreen(
          receiverId: receiverId,
          receiverName: receiverName,
          receiverProfileUrl: receiverProfileUrl,
          callService: _callService,
        ),
      ),
    ).then((_) {
      // Call screen was closed
      _isCallUIActive = false;
    });

    // Initiate the call
    final call = await _callService.initiateCall(receiverId);
    if (call == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initiate call')),
      );
    }
  }

  // Handle incoming call
  Future<void> _handleIncomingCall(Call call) async {
    // Get caller information
    final callerInfo = await _getCallerInfo(call.callerId);

    _activeCallUserId = call.callerId;
    _activeCallUserName = callerInfo['username'] ?? 'Unknown';
    _activeCallUserProfileUrl = callerInfo['profile_image_url'];
    _isCallUIActive = true;

    if (_context != null && _context!.mounted) {
      // Show incoming call screen
      Navigator.push(
        _context!,
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callerId: call.callerId,
            callerName: _activeCallUserName!,
            callerProfileUrl: _activeCallUserProfileUrl,
            callService: _callService,
          ),
        ),
      ).then((_) {
        // Call screen was closed
        _isCallUIActive = false;
      });
    }
  }

  // Navigate to active call screen
  void navigateToActiveCall(BuildContext context) {
    if (!_isCallUIActive && _callService.currentCall != null && _callService.currentCall!.isActive) {
      _isCallUIActive = true;

      // Check if call is answered or still ringing
      if (_callService.currentCall!.status == CallStatus.answered) {
        // Go directly to in-call screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InCallScreen(
              callService: _callService,
              otherUserName: _activeCallUserName ?? 'Unknown',
              otherUserProfileUrl: _activeCallUserProfileUrl,
            ),
          ),
        ).then((_) {
          _isCallUIActive = false;
        });
      } else {
        // Show appropriate screen based on who initiated the call
        final isOutgoing = _callService.currentCall!.callerId == _callService.currentUserId;

        if (isOutgoing) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OutgoingCallScreen(
                receiverId: _callService.currentCall!.receiverId,
                receiverName: _activeCallUserName ?? 'Unknown',
                receiverProfileUrl: _activeCallUserProfileUrl,
                callService: _callService,
              ),
            ),
          ).then((_) {
            _isCallUIActive = false;
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                callerId: _callService.currentCall!.callerId,
                callerName: _activeCallUserName ?? 'Unknown',
                callerProfileUrl: _activeCallUserProfileUrl,
                callService: _callService,
              ),
            ),
          ).then((_) {
            _isCallUIActive = false;
          });
        }
      }
    }
  }

  // Check if there's an active call with a specific user
  bool hasActiveCallWith(String userId) {
    if (_callService.currentCall == null) return false;
    final call = _callService.currentCall!;
    return call.isActive && (call.callerId == userId || call.receiverId == userId);
  }

  // Get active call status
  CallStatus? getActiveCallStatus() {
    return _callService.currentCall?.status;
  }

  // Get caller information
  Future<Map<String, dynamic>> _getCallerInfo(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('username, profile_image_url')
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      print('Error fetching caller info: $e');
      return {'username': 'Unknown User'};
    }
  }

  // Get device ID (simple implementation)
  Future<String> _getDeviceId() async {
    // For now, return a simple identifier
    // In production, you should use device_info_plus package
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Check if same device (simple implementation)
  Future<bool> _checkIfSameDevice(String receiverId, String deviceId) async {
    // For now, always return false
    // In production, implement proper device tracking
    return false;
  }

  // Show same device warning
  void _showSameDeviceWarning(BuildContext context, String receiverName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Same Device Call',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'You are trying to call $receiverName who may be logged in on this same device. This call cannot be completed.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show permission denied dialog
  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Microphone Permission Required',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'To make calls, please enable microphone permission in settings.',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Dispose resources
  void dispose() {
    _callService.dispose();
    _isInitialized = false;
  }
}