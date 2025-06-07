// Replace the existing account_manager.dart content with this:

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class StoredAccount {
  final String userId;
  final String email;
  final String username;
  final String? profileImageUrl;
  final String? fullName;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  StoredAccount({
    required this.userId,
    required this.email,
    required this.username,
    this.profileImageUrl,
    this.fullName,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'username': username,
    'profileImageUrl': profileImageUrl,
    'fullName': fullName,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  factory StoredAccount.fromJson(Map<String, dynamic> json) => StoredAccount(
    userId: json['userId'],
    email: json['email'],
    username: json['username'],
    profileImageUrl: json['profileImageUrl'],
    fullName: json['fullName'],
    accessToken: json['accessToken'],
    refreshToken: json['refreshToken'],
    expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
  );
}

class AccountManager {
  static const String _accountsKey = 'stored_accounts';
  static const String _currentAccountKey = 'current_account_id';
  static AccountManager? _instance;

  AccountManager._();

  static AccountManager get instance {
    _instance ??= AccountManager._();
    return _instance!;
  }

  // Store current session as an account
  Future<void> storeCurrentAccount() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session?.user == null) return;

    try {
      // Get user profile data
      final profileData = await Supabase.instance.client
          .from('users')
          .select('username, profile_image_url, full_name')
          .eq('id', session!.user.id)
          .single();

      final account = StoredAccount(
        userId: session.user.id,
        email: session.user.email ?? '',
        username: profileData['username'] ?? '',
        profileImageUrl: profileData['profile_image_url'],
        fullName: profileData['full_name'],
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        expiresAt: session.expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000)
            : null,
      );

      await _storeAccount(account);
      await _setCurrentAccount(account.userId);
    } catch (e) {
      print('Error storing account: $e');
    }
  }

  // Get all stored accounts
  Future<List<StoredAccount>> getStoredAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString(_accountsKey);

    if (accountsJson == null) return [];

    try {
      final List<dynamic> accountsList = json.decode(accountsJson);
      return accountsList.map((json) => StoredAccount.fromJson(json)).toList();
    } catch (e) {
      print('Error loading accounts: $e');
      return [];
    }
  }

  // Switch to a specific account
  Future<bool> switchToAccount(String userId,BuildContext context) async {
    try {
      final accounts = await getStoredAccounts();
      final accountIndex = accounts.indexWhere((acc) => acc.userId == userId);

      if (accountIndex == -1) {
        throw Exception('Account not found');
      }

      var account = accounts[accountIndex];

      // Check if we have valid tokens
      if (account.refreshToken == null || account.refreshToken!.isEmpty) {
        print('No refresh token available for account');
        await removeAccount(userId);
        return false;
      }

      // Check if token needs refresh (with 5 minute buffer)
      final now = DateTime.now();
      final bufferTime = const Duration(minutes: 5);
      bool needsRefresh = account.expiresAt == null ||
          account.expiresAt!.isBefore(now.add(bufferTime));

      if (needsRefresh) {
        print('Token expired or expiring soon, attempting refresh...');
        final refreshed = await _refreshAccountToken(account);
        if (!refreshed) {
          print('Token refresh failed, removing account');
          await removeAccount(userId);
          return false;
        }

        // Get the updated account after refresh
        final updatedAccounts = await getStoredAccounts();
        final updatedAccountIndex = updatedAccounts.indexWhere((acc) => acc.userId == userId);
        if (updatedAccountIndex == -1) {
          print('Account not found after refresh');
          return false;
        }
        account = updatedAccounts[updatedAccountIndex];
      }

      // Set the session using refresh token
      print('Setting session for account: ${account.username}');
      final response = await Supabase.instance.client.auth.setSession(
        account.refreshToken!,
      );

      if (response.session == null) {
        print('Failed to set session');
        await removeAccount(userId);
        return false;
      }

      // Update stored account with new session data if available
      if (response.session!.accessToken != account.accessToken ||
          response.session!.refreshToken != account.refreshToken) {
        final updatedAccount = StoredAccount(
          userId: account.userId,
          email: account.email,
          username: account.username,
          profileImageUrl: account.profileImageUrl,
          fullName: account.fullName,
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken ?? account.refreshToken,
          expiresAt: response.session!.expiresAt != null
              ? DateTime.fromMillisecondsSinceEpoch(response.session!.expiresAt! * 1000)
              : account.expiresAt,
        );
        await _storeAccount(updatedAccount);
      }

      await _setCurrentAccount(userId);
      print('Successfully switched to account: ${account.username}');
      return true;
    } catch (e) {
      print('Error switching account: $e');
      await removeAccount(userId);
      return false;
    }
  }

  // Remove an account
  Future<void> removeAccount(String userId) async {
    final accounts = await getStoredAccounts();
    accounts.removeWhere((acc) => acc.userId == userId);
    await _saveAccounts(accounts);

    // If we removed the current account, clear current account
    final currentId = await getCurrentAccountId();
    if (currentId == userId) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentAccountKey);
    }
  }

  // Get current account ID
  Future<String?> getCurrentAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentAccountKey);
  }

  // Sign out from current account
  Future<void> signOutCurrent() async {
    await Supabase.instance.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentAccountKey);
  }

  // Sign out from all accounts
  Future<void> signOutAll() async {
    await Supabase.instance.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountsKey);
    await prefs.remove(_currentAccountKey);
  }

  // Private helper methods
  Future<void> _storeAccount(StoredAccount account) async {
    final accounts = await getStoredAccounts();

    // Remove existing account with same userId if exists
    accounts.removeWhere((acc) => acc.userId == account.userId);

    // Add the new/updated account
    accounts.add(account);

    await _saveAccounts(accounts);
  }

  Future<void> _saveAccounts(List<StoredAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = json.encode(accounts.map((acc) => acc.toJson()).toList());
    await prefs.setString(_accountsKey, accountsJson);
  }

  Future<void> _setCurrentAccount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentAccountKey, userId);
  }

  // Refresh account token
  Future<bool> _refreshAccountToken(StoredAccount account) async {
    try {
      if (account.refreshToken == null || account.refreshToken!.isEmpty) {
        print('No refresh token available');
        return false;
      }

      print('Attempting to refresh token for: ${account.username}');

      // Use the refresh token to get a new session
      final response = await Supabase.instance.client.auth.refreshSession(
        account.refreshToken!,
      );

      if (response.session != null && response.session!.accessToken.isNotEmpty) {
        print('Token refresh successful');

        // Update stored account with new tokens
        final updatedAccount = StoredAccount(
          userId: account.userId,
          email: account.email,
          username: account.username,
          profileImageUrl: account.profileImageUrl,
          fullName: account.fullName,
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken ?? account.refreshToken,
          expiresAt: response.session!.expiresAt != null
              ? DateTime.fromMillisecondsSinceEpoch(response.session!.expiresAt! * 1000)
              : null,
        );

        await _storeAccount(updatedAccount);
        return true;
      } else {
        print('Token refresh returned null or empty session');
        return false;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }
}