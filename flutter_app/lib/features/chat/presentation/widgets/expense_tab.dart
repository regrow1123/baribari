import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/kakao_theme.dart';
import '../../domain/models.dart';
import '../providers/chat_provider.dart';

class ExpenseTab extends ConsumerWidget {
  final String tripId;

  const ExpenseTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider(tripId));
    final messages = ref.watch(messagesProvider(tripId));

    // Get itinerary days for linking
    final itineraryMsg = messages.lastWhere(
      (m) => m.messageType == MessageType.itineraryCard && m.metadata != null,
      orElse: () => Message(id: '', tripId: tripId, role: '', content: '', createdAt: DateTime.now()),
    );
    final days = (itineraryMsg.metadata?['days'] as List?) ?? [];

    final totalKrw = expenses.fold<int>(0, (sum, e) => sum + ((e['amount'] as num?)?.toInt() ?? 0));
    final byCategory = <String, int>{};
    for (final e in expenses) {
      final cat = e['category'] as String? ?? '기타';
      byCategory[cat] = (byCategory[cat] ?? 0) + ((e['amount'] as num?)?.toInt() ?? 0);
    }

    // Group by day
    final byDay = <int, List<Map<String, dynamic>>>{};
    final unlinked = <Map<String, dynamic>>[];
    for (final e in expenses) {
      final day = e['day_number'] as int?;
      if (day != null) {
        byDay.putIfAbsent(day, () => []).add(e);
      } else {
        unlinked.add(e);
      }
    }

    return Container(
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                const Text('총 경비', style: TextStyle(fontSize: 14, color: KakaoTheme.secondary)),
                const SizedBox(height: 4),
                Text(
                  _formatKrw(totalKrw),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: KakaoTheme.primary),
                ),
                if (byCategory.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: byCategory.entries.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _catColor(e.key).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_catIcon(e.key)} ${e.key}  ${_formatKrw(e.value)}',
                        style: TextStyle(fontSize: 12, color: _catColor(e.key), fontWeight: FontWeight.w600),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Add button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _showAddExpenseSheet(context, ref, days),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF48BB78).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF48BB78)),
                    SizedBox(width: 8),
                    Text('경비 추가', style: TextStyle(fontSize: 14, color: Color(0xFF48BB78), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Expense list grouped by day
          Expanded(
            child: expenses.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('💰', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 16),
                        Text('아직 경비 기록이 없어요', style: TextStyle(fontSize: 16, color: KakaoTheme.secondary)),
                        Text('여행 경비를 기록해보세요!', style: TextStyle(fontSize: 14, color: KakaoTheme.secondary)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _buildDayGroups(byDay, days, ref),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDayGroups(Map<int, List<Map<String, dynamic>>> byDay, List days, WidgetRef ref) {
    final widgets = <Widget>[];
    final sortedDays = byDay.keys.toList()..sort();

    for (final dayNum in sortedDays) {
      final dayExpenses = byDay[dayNum]!;
      final dayTotal = dayExpenses.fold<int>(0, (s, e) => s + ((e['amount'] as num?)?.toInt() ?? 0));

      // Get day info from itinerary
      String? dayTitle;
      if (dayNum > 0 && dayNum <= days.length) {
        final d = days[dayNum - 1] as Map<String, dynamic>;
        dayTitle = d['date'] as String?;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90D9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Day $dayNum', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              if (dayTitle != null) ...[
                const SizedBox(width: 8),
                Text(dayTitle, style: const TextStyle(fontSize: 12, color: KakaoTheme.secondary)),
              ],
              const Spacer(),
              Text(_formatKrw(dayTotal), style: const TextStyle(fontSize: 13, color: Color(0xFF4A90D9), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

      for (final e in dayExpenses) {
        widgets.add(_ExpenseTile(
          expense: e,
          onDelete: () => ref.read(expensesProvider(tripId).notifier).remove(e['id']),
        ));
      }
    }

    // Unlinked expenses
    final allExpenses = ref.read(expensesProvider(tripId));
    final unlinked = allExpenses.where((e) => e['day_number'] == null).toList();
    if (unlinked.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.only(top: 12, bottom: 6),
          child: Text('미분류', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: KakaoTheme.secondary)),
        ),
      );
      for (final e in unlinked) {
        widgets.add(_ExpenseTile(
          expense: e,
          onDelete: () => ref.read(expensesProvider(tripId).notifier).remove(e['id']),
        ));
      }
    }

    return widgets;
  }

  void _showAddExpenseSheet(BuildContext context, WidgetRef ref, List days) {
    final amountCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    String selectedCategory = '식비';
    int? selectedDay;
    String? selectedItem;

    // Build itinerary items list
    final dayItems = <Map<String, dynamic>>[];
    for (var i = 0; i < days.length; i++) {
      final d = days[i] as Map<String, dynamic>;
      final dayNum = d['day'] ?? i + 1;
      dayItems.add({'dayNum': dayNum, 'label': 'Day $dayNum', 'items': d['items'] ?? []});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: Text('💰 경비 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 20),
                    // Amount
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '금액 (원)',
                        prefixText: '₩ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Category
                    const Text('카테고리', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: ['식비', '교통', '숙박', '쇼핑', '관광', '기타'].map((cat) {
                        final isSelected = selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => setState(() => selectedCategory = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? _catColor(cat) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _catColor(cat)),
                            ),
                            child: Text(
                              '${_catIcon(cat)} $cat',
                              style: TextStyle(color: isSelected ? Colors.white : _catColor(cat), fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Day selection (if itinerary exists)
                    if (dayItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('일정 연결', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() { selectedDay = null; selectedItem = null; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedDay == null ? const Color(0xFF4A90D9) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF4A90D9)),
                              ),
                              child: Text('미분류', style: TextStyle(
                                color: selectedDay == null ? Colors.white : const Color(0xFF4A90D9), fontWeight: FontWeight.w600)),
                            ),
                          ),
                          ...dayItems.map((d) {
                            final dayNum = d['dayNum'] as int;
                            final isSelected = selectedDay == dayNum;
                            return GestureDetector(
                              onTap: () => setState(() { selectedDay = dayNum; selectedItem = null; }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF4A90D9) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF4A90D9)),
                                ),
                                child: Text('Day $dayNum', style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF4A90D9), fontWeight: FontWeight.w600)),
                              ),
                            );
                          }),
                        ],
                      ),
                      // Item selection within selected day
                      if (selectedDay != null) ...[
                        const SizedBox(height: 8),
                        ...() {
                          final dayData = dayItems.firstWhere((d) => d['dayNum'] == selectedDay, orElse: () => {});
                          final items = (dayData['items'] as List?) ?? [];
                          return items.map<Widget>((item) {
                            final title = (item as Map)['title'] as String? ?? '';
                            final isItemSelected = selectedItem == title;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: GestureDetector(
                                onTap: () => setState(() => selectedItem = isItemSelected ? null : title),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isItemSelected ? const Color(0xFF4A90D9).withValues(alpha: 0.1) : const Color(0xFFF5F7FA),
                                    borderRadius: BorderRadius.circular(8),
                                    border: isItemSelected ? Border.all(color: const Color(0xFF4A90D9)) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(isItemSelected ? Icons.check_circle : Icons.circle_outlined,
                                        size: 18, color: isItemSelected ? const Color(0xFF4A90D9) : KakaoTheme.secondary),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList();
                        }(),
                      ],
                    ],
                    const SizedBox(height: 16),
                    // Memo
                    TextField(
                      controller: memoCtrl,
                      decoration: InputDecoration(
                        labelText: '메모 (선택)',
                        hintText: '예: 이치란 라멘',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF48BB78),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final amount = int.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                          if (amount == null || amount <= 0) return;
                          ref.read(expensesProvider(tripId).notifier).add(
                            amount: amount,
                            category: selectedCategory,
                            memo: memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim(),
                            dayNumber: selectedDay,
                            linkedItem: selectedItem,
                          );
                          Navigator.pop(ctx);
                        },
                        child: const Text('추가', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Map<String, dynamic> expense;
  final VoidCallback onDelete;

  const _ExpenseTile({required this.expense, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final amount = (expense['amount'] as num?)?.toInt() ?? 0;
    final category = expense['category'] as String? ?? '기타';
    final memo = expense['memo'] as String?;
    final linkedItem = expense['linked_item'] as String?;
    final spentAt = DateTime.tryParse(expense['spent_at'] ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _catColor(category).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(_catIcon(category), style: const TextStyle(fontSize: 22))),
        ),
        title: Text(
          _formatKrw(amount),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${memo ?? category}  •  ${DateFormat('M/d HH:mm').format(spentAt)}',
              style: const TextStyle(fontSize: 12, color: KakaoTheme.secondary),
            ),
            if (linkedItem != null)
              Text(
                '🔗 $linkedItem',
                style: const TextStyle(fontSize: 11, color: Color(0xFF4A90D9)),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.withValues(alpha: 0.5)),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('삭제'),
                content: const Text('이 경비를 삭제할까요?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                  TextButton(
                    onPressed: () { onDelete(); Navigator.pop(ctx); },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('삭제'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _formatKrw(int amount) =>
    NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0).format(amount);

Color _catColor(String cat) {
  switch (cat) {
    case '식비': return const Color(0xFFED8936);
    case '교통': return const Color(0xFF4A90D9);
    case '숙박': return const Color(0xFF9F7AEA);
    case '쇼핑': return const Color(0xFFE53E3E);
    case '관광': return const Color(0xFF48BB78);
    default: return const Color(0xFF718096);
  }
}

String _catIcon(String cat) {
  switch (cat) {
    case '식비': return '🍽️';
    case '교통': return '🚃';
    case '숙박': return '🏨';
    case '쇼핑': return '🛍️';
    case '관광': return '🎟️';
    default: return '💸';
  }
}
