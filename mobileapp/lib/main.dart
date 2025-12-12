import 'dart:ui';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:android_sms_reader/android_sms_reader.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'services/allowed_numbers_service.dart';
import 'services/user_service.dart';
import 'services/sms_storage_service.dart';
import 'models/sms_message.dart';
import 'widgets/sms_card.dart';
import 'widgets/empty_state.dart';
import 'pages/allowed_numbers_page.dart';
import 'pages/settings_page.dart';
import 'pages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request SMS permission automatically
  await _requestSmsPermission();

  // Request notification permission (required for Android 13+)
  await _requestNotificationPermission();

  // Create notification channel FIRST - must exist before service starts
  try {
    await _createNotificationChannel();
  } catch (e) {
    print('Failed to create notification channel: $e');
  }

  // Initialize user ID on first app load
  Future.microtask(() async {
    try {
      await UserService.initializeUserId();
    } catch (e) {
      print('Failed to initialize user ID: $e');
    }
  });

  // Start app
  runApp(const SmsApp());

  // Initialize service after app starts (non-blocking)
  // Channel already exists, so service can start safely
  Future.microtask(() async {
    try {
      // Small delay to ensure app is fully started
      await Future.delayed(const Duration(milliseconds: 300));
      await initializeService();
    } catch (e) {
      print('Failed to initialize background service: $e');
      // App continues to run even if service fails
    }
  });
}

// Request SMS permission automatically
Future<void> _requestSmsPermission() async {
  try {
    // Check current permission status
    final smsStatus = await Permission.sms.status;

    if (smsStatus.isDenied) {
      // Request permission
      final result = await Permission.sms.request();
      if (result.isGranted) {
        print('SMS permission granted automatically');
      } else if (result.isPermanentlyDenied) {
        print(
          'SMS permission permanently denied - user needs to enable in settings',
        );
      } else {
        print('SMS permission denied by user');
      }
    } else if (smsStatus.isGranted) {
      print('SMS permission already granted');
    } else if (smsStatus.isPermanentlyDenied) {
      print('SMS permission permanently denied');
    }
  } catch (e) {
    print('Error requesting SMS permission: $e');
    // Fallback to android_sms_reader method
    try {
      await AndroidSMSReader.requestPermissions();
    } catch (e2) {
      print('Fallback permission request also failed: $e2');
    }
  }
}

// Request notification permission (required for Android 13+ / API 33+)
Future<void> _requestNotificationPermission() async {
  try {
    // Check current permission status
    final notificationStatus = await Permission.notification.status;

    if (notificationStatus.isDenied) {
      // Request permission
      final result = await Permission.notification.request();
      if (result.isGranted) {
        print('Notification permission granted automatically');
      } else if (result.isPermanentlyDenied) {
        print(
          'Notification permission permanently denied - user needs to enable in settings',
        );
      } else {
        print('Notification permission denied by user');
      }
    } else if (notificationStatus.isGranted) {
      print('Notification permission already granted');
    } else if (notificationStatus.isPermanentlyDenied) {
      print('Notification permission permanently denied');
    } else if (notificationStatus.isRestricted) {
      print('Notification permission is restricted');
    }
  } catch (e) {
    print('Error requesting notification permission: $e');
    // On Android versions below 13, notification permission is granted by default
    // so this error can be safely ignored
  }
}

