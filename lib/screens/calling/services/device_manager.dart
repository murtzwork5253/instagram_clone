// screens/calling/services/device_manager.dart

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../call_manager.dart';

class DeviceManager {
  static final DeviceManager _instance = DeviceManager._internal();
  factory DeviceManager() => _instance;
  DeviceManager._internal();

  String? _deviceId;
  final _deviceInfo = DeviceInfoPlugin();

  // Get unique device ID
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? '';
      }
    } catch (e) {
      print('Error getting device ID: $e');
      _deviceId = 'unknown_device';
    }

    return _deviceId!;
  }

  // Register device for current user
  Future<void> registerDevice(String userId) async {
    final deviceId = await getDeviceId();
    final prefs = await SharedPreferences.getInstance();

    // Store active user sessions on this device
    List<String> activeUsers = prefs.getStringList('active_users') ?? [];
    if (!activeUsers.contains(userId)) {
      activeUsers.add(userId);
      await prefs.setStringList('active_users', activeUsers);
    }

    // Update device info in database
    try {
      await Supabase.instance.client.from('user_devices').upsert({
        'user_id': userId,
        'device_id': deviceId,
        'last_active': DateTime.now().toUtc().toIso8601String(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
      });
    } catch (e) {
      print('Error registering device: $e');
    }
  }

  // Check if two users are on the same device
  Future<bool> areUsersOnSameDevice(String userId1, String userId2) async {
    final currentDeviceId = await getDeviceId();

    try {
      // Check if both users have registered this device
      final response = await Supabase.instance.client
          .from('user_devices')
          .select('user_id, device_id')
          .eq('device_id', currentDeviceId)
          .inFilter('user_id', [userId1, userId2]);

      return response.length == 2;
    } catch (e) {
      print('Error checking same device: $e');
      return false;
    }
  }

  // Get all active users on this device
  Future<List<String>> getActiveUsersOnDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('active_users') ?? [];
  }

  // Remove user from device (on logout)
  Future<void> removeUserFromDevice(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> activeUsers = prefs.getStringList('active_users') ?? [];
    activeUsers.remove(userId);
    await prefs.setStringList('active_users', activeUsers);
  }
}

// Updated Call Manager with multi-account handling
extension MultiAccountCallManager on CallManager {

  Future<void> makeCallWithMultiAccountCheck({
    required BuildContext context,
    required String receiverId,
    required String receiverName,
    String? receiverProfileUrl,
  }) async {
    // Check if trying to call yourself
    if (receiverId == callService.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot call yourself')),
      );
      return;
    }

    // Check if both users are on same device
    final deviceManager = DeviceManager();
    final onSameDevice = await deviceManager.areUsersOnSameDevice(
        callService.currentUserId,
        receiverId
    );

    if (onSameDevice) {
      // Show warning dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Same Device Call',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'You are trying to call $receiverName who is logged in on this same device. This call cannot be completed.',
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
      return;
    }

    // Proceed with normal call flow
    await makeCall(
      context: context,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverProfileUrl: receiverProfileUrl,
    );
  }
}