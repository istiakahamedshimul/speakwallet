import 'package:flutter/material.dart';

import 'database_service.dart';

class SummaryHeader extends StatelessWidget {
  final double totalSpent;
  final double netBalance;
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final Map<String, int> filterDays;

  const SummaryHeader({
    super.key,
    required this.totalSpent,
    required this.netBalance,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.filterDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_down_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Spending",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "${totalSpent.toStringAsFixed(0)} BDT",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE0E6EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedFilter,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.teal.shade800,
                    ),
                    style: TextStyle(
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    items: filterDays.keys.map((String key) {
                      return DropdownMenuItem<String>(
                        value: key,
                        child: Text(key),
                      );
                    }).toList(),
                    onChanged: (val) => onFilterChanged(val!),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: netBalance >= 0
                  ? Colors.teal.withOpacity(0.08)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  netBalance >= 0
                      ? Icons.account_balance_wallet_outlined
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: netBalance >= 0 ? Colors.teal.shade800 : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Net Balance",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  "${netBalance.toStringAsFixed(0)} BDT",
                  style: TextStyle(
                    color: netBalance >= 0
                        ? Colors.teal.shade800
                        : Colors.orange.shade800,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
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

  const TransactionDialog({
    super.key,
    this.isEdit = false,
    this.existingData,
    this.docId,
    this.dateKey,
    required this.dbService,
  });

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  late String type;
  late TextEditingController titleController;
  late TextEditingController amountController;

  @override
  void initState() {
    super.initState();
    type = widget.isEdit ? widget.existingData!['type'] : 'expense';
    titleController = TextEditingController(
        text: widget.isEdit ? widget.existingData!['title'] : "");
    amountController = TextEditingController(
        text: widget.isEdit ? widget.existingData!['amount'].toString() : "");
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
            if (!widget.isEdit)
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text("Expense")),
                  DropdownMenuItem(
                      value: 'loan_taken', child: Text("Loan Taken")),
                  DropdownMenuItem(
                      value: 'loan_given', child: Text("Loan Given")),
                ],
                onChanged: (val) => setState(() => type = val!),
              ),
            const SizedBox(height: 15),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount (BDT)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            if (titleController.text.isNotEmpty &&
                amountController.text.isNotEmpty) {
              double amount = double.tryParse(amountController.text) ?? 0;

              if (widget.isEdit) {
                widget.dbService.updateTransaction(
                  widget.docId!,
                  widget.dateKey!,
                  titleController.text,
                  amount,
                );
              } else {
                Map<String, dynamic> data;
                if (type == 'expense') {
                  data = {
                    'category': 'expense',
                    'items': [
                      {
                        'item_bn': titleController.text,
                        'item_en': '',
                        'amount': amount
                      }
                    ]
                  };
                } else {
                  data = {
                    'category': type,
                    'person': titleController.text,
                    'amount': amount
                  };
                }
                widget.dbService.saveTransaction(data);
              }
              Navigator.pop(context);
            }
          },
          child: Text(
            widget.isEdit ? "Update" : "Save",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