Future<void> _createNotificationChannel() async {
  try {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Initialize notification settings - use default launcher icon
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Create notification channel - MUST exist before service starts
    // Using high importance for persistent foreground service
    const channel = AndroidNotificationChannel(
      'sms_reader_channel',
      'SMS Reader Service',
      description: 'Keeps SMS reader running in background',
      importance: Importance.high, // Changed to high for persistent service
      enableVibration: false,
      playSound: false,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  } catch (e) {
    print('Error creating notification channel: $e');
    rethrow;
  }
}

@pragma('vm:entry-point')
Future<void> initializeService() async {
  // Ensure notification channel exists before starting service
  try {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'sms_reader_channel',
      'SMS Reader Service',
      description: 'Keeps SMS reader running in background',
      importance: Importance.low,
      enableVibration: false,
      playSound: false,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  } catch (e) {
    print('Error ensuring notification channel exists: $e');
  }

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true, // Auto-start service
      isForegroundMode: true, // Enable foreground mode for persistent service
      autoStartOnBoot: true, // Auto-start on device boot
      notificationChannelId: 'sms_reader_channel',
      initialNotificationTitle: 'SMS Reader',
      initialNotificationContent: 'Monitoring SMS messages',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration:
        IosConfiguration(), // iOS not supported for this, but required
  );

  // Start service manually after configuration
  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure Flutter plugins work inside background isolate
  DartPluginRegistrant.ensureInitialized();

  // Store subscription for SMS listener so we can cancel it when stopping
  StreamSubscription? smsSubscription;
  Timer? periodicTimer;

  // Set up stop handler FIRST - before any other operations
  // This ensures the stop command can be received even if other operations fail
  service.on('stop').listen((event) {
    print('Stop command received in background service - stopping now...');
    try {
      // Cancel any active subscriptions
      smsSubscription?.cancel();
      periodicTimer?.cancel();
      print('Cancelled active subscriptions');

      // Stop the service
      service.stopSelf();
      print('Service stopSelf() called successfully');
    } catch (e) {
      print('Error stopping service: $e');
    }
  });

  if (service is AndroidServiceInstance) {
    // When isForegroundMode is true in configuration, the service automatically
    // creates the notification. We just need to ensure it stays in foreground.
    // Don't manually set notification here as it's already handled by the service.

    // Handle commands from UI
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      // Don't allow switching to background - keep it foreground
      service.setAsForegroundService();
    });
  }

  // Request SMS permission
  final granted = await AndroidSMSReader.requestPermissions();
  if (!granted) {
    print('SMS permission denied in background service');
    return;
  }

  // 📩 Real-time SMS listener
  smsSubscription = AndroidSMSReader.observeIncomingMessages().listen((
    AndroidSMSMessage sms,
  ) async {
    print('New SMS in background: From ${sms.address}, Body: ${sms.body}');

    // Check if the number is allowed
    final isAllowed = await AllowedNumbersService.isNumberAllowed(sms.address);

    if (!isAllowed) {
      print(
        'SMS from ${sms.address} is not in allowed list - skipping API call',
      );
      return;
    }

    print('SMS from ${sms.address} is allowed - calling API');

    // ---- API CALL HERE ----
    try {
      // Get user ID from storage
      final userId = await UserService.getUserId();

      if (userId == null || userId.isEmpty) {
        print(
          'User ID not set - skipping API call. Please set user ID in app settings.',
        );
        return;
      }

      final url = Uri.parse(
        "https://us-central1-payconfirmapp.cloudfunctions.net/swiftAlert",
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'smsText': ' ${sms.body}'}),
      );
      print("API Response: ${response.statusCode} - ${response.body}");

      // Parse API response
      ApiResponse? apiResponse;
      if (response.statusCode == 200) {
        try {
          final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
          apiResponse = ApiResponse.fromApiJson(responseJson);
          print("Parsed API response - isBankMessage: ${apiResponse.isBankMessage}, isSuccess: ${apiResponse.isSuccess}");
        } catch (e) {
          print("Error parsing API response: $e");
        }
      }

      // Save message with API response
      // Generate unique ID using address, date, and body hash
      final messageId = '${sms.address}_${sms.date}_${sms.body.hashCode}';
      final message = SmsMessage(
        id: messageId,
        address: sms.address,
        body: sms.body,
        date: sms.date,
        apiResponse: apiResponse,
      );
      
      // Only save if it's a relevant bank message
      if (message.isRelevantBankMessage) {
        await SmsStorageService.saveMessage(message);
        print("Saved relevant bank message: ${message.id}");
      } else {
        print("Message is not a relevant bank message - not saving");
      }
    } catch (e) {
      print("API call failed: $e");
    }
  });

  // 🔄 Keep-alive mechanism - periodic check every 30s
  periodicTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      try {
        // Ensure service stays in foreground mode
        if (!(await service.isForegroundService())) {
          print('Service not in foreground, switching to foreground mode...');
          service.setAsForegroundService();
        }

        // Update notification to show service is alive (only if in foreground)
        try {
          service.setForegroundNotificationInfo(
            title: 'SMS Reader Active',
            content:
                'Monitoring SMS messages - ${DateTime.now().toString().substring(11, 19)}',
          );
        } catch (e) {
          print('Error updating notification: $e');
        }

        // Periodic SMS check
        final msgs = await AndroidSMSReader.fetchMessages(
          type: AndroidSMSType.inbox,
          start: 0,
          count: 5,
        );
        print('Periodic fetch: ${msgs.length} messages');
      } catch (e) {
        print('Error in periodic keep-alive: $e');
        // Try to restart foreground service if error occurs
        try {
          service.setAsForegroundService();
        } catch (e2) {
          print('Error restarting foreground service: $e2');
        }
      }
    }
  });
}

class SmsApp extends StatelessWidget {
  const SmsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Android SMS Reader Demo',
      home: const SplashPage(),
    );
  }
}

class SmsHomePage extends StatefulWidget {
  const SmsHomePage({super.key});
  @override
  State<SmsHomePage> createState() => _SmsHomePageState();
}

