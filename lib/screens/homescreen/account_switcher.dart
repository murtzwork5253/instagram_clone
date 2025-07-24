// Replace the existing account_switcher.dart content with this:

import 'package:Instagram/screens/homescreen/home_screen.dart';
import 'package:Instagram/screens/reels_screen/reel_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/account_manager.dart';
import '../../services/insta_data_provider.dart';
import '../auth/login_page.dart';
import '../../services/auth_service.dart';

class AccountSwitcherModal extends StatefulWidget {
  const AccountSwitcherModal({super.key});

  @override
  State<AccountSwitcherModal> createState() => _AccountSwitcherModalState();
}

class _AccountSwitcherModalState extends State<AccountSwitcherModal> {
  List<StoredAccount> accounts = [];
  String? currentAccountId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final loadedAccounts = await AccountManager.instance.getStoredAccounts();
      final currentId = await AccountManager.instance.getCurrentAccountId();

      if (mounted) {
        setState(() {
          accounts = loadedAccounts;
          currentAccountId = currentId;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Order accounts with current account first
  List<StoredAccount> get orderedAccounts {
    if (currentAccountId == null) return accounts;

    final currentAccount = accounts.where((account) => account.userId == currentAccountId).toList();
    final otherAccounts = accounts.where((account) => account.userId != currentAccountId).toList();

    return [...currentAccount, ...otherAccounts];
  }

  // Replace the _switchAccount method in account_switcher.dart with this:

  Future<void> _switchAccount(StoredAccount account) async {
    if (account.userId == currentAccountId) {
      Navigator.pop(context);
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      // Attempt to switch to the account
      final success = await AccountManager.instance.switchToAccount(account.userId, context);

      // Close loading dialog first
      if (mounted) {
        Navigator.pop(context); // Close loading
      }

      if (success) {
        // Close modal
        if (mounted) {
          Navigator.pop(context); // Close modal
        }

        // Full app refresh - Navigate to main page and remove all previous routes
        if (mounted) {
          // Import your main page/home page here
          final provider = Provider.of<InstaDataProvider>(context,listen: false);
          provider.reloadData();
          final reelprovi = Provider.of<ReelProvider>(context,listen: false);
          reelprovi.fetchReels();
          // Replace 'HomePage' with your actual main page widget
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeDashboard(), // Replace with your main page
            ),
                (route) => false, // Remove all previous routes
          );

          // Show success message after navigation
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched to ${account.username}'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          });
        }
      } else {
        // Account switch failed - account was removed
        if (mounted) {
          await _handleExpiredSession(account);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        await _handleSwitchError(e.toString(), account);
      }
    }
  }

  Future<void> _handleExpiredSession(StoredAccount account) async {
    // Show expired session dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Session Expired',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '${account.username}\'s session has expired. The account has been removed from this device.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close modal
              },
              child: const Text('OK', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close modal
                _navigateToReLogin(account);
              },
              child: const Text('Re-login', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
    }

    // Reload accounts list
    await _loadAccounts();
  }

  Future<void> _handleSwitchError(String error, StoredAccount account) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'An error occurred while switching accounts: $error',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close modal
            },
            child: const Text('OK', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close modal
              _navigateToReLogin(account);
            },
            child: const Text('Re-login', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _navigateToReLogin(StoredAccount account) {
    // Store the account info for pre-filling login form if needed
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
  }

  Future<void> _removeAccount(StoredAccount account) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Remove Account', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove ${account.username} from this device?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AccountManager.instance.removeAccount(account.userId);

      // If removed current account, redirect to login
      if (account.userId == currentAccountId) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
          );
        }
      } else {
        // Reload accounts list
        await _loadAccounts();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedAccounts = orderedAccounts;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Switch Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No accounts found',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
          // Accounts list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sortedAccounts.length + 1, // +1 for "Add Account" button
                itemBuilder: (context, index) {
                  if (index == sortedAccounts.length) {
                    // Add Account button
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                      title: const Text(
                        'Add Account',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        // Store current account before navigating
                        await AccountManager.instance.storeCurrentAccount();
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        }
                      },
                    );
                  }

                  final account = sortedAccounts[index];
                  final isCurrentAccount = account.userId == currentAccountId;

                  return Container(
                    // Add visual separation for current account
                    margin: isCurrentAccount
                        ? const EdgeInsets.only(bottom: 8)
                        : EdgeInsets.zero,
                    decoration: isCurrentAccount
                        ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[800]!,
                          width: 1,
                        ),
                      ),
                    )
                        : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: account.profileImageUrl != null && account.profileImageUrl!.isNotEmpty
                            ? NetworkImage(
                          account.profileImageUrl!.startsWith('http')
                              ? account.profileImageUrl!
                              : 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${account.profileImageUrl}',
                        )
                            : null,
                        child: account.profileImageUrl == null || account.profileImageUrl!.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        account.username,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isCurrentAccount ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        account.fullName ?? account.email,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      trailing: isCurrentAccount
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white70),
                        color: Colors.grey[800],
                        onSelected: (value) {
                          if (value == 'remove') {
                            _removeAccount(account);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove Account', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                      onTap: () => _switchAccount(account),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}