import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/kakao_theme.dart';
import '../providers/chat_provider.dart';

class ExpenseTab extends ConsumerWidget {
  final String tripId;

  const ExpenseTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider(tripId));

    final totalKrw = expenses.fold<int>(0, (sum, e) => sum + ((e['amount'] as num?)?.toInt() ?? 0));
    final byCategory = <String, int>{};
    for (final e in expenses) {
      final cat = e['category'] as String? ?? '기타';
      byCategory[cat] = (byCategory[cat] ?? 0) + ((e['amount'] as num?)?.toInt() ?? 0);
    }

    return Container(
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // Summary header
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                const Text('총 지출', style: TextStyle(fontSize: 14, color: KakaoTheme.secondary)),
                const SizedBox(height: 4),
                Text(
                  NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0).format(totalKrw),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: KakaoTheme.primary),
                ),
                if (byCategory.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: byCategory.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _catColor(e.key).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_catIcon(e.key)} ${e.key}  ${NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0).format(e.value)}',
                          style: TextStyle(fontSize: 12, color: _catColor(e.key), fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
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
              onTap: () => _showAddExpenseSheet(context, ref),
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
                    Text('지출 추가', style: TextStyle(fontSize: 14, color: Color(0xFF48BB78), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Expense list
          Expanded(
            child: expenses.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('💰', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 16),
                        Text('아직 지출 기록이 없어요', style: TextStyle(fontSize: 16, color: KakaoTheme.secondary)),
                        Text('여행 경비를 기록해보세요!', style: TextStyle(fontSize: 14, color: KakaoTheme.secondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final e = expenses[index];
                      return _ExpenseTile(
                        expense: e,
                        onDelete: () => ref.read(expensesProvider(tripId).notifier).remove(e['id']),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    String selectedCategory = '식비';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text('💰 지출 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
                    spacing: 8,
                    runSpacing: 8,
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
                            style: TextStyle(
                              color: isSelected ? Colors.white : _catColor(cat),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
                  // Submit
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
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text('추가', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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
          NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0).format(amount),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${memo ?? category}  •  ${DateFormat('M/d HH:mm').format(spentAt)}',
          style: const TextStyle(fontSize: 12, color: KakaoTheme.secondary),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.withValues(alpha: 0.5)),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('삭제'),
                content: const Text('이 지출을 삭제할까요?'),
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
