import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart'; // 🔴 ADDED IMAGE PICKER

import 'login_screen.dart';
import 'database_service.dart';
import 'transaction_widgets.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.refFromURL('https://speakwalletapp-default-rtdb.firebaseio.com/');
  final DatabaseService _dbService = DatabaseService();

  late final AudioRecorder _audioRecorder;
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker(); // 🔴 INITIALIZED PICKER

  bool _isRecording = false;

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // --- RECORDING LOGIC ---
  Future<void> _startRecording() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/voice_input.m4a';

      await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1),
          path: filePath
      );
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopAndProcess() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path != null) {
      _showStatus("Processing audio...", Colors.grey.shade700);
      String result = await _dbService.uploadAndAnalyzeAudio(path);

      if (result == "Success") {
        _showStatus("Voice transaction saved!", Colors.teal);
      } else if (result == "Quota Full") {
        _showStatus("AI Quota Full! Wait 30s", Colors.orange);
      } else {
        _showStatus(result, Colors.redAccent);
      }

      if (File(path).existsSync()) File(path).delete();
    }
  }

  // --- IMAGE / RECEIPT LOGIC 🔴 ---
  Future<void> _processImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);

    if (image != null) {
      _showStatus("Scanning receipt...", Colors.grey.shade700);
      String result = await _dbService.uploadAndAnalyzeReceipt(image.path);

      if (result == "Success") {
        _showStatus("Receipt items saved successfully!", Colors.teal);
      } else {
        _showStatus(result, Colors.redAccent);
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.teal),
              title: Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _processImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.blue),
              title: Text('Choose from Gallery'),
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
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating, duration: Duration(milliseconds: 2000)),
    );
  }

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade900,
        title: Text("SpeakWallet", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          // 🔴 ADDED RECEIPT SCANNER BUTTON
          IconButton(
              icon: Icon(Icons.document_scanner, color: Colors.white),
              onPressed: _showImageSourceDialog
          ),
          IconButton(
              icon: Icon(Icons.add, color: Colors.white),
              onPressed: () => showDialog(context: context, builder: (ctx) => TransactionDialog(dbService: _dbService))
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.teal.shade200,
          tabs: [Tab(text: "Expenses"), Tab(text: "Taken"), Tab(text: "Given")],
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _rtdb.child('users/$uid/history').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Column(
              children: [
                SummaryHeader(totalSpent: 0, netBalance: 0, selectedFilter: _selectedFilter, filterDays: _filterDays, onFilterChanged: (val) => setState(() => _selectedFilter = val)),
                Expanded(child: Center(child: Text("No records found", style: TextStyle(color: Colors.grey)))),
              ],
            );
          }

          int cutoffDays = _filterDays[_selectedFilter]!;
          DateTime cutoffDate = DateTime.now().subtract(Duration(days: cutoffDays));

          List<Map<String, dynamic>> allUserDocs = [];
          Map<dynamic, dynamic> historyData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

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
                      docDate = DateTime.fromMillisecondsSinceEpoch(docData['timestamp']);
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

          allUserDocs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

          double totalExpense = 0, totalTaken = 0, totalGiven = 0;

          for (var docData in allUserDocs) {
            double amt = docData.containsKey('amount') ? (docData['amount'] ?? 0).toDouble() : 0.0;
            String type = docData.containsKey('type') ? docData['type'] : '';

            if (type == 'expense') totalExpense += amt;
            else if (type == 'loan_taken') totalTaken += amt;
            else if (type == 'loan_given') totalGiven += amt;
          }

          double netBalance = totalTaken - (totalExpense + totalGiven);

          return Column(
            children: [
              SummaryHeader(
                totalSpent: totalExpense,
                netBalance: netBalance,
                selectedFilter: _selectedFilter,
                filterDays: _filterDays,
                onFilterChanged: (val) => setState(() => _selectedFilter = val),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListView(allUserDocs, "expense", Colors.redAccent, Icons.shopping_cart),
                    _buildListView(allUserDocs, "loan_taken", Colors.orange, Icons.arrow_circle_down),
                    _buildListView(allUserDocs, "loan_given", Colors.blue, Icons.arrow_circle_up),
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
            duration: Duration(milliseconds: 150),
            height: _isRecording ? 85 : 70,
            width: _isRecording ? 85 : 70,
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red : Colors.teal.shade800,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _isRecording ? Colors.red.withOpacity(0.5) : Colors.black26, blurRadius: 15, spreadRadius: 2)],
            ),
            child: Icon(_isRecording ? Icons.settings_voice : Icons.mic, color: Colors.white, size: 35),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> allDocs, String targetType, Color color, IconData icon) {
    var filteredDocs = allDocs.where((data) {
      return data.containsKey('type') && data['type'] == targetType;
    }).toList();

    if (filteredDocs.isEmpty) return Center(child: Text("No records found", style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 120),
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        var data = filteredDocs[index];

        String displayTitle = data.containsKey('title') ? data['title'] : (data.containsKey('name_bn') ? data['name_bn'] : 'Unknown');
        String displayDate = data.containsKey('date') ? data['date'] : 'Older Date';
        double displayAmount = data.containsKey('amount') ? (data['amount'] ?? 0).toDouble() : 0.0;
        String docId = data['id'];

        return Card(
          elevation: 0.5,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
            title: Text(displayTitle, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(displayDate),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("$displayAmount ৳", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'edit') {
                      showDialog(
                          context: context,
                          builder: (ctx) => TransactionDialog(
                              isEdit: true,
                              existingData: data,
                              docId: docId,
                              dateKey: displayDate,
                              dbService: _dbService
                          )
                      );
                    } else if (value == 'delete') {
                      _dbService.softDeleteTransaction(docId, displayDate);
                      _showStatus("Transaction deleted", Colors.grey);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: Colors.blue), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'), contentPadding: EdgeInsets.zero)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}