import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_service.dart';

class SummaryHeader extends StatelessWidget {
  final double totalSpent;
  final double netBalance;
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final Map<String, int> filterDays;

  SummaryHeader({
    required this.totalSpent,
    required this.netBalance,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.filterDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: Offset(0, 3))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Spent", style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
              Text("${totalSpent.toStringAsFixed(0)} ৳", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              SizedBox(height: 2),
              Text("Net Balance: ${netBalance.toStringAsFixed(0)} ৳", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedFilter,
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.teal.shade800),
                style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold, fontSize: 13),
                items: filterDays.keys.map((String key) {
                  return DropdownMenuItem<String>(value: key, child: Text(key));
                }).toList(),
                onChanged: (val) => onFilterChanged(val!),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class TransactionDialog extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic>? existingData;
  final String? docId;
  final String? dateKey;
  final DatabaseService dbService;

  TransactionDialog({this.isEdit = false, this.existingData, this.docId, this.dateKey, required this.dbService});

  @override
  _TransactionDialogState createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  late String type;
  late TextEditingController titleController;
  late TextEditingController amountController;

  @override
  void initState() {
    super.initState();
    type = widget.isEdit ? widget.existingData!['type'] : 'expense';
    titleController = TextEditingController(text: widget.isEdit ? widget.existingData!['title'] : "");
    amountController = TextEditingController(text: widget.isEdit ? widget.existingData!['amount'].toString() : "");
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.isEdit ? "Edit Transaction" : "Add Transaction"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isEdit) // Hide dropdown if editing to prevent type changes
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: [
                  DropdownMenuItem(value: 'expense', child: Text("Expense")),
                  DropdownMenuItem(value: 'loan_taken', child: Text("Loan Taken")),
                  DropdownMenuItem(value: 'loan_given', child: Text("Loan Given")),
                ],
                onChanged: (val) => setState(() => type = val!),
              ),
            SizedBox(height: 15),
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: "Description", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            SizedBox(height: 15),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Amount (৳)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            if (titleController.text.isNotEmpty && amountController.text.isNotEmpty) {
              double amount = double.tryParse(amountController.text) ?? 0;

              if (widget.isEdit) {
                widget.dbService.updateTransaction(widget.docId!, widget.dateKey!, titleController.text, amount);
              } else {
                Map<String, dynamic> data;
                if (type == 'expense') {
                  data = {'category': 'expense', 'items': [{'item_bn': titleController.text, 'item_en': '', 'amount': amount}]};
                } else {
                  data = {'category': type, 'person': titleController.text, 'amount': amount};
                }
                widget.dbService.saveTransaction(data);
              }
              Navigator.pop(context);
            }
          },
          child: Text(widget.isEdit ? "Update" : "Save", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}