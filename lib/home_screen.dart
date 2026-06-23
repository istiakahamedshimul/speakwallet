import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'advisor_screen.dart';
import 'database_service.dart';
import 'login_screen.dart';
import 'offline_processing_queue.dart';
import 'transaction_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance
      .refFromURL('https://speakwalletapp-default-rtdb.firebaseio.com/');
  final DatabaseService _dbService = DatabaseService();
  final OfflineProcessingQueue _offlineQueue = OfflineProcessingQueue();

  late final AudioRecorder _audioRecorder;
  late TabController _tabController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final ImagePicker _picker = ImagePicker();

  bool _isRecording = false;
  bool _isOnline = true;
  int _pendingQueueCount = 0;
  String? _syncedHistoryUid;

  String _selectedFilter = '1 Month';
  final Map<String, int> _filterDays = {
    '1 Week': 7,
    '2 Weeks': 14,
    '3 Weeks': 21,
    '1 Month': 30,
    '2 Months': 60
  };

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _tabController = TabController(length: 4, vsync: this);
    _startQueueMonitor();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _audioRecorder.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _startQueueMonitor() {
    _refreshConnectionAndQueue(showProcessedMessage: true);

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final hasNetworkSignal =
          results.any((result) => result != ConnectivityResult.none);

      if (!hasNetworkSignal) {
        _setOfflineStatus();
        return;
      }

      _refreshConnectionAndQueue(showProcessedMessage: true);
    });
  }

  Future<void> _setOfflineStatus() async {
    final pending = await _offlineQueue.pendingCount();
    if (!mounted) return;

    setState(() {
      _isOnline = false;
      _pendingQueueCount = pending;
    });
  }

  Future<void> _refreshConnectionAndQueue({
    bool showProcessedMessage = false,
  }) async {
    final online = await _offlineQueue.hasInternet();
    OfflineProcessingResult? result;

    if (online) {
      result = await _offlineQueue.processPending(_dbService);
    }

    final pending = await _offlineQueue.pendingCount();
    if (!mounted) return;

    setState(() {
      _isOnline = online;
      _pendingQueueCount = pending;
    });

    if (showProcessedMessage && result != null && result.processed > 0) {
      _showStatus(
        "${result.processed} offline file(s) processed successfully.",
        Colors.teal,
      );
    }
  }

  Future<void> _startRecording() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/voice_input.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: filePath,
      );
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopAndProcess() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path != null) {
      final online = await _offlineQueue.hasInternet();

      if (!online) {
        await _offlineQueue.enqueueAudio(path);
        await _refreshConnectionAndQueue();
        _showStatus(
          "You are offline. Voice will be processed when internet returns.",
          Colors.orange,
        );
        if (File(path).existsSync()) File(path).delete();
        return;
      }

      _showStatus("Processing audio...", Colors.grey.shade700);
      String result = await _dbService.uploadAndAnalyzeAudio(path);

      if (result == "Success") {
        _showStatus("Voice transaction saved!", Colors.teal);
      } else if (result == "Quota Full") {
        _showStatus("AI Quota Full! Wait 30s", Colors.orange);
      } else if (result == "Connection Failed") {
        await _offlineQueue.enqueueAudio(path);
        await _refreshConnectionAndQueue();
        _showStatus(
          "Connection lost. Voice will be processed when internet returns.",
          Colors.orange,
        );
      } else {
        _showStatus(result, Colors.redAccent);
      }

      if (File(path).existsSync()) File(path).delete();
    }
  }

  Future<void> _processImage(ImageSource source) async {
    final XFile? image =
        await _picker.pickImage(source: source, imageQuality: 80);

    if (image != null) {
      final online = await _offlineQueue.hasInternet();

      if (!online) {
        await _offlineQueue.enqueueReceipt(image.path);
        await _refreshConnectionAndQueue();
        _showStatus(
          "You are offline. Receipt will be processed when internet returns.",
          Colors.orange,
        );
        return;
      }

      _showStatus("Scanning receipt...", Colors.grey.shade700);
      String result = await _dbService.uploadAndAnalyzeReceipt(image.path);

      if (result == "Success") {
        _showStatus("Receipt items saved successfully!", Colors.teal);
      } else if (result == "Connection Failed") {
        await _offlineQueue.enqueueReceipt(image.path);
        await _refreshConnectionAndQueue();
        _showStatus(
          "Connection lost. Receipt will be processed when internet returns.",
          Colors.orange,
        );
      } else {
        _showStatus(result, Colors.redAccent);
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _processImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _processImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStatus(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;
    _enableOfflineHistoryCache(uid);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade900,
        title: const Text(
          "SpeakWallet",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner, color: Colors.white),
            onPressed: _showImageSourceDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => TransactionDialog(dbService: _dbService),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _auth.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.teal.shade200,
          tabs: const [
            Tab(text: "Expenses"),
            Tab(text: "Taken"),
            Tab(text: "Given"),
            Tab(text: "Advisor"),
          ],
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _rtdb.child('users/$uid/history').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allUserDocs = _readTransactions(snapshot);
          final totals = _calculateTotals(allUserDocs);

          return Column(
            children: [
              SummaryHeader(
                totalSpent: totals.expense,
                netBalance: totals.netBalance,
                selectedFilter: _selectedFilter,
                filterDays: _filterDays,
                onFilterChanged: (val) => setState(() => _selectedFilter = val),
              ),
              _buildConnectionBanner(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListView(
                      allUserDocs,
                      "expense",
                      Colors.redAccent,
                      Icons.shopping_bag_outlined,
                    ),
                    _buildListView(
                      allUserDocs,
                      "loan_taken",
                      Colors.orange,
                      Icons.south_west_rounded,
                    ),
                    _buildListView(
                      allUserDocs,
                      "loan_given",
                      Colors.blue,
                      Icons.north_east_rounded,
                    ),
                    AdvisorScreen(transactions: allUserDocs),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 25),
        child: GestureDetector(
          onTapDown: (_) => _startRecording(),
          onTapUp: (_) => _stopAndProcess(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _isRecording ? 85 : 70,
            width: _isRecording ? 85 : 70,
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red : Colors.teal.shade800,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _isRecording
                      ? Colors.red.withOpacity(0.5)
                      : Colors.black26,
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Icon(
              _isRecording ? Icons.settings_voice : Icons.mic,
              color: Colors.white,
              size: 35,
            ),
          ),
        ),
      ),
    );
  }

  void _enableOfflineHistoryCache(String uid) {
    if (_syncedHistoryUid == uid) return;

    _syncedHistoryUid = uid;
    unawaited(_rtdb.child('users/$uid/history').keepSynced(true));
  }

  List<Map<String, dynamic>> _readTransactions(
      AsyncSnapshot<DatabaseEvent> snapshot) {
    if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return [];

    int cutoffDays = _filterDays[_selectedFilter]!;
    DateTime cutoffDate = DateTime.now().subtract(Duration(days: cutoffDays));
    List<Map<String, dynamic>> allUserDocs = [];
    Map<dynamic, dynamic> historyData =
        snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

    historyData.forEach((dateKey, dateNode) {
      if (dateNode is Map && dateNode['transactions'] != null) {
        Map<dynamic, dynamic> transactions = dateNode['transactions'];
        transactions.forEach((txId, txData) {
          if (txData is Map) {
            var docData = Map<String, dynamic>.from(txData);
            docData['id'] = txId;

            if (docData['is_deleted'] != 1) {
              DateTime docDate;
              if (docData['timestamp'] != null) {
                docDate =
                    DateTime.fromMillisecondsSinceEpoch(docData['timestamp']);
              } else {
                docDate = DateTime.now();
              }

              if (docDate.isAfter(cutoffDate)) {
                allUserDocs.add(docData);
              }
            }
          }
        });
      }
    });

    allUserDocs
        .sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    return allUserDocs;
  }

  _TransactionTotals _calculateTotals(List<Map<String, dynamic>> allDocs) {
    double totalExpense = 0;
    double totalTaken = 0;
    double totalGiven = 0;

    for (var docData in allDocs) {
      double amt = docData.containsKey('amount')
          ? (docData['amount'] ?? 0).toDouble()
          : 0.0;
      String type = docData.containsKey('type') ? docData['type'] : '';

      if (type == 'expense') {
        totalExpense += amt;
      } else if (type == 'loan_taken') {
        totalTaken += amt;
      } else if (type == 'loan_given') {
        totalGiven += amt;
      }
    }

    return _TransactionTotals(
      expense: totalExpense,
      taken: totalTaken,
      given: totalGiven,
    );
  }

  Widget _buildListView(
    List<Map<String, dynamic>> allDocs,
    String targetType,
    Color color,
    IconData icon,
  ) {
    var filteredDocs = allDocs.where((data) {
      return data.containsKey('type') && data['type'] == targetType;
    }).toList();

    if (filteredDocs.isEmpty) {
      return _buildEmptyState(_emptyMessageForType(targetType));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        var data = filteredDocs[index];

        String displayTitle = data.containsKey('title')
            ? data['title']
            : (data.containsKey('name_bn') ? data['name_bn'] : 'Unknown');
        String displayDate =
            data.containsKey('date') ? data['date'] : 'Older Date';
        double displayAmount =
            data.containsKey('amount') ? (data['amount'] ?? 0).toDouble() : 0.0;
        String docId = data['id'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E9EE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2933),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              displayDate,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _labelForType(targetType),
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${displayAmount.toStringAsFixed(0)} BDT",
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, color: Colors.grey.shade500),
                      onSelected: (value) {
                        if (value == 'edit') {
                          showDialog(
                            context: context,
                            builder: (ctx) => TransactionDialog(
                              isEdit: true,
                              existingData: data,
                              docId: docId,
                              dateKey: displayDate,
                              dbService: _dbService,
                            ),
                          );
                        } else if (value == 'delete') {
                          _dbService.softDeleteTransaction(docId, displayDate);
                          _showStatus("Transaction deleted", Colors.grey);
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit, color: Colors.blue),
                            title: Text('Edit'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Delete'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    if (_isOnline && _pendingQueueCount == 0) return const SizedBox.shrink();

    final offline = !_isOnline;
    final color = offline ? Colors.orange : Colors.teal;
    final message = offline
        ? _pendingQueueCount > 0
            ? "Offline. $_pendingQueueCount file(s) waiting to process."
            : "Offline. You can view saved data on this device."
        : "$_pendingQueueCount file(s) waiting to process.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withOpacity(0.12),
      child: Row(
        children: [
          Icon(
            offline ? Icons.wifi_off_rounded : Icons.cloud_upload_outlined,
            color: color.shade800,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelForType(String type) {
    if (type == 'loan_taken') return 'Taken';
    if (type == 'loan_given') return 'Given';
    return 'Expense';
  }

  String _emptyMessageForType(String type) {
    if (type == 'loan_taken') return 'No money taken records yet';
    if (type == 'loan_given') return 'No money given records yet';
    return 'No expenses recorded yet';
  }
}

class _TransactionTotals {
  final double expense;
  final double taken;
  final double given;

  const _TransactionTotals({
    required this.expense,
    required this.taken,
    required this.given,
  });

  double get netBalance => taken - (expense + given);
}
