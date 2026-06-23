import 'package:flutter/material.dart';

class AdvisorScreen extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;

  const AdvisorScreen({super.key, required this.transactions});

  @override
  State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  bool _showWeek = false;
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
      children: [
        _buildHeader(stats),
        const SizedBox(height: 14),
        _buildPeriodSwitch(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: "Total Cost",
                amount: stats.expense,
                color: Colors.redAccent,
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                label: "Net Balance",
                amount: stats.netBalance,
                color: stats.netBalance >= 0 ? Colors.teal : Colors.orange,
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: "Taken",
                amount: stats.taken,
                color: Colors.orange,
                icon: Icons.south_west_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                label: "Given",
                amount: stats.given,
                color: Colors.blue,
                icon: Icons.north_east_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInsightCard(stats),
        const SizedBox(height: 16),
        _buildChatPanel(stats),
      ],
    );
  }

  Widget _buildHeader(_AdvisorStats stats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F5F5A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_alt_outlined,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Money Advisor",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stats.transactionCount == 0
                      ? "Add transactions to unlock smarter guidance."
                      : "Review spending and ask for guidance.",
                  style: TextStyle(
                    color: Colors.teal.shade50,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E9EE)),
      ),
      child: Row(
        children: [
          _buildPeriodButton("This Month", !_showWeek),
          _buildPeriodButton("This Week", _showWeek),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, bool selected) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _showWeek = label == "This Week"),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.teal.shade800 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E9EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              "${amount.toStringAsFixed(0)} BDT",
              style: TextStyle(
                color: color,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(_AdvisorStats stats) {
    final message = _buildInsightText(stats);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1D58C)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lightbulb_outline,
                color: Colors.amber.shade800, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Advisor Summary",
                  style: TextStyle(
                    color: Color(0xFF2D3748),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel(_AdvisorStats stats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E9EE)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline,
                    color: Colors.teal.shade800, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Ask Advisor",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2933),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "API later",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildMessageBubble(
                  isUser: false,
                  text:
                      "I can review your ${_showWeek ? 'weekly' : 'monthly'} spending and suggest better money habits once the AI API is connected.",
                ),
                const SizedBox(height: 10),
                _buildMessageBubble(
                  isUser: true,
                  text: stats.transactionCount == 0
                      ? "How should I start tracking?"
                      : "How can I reduce my total cost?",
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Ask about saving, budgeting, or spending",
                          hintStyle: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF6F8FA),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 46,
                      width: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _messageController.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.teal.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({required bool isUser, required String text}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? Colors.teal.shade800 : const Color(0xFFF0F4F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.grey.shade800,
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  _AdvisorStats _calculateStats() {
    final now = DateTime.now();
    final cutoff = _showWeek
        ? now.subtract(const Duration(days: 7))
        : DateTime(now.year, now.month, 1);

    double expense = 0;
    double taken = 0;
    double given = 0;
    int count = 0;

    for (final tx in widget.transactions) {
      final date = _readDate(tx);
      if (date.isBefore(cutoff)) continue;

      final amount =
          tx.containsKey('amount') ? (tx['amount'] ?? 0).toDouble() : 0.0;
      final type = tx.containsKey('type') ? tx['type'] : '';
      count++;

      if (type == 'expense') {
        expense += amount;
      } else if (type == 'loan_taken') {
        taken += amount;
      } else if (type == 'loan_given') {
        given += amount;
      }
    }

    return _AdvisorStats(
      expense: expense,
      taken: taken,
      given: given,
      transactionCount: count,
    );
  }

  DateTime _readDate(Map<String, dynamic> tx) {
    if (tx['timestamp'] != null) {
      return DateTime.fromMillisecondsSinceEpoch(tx['timestamp']);
    }

    if (tx['date'] is String) {
      return DateTime.tryParse(tx['date']) ?? DateTime.now();
    }

    return DateTime.now();
  }

  String _buildInsightText(_AdvisorStats stats) {
    if (stats.transactionCount == 0) {
      return "No spending data for this period yet. Add expenses, money taken, or money given to see a useful summary.";
    }

    final period = _showWeek ? "week" : "month";
    if (stats.expense == 0) {
      return "No costs recorded this $period. Your tracked balance is ${stats.netBalance.toStringAsFixed(0)} BDT.";
    }

    if (stats.netBalance < 0) {
      return "Your cost and money given are higher than money taken this $period. Review non-essential expenses first.";
    }

    return "You spent ${stats.expense.toStringAsFixed(0)} BDT this $period. Keep tracking daily to improve the next advice.";
  }
}

class _AdvisorStats {
  final double expense;
  final double taken;
  final double given;
  final int transactionCount;

  const _AdvisorStats({
    required this.expense,
    required this.taken,
    required this.given,
    required this.transactionCount,
  });

  double get netBalance => taken - (expense + given);
}
