import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/debts_controller.dart';
import '../../customers/controllers/customers_controller.dart';
import '../../customers/presentation/customer_profile_screen.dart';

class DebtsScreen extends StatelessWidget {
  DebtsScreen({super.key});

  final DebtsController controller = Get.put(DebtsController());
  final CustomersController custController = Get.put(CustomersController());

  String _normalizeDigits(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('سجل الديون', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black87), onPressed: () => controller.fetchDebts()),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        if (controller.debts.isEmpty) {
          return const Center(child: Text('لا توجد بيانات بعد.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.debts.length,
          itemBuilder: (context, index) {
            final debt = controller.debts[index];
            final isUnpaid = debt['status'] == 'unpaid';
            final remaining = double.parse(debt['amount'].toString()) - double.parse(debt['paid'].toString());

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                onTap: () {
                  if (debt['customer_id'] != null) {
                    Get.to(() => CustomerProfileScreen(customerId: debt['customer_id']));
                  }
                },
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnpaid ? AppTheme.danger.withValues(alpha: 0.1) : AppTheme.secondaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.receipt_long, color: isUnpaid ? AppTheme.danger : AppTheme.secondaryColor),
                ),
                title: Text(debt['customer_name'] ?? 'بدون عميل', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('متبقي: $remaining ر.ي', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(isUnpaid ? 'غير مسدد' : 'مسدد جزئياً/كلياً', 
                      style: TextStyle(color: isUnpaid ? AppTheme.danger : Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                trailing: isUnpaid ? const Icon(Icons.pending_actions, color: AppTheme.danger) : const Icon(Icons.check_circle, color: AppTheme.secondaryColor),
              ),
            ).animate().fade(delay: Duration(milliseconds: 50 * index)).slideX();
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: () => _showAddDebtDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ).animate().scale(delay: 500.ms),
    );
  }

  void _showAddDebtDialog(BuildContext context) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    dynamic selectedCustomerId;
    String enteredCustomerName = '';
    bool isSaving = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('إنشاء دين جديد'),
            content: Obx(() {
              if (custController.customers.isEmpty) {
                return const Text('الرجاء إضافة عميل أولاً من شاشة العملاء.');
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return custController.customers;
                      }
                      return custController.customers.where((customer) {
                        return customer['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    displayStringForOption: (Map<String, dynamic> option) => option['name']?.toString() ?? '',
                    onSelected: (Map<String, dynamic> selection) {
                      selectedCustomerId = selection['id'];
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onChanged: (val) {
                          enteredCustomerName = val;
                          final match = custController.customers.firstWhereOrNull(
                            (c) => c['name'].toString().trim().toLowerCase() == val.trim().toLowerCase(),
                          );
                          if (match != null) {
                            selectedCustomerId = match['id'];
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'ابحث واختر العميل',
                          prefixIcon: Icon(Icons.search),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: amountController, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(controller: notesController, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
                ],
              );
            }),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context), 
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (selectedCustomerId == null && enteredCustomerName.isNotEmpty) {
                    final match = custController.customers.firstWhereOrNull(
                      (c) => c['name'].toString().trim().toLowerCase() == enteredCustomerName.trim().toLowerCase(),
                    );
                    if (match != null) {
                      selectedCustomerId = match['id'];
                    }
                  }

                  final cleanAmount = _normalizeDigits(amountController.text.trim());
                  final amt = double.tryParse(cleanAmount) ?? 0.0;

                  if (selectedCustomerId != null && amt > 0) {
                    setState(() => isSaving = true);
                    try {
                      await controller.addDebt(selectedCustomerId, amt, notesController.text.trim());
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) setState(() => isSaving = false);
                      Get.snackbar('خطأ', 'حدث خطأ أثناء الإضافة: $e');
                    }
                  } else {
                    Get.snackbar('تنبيه', 'يرجى اختيار العميل وإدخال مبلغ صحيح أكبر من الصفر');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('إضافة وتسجيل', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      )
    );
  }
}
