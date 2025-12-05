import 'package:flutter/material.dart';
import '../services/user_service.dart';
// Import SmsHomePage - using a deferred import pattern to avoid circular dependency
import '../main.dart' show SmsHomePage;

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with WidgetsBindingObserver {
  bool _isChecking = true;
  bool _hasUserId = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUserId();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check user_id when app resumes
      _checkUserId();
    }
  }

  Future<void> _checkUserId() async {
    try {
      final hasUserId = await UserService.hasUserId();
      setState(() {
        _hasUserId = hasUserId;
        _isChecking = false;
      });
    } catch (e) {
      print('Error checking user ID: $e');
      setState(() {
        _hasUserId = false;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade400, Colors.purple.shade400],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    if (!_hasUserId) {
      // Show user ID setup screen
      return const UserIdSetupPage();
    }

    // User ID exists, show main app
    return const SmsHomePage();
  }
}

class UserIdSetupPage extends StatefulWidget {
  const UserIdSetupPage({super.key});

  @override
  State<UserIdSetupPage> createState() => _UserIdSetupPageState();
}

class _UserIdSetupPageState extends State<UserIdSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _saveUserId() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _userIdController.text.trim();
      if (userId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a user ID')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final success = await UserService.saveUserId(userId);
      if (mounted) {
        if (success) {
          // Reload the app to show main screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SplashPage()),
          );
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save user ID')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving user ID: $e')),
        );
      }
    }
  }

  String? _validateUserId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a user ID';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade400, Colors.purple.shade400],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  // Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Title
                  const Text(
                    'User ID Required',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Description
                  Text(
                    'Please enter your User ID to continue using the app.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  // User ID Input Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _userIdController,
                            decoration: InputDecoration(
                              labelText: 'User ID',
                              hintText: 'Enter your user ID',
                              prefixIcon: const Icon(Icons.badge),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: _validateUserId,
                          enabled: !_isLoading,
                            autofocus: true,
                          ),
                        const SizedBox(height: 24),
                          // Save button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveUserId,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.blue.shade400,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Info card
                  Card(
                    elevation: 2,
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your User ID is required to identify your account when sending SMS alerts.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