class _SmsHomePageState extends State<SmsHomePage> {
  List<SmsMessage> _filteredMessages = [];
  bool _loading = true;
  String? _error;
  bool _isRunning = false;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    // Defer heavy operations until after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkServiceStatus();
      _loadMessages(); // Load UI messages separately
    });
  }

  Future<void> _checkServiceStatus() async {
    if (!mounted) return;

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (!mounted) return;

    setState(() => _isRunning = isRunning);
  }

  Future<void> _toggleService() async {
    if (!mounted || _isToggling) return;

    setState(() => _isToggling = true);

    final service = FlutterBackgroundService();
    try {
      if (_isRunning) {
        // Stop service by invoking stop command
        print('Stopping background service...');
        service.invoke('stop');
      } else {
        print('Starting background service...');
        await service.startService();
      }

      // Wait longer for service to actually stop/start
      // Service stop might take a moment to process
      await Future.delayed(const Duration(milliseconds: 800));

      // Check status multiple times to ensure it updated
      for (int i = 0; i < 3; i++) {
        await _checkServiceStatus();
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      print('Error toggling service: $e');
      // Still check status even if there was an error
      await _checkServiceStatus();
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Check permission status first
      final smsStatus = await Permission.sms.status;

      bool granted = false;

      if (smsStatus.isGranted) {
        granted = true;
      } else if (smsStatus.isDenied) {
        // Request permission if denied
        final result = await Permission.sms.request();
        granted = result.isGranted;
      } else if (smsStatus.isPermanentlyDenied) {
        // Permission permanently denied - need to open settings
        if (mounted) {
          setState(() {
            _error = 'permanently_denied';
            _loading = false;
          });
        }
        return;
      }

      // Fallback to android_sms_reader if permission_handler didn't work
      if (!granted) {
        granted = await AndroidSMSReader.requestPermissions();
      }

      if (!mounted) return;

      if (!granted) {
        setState(() {
          _error =
              'SMS permission denied. Please grant permission to view messages.';
          _loading = false;
        });
        return;
      }

      // Load only relevant bank messages (isBankMessage: true) from storage
      final relevantMessages = await SmsStorageService.getRelevantBankMessages();

      if (!mounted) return;

      setState(() {
        _filteredMessages = relevantMessages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load messages: $e';
        _loading = false;
      });
    }
  }

  Future<void> _navigateToAllowedNumbers() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AllowedNumbersPage()));
    // Reload messages after returning from allowed numbers page
    _loadMessages();
  }

  Future<void> _navigateToSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SettingsPage()));
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blue),
              title: const Text('Allowed Numbers'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAllowedNumbers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.blue),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                _navigateToSettings();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'SMS Reader',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Service Status Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isRunning ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isRunning ? 'Running' : 'Stopped',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: _showSettingsMenu,
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ),
              // Service Control Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Background Service',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isToggling
                                    ? (_isRunning
                                        ? 'Stopping...'
                                        : 'Starting...')
                                    : (_isRunning
                                        ? 'Monitoring SMS messages'
                                        : 'Service is stopped'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _isToggling
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Switch(
                                value: _isRunning,
                                onChanged: _isToggling
                                    ? null
                                    : (_) => _toggleService(),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Messages List
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _error == 'permanently_denied'
                                          ? Icons.settings
                                          : Icons.error_outline,
                                      size: 64,
                                      color: Colors.red[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _error == 'permanently_denied'
                                          ? 'SMS Permission Required'
                                          : _error!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (_error == 'permanently_denied') ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Please enable SMS permission in app settings',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                    if (_error == 'permanently_denied')
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await openAppSettings();
                                          // Reload after returning from settings
                                          await Future.delayed(
                                            const Duration(seconds: 1),
                                          );
                                          _loadMessages();
                                        },
                                        icon: const Icon(Icons.settings),
                                        label: const Text('Open Settings'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      )
                                    else
                                      ElevatedButton(
                                        onPressed: _loadMessages,
                                        child: const Text('Retry'),
                                      ),
                                  ],
                                ),
                              ),
                            )
                          : _filteredMessages.isEmpty
                              ? EmptyState(
                                  icon: Icons.message,
                                  title: 'No filtered messages',
                                  message:
                                      'Add allowed numbers to see SMS messages from those contacts',
                                  action: ElevatedButton.icon(
                                    onPressed: _navigateToAllowedNumbers,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Manage Numbers'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadMessages,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(
                                        top: 8, bottom: 16),
                                    itemCount: _filteredMessages.length,
                                    itemBuilder: (context, i) {
                                      final m = _filteredMessages[i];
                                      return SmsCard(message: m);
                                    },
                                  ),
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadMessages,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
