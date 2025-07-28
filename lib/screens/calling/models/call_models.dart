// screens/calling/models/call_models.dart

import 'package:flutter/material.dart';

enum CallStatus {
  initiated,
  ringing,
  answered,
  ended,
  missed,
  declined,
  busy
}

enum SignalType {
  offer,
  answer,
  iceCandidate,
  endCall,
  rejectCall
}

class Call {
  final String id;
  final String callerId;
  final String receiverId;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String? endedBy;

  Call({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.status,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
    this.durationSeconds,
    this.endedBy,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'],
      callerId: json['caller_id'],
      receiverId: json['receiver_id'],
      status: CallStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => CallStatus.ended,
      ),
      startedAt: DateTime.parse(json['started_at']).toLocal(),
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at']).toLocal()
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at']).toLocal()
          : null,
      durationSeconds: json['duration_seconds'],
      endedBy: json['ended_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caller_id': callerId,
      'receiver_id': receiverId,
      'status': status.name,
      'started_at': startedAt.toUtc().toIso8601String(),
      'answered_at': answeredAt?.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'duration_seconds': durationSeconds,
      'ended_by': endedBy,
    };
  }

  bool get isActive => status == CallStatus.initiated ||
      status == CallStatus.ringing ||
      status == CallStatus.answered;
}

class CallSignal {
  final String id;
  final String callId;
  final String fromUserId;
  final String toUserId;
  final SignalType signalType;
  final Map<String, dynamic> signalData;
  final DateTime createdAt;

  CallSignal({
    required this.id,
    required this.callId,
    required this.fromUserId,
    required this.toUserId,
    required this.signalType,
    required this.signalData,
    required this.createdAt,
  });

  factory CallSignal.fromJson(Map<String, dynamic> json) {
    return CallSignal(
      id: json['id'],
      callId: json['call_id'],
      fromUserId: json['from_user_id'],
      toUserId: json['to_user_id'],
      signalType: SignalType.values.firstWhere(
            (e) => e.name == _mapSignalType(json['signal_type']),
      ),
      signalData: json['signal_data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }

  static String _mapSignalType(String dbType) {
    switch (dbType) {
      case 'ice_candidate':
        return 'iceCandidate';
      case 'end_call':
        return 'endCall';
      case 'reject_call':
        return 'rejectCall';
      default:
        return dbType;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'signal_type': _mapSignalTypeToDb(signalType),
      'signal_data': signalData,
    };
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
}

class CallerInfo {
  final String userId;
  final String username;
  final String? profileImageUrl;

  CallerInfo({
    required this.userId,
    required this.username,
    this.profileImageUrl,
  });
}