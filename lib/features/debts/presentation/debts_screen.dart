import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/debts_controller.dart';
import '../../customers/controllers/customers_controller.dart';

import '../../../core/network/sync_service.dart';

class DebtsScreen extends StatelessWidget {
  DebtsScreen({Key? key}) : super(key: key);

  final DebtsController controller = Get.put(DebtsController());
  final CustomersController custController = Get.put(CustomersController());
  final SyncService syncService = Get.find<SyncService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('سجل الديون', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        leading: Obx(() => syncService.isOnline.value 
            ? const SizedBox() 
            : const Icon(Icons.cloud_off, color: Colors.orange)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black87), onPressed: () => controller.fetchDebts()),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        if (controller.debts.isEmpty) {
          return const Center(child: Text('لا توجد ديون مسجلة.'));
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
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnpaid ? AppTheme.danger.withOpacity(0.1) : AppTheme.secondaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.receipt_long, color: isUnpaid ? AppTheme.danger : AppTheme.secondaryColor),
                ),
                title: Text(debt['customer']?['name'] ?? 'بدون عميل', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                trailing: isUnpaid ? ElevatedButton(
                  onPressed: () {
                    // Logic to pay debt will be added here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('تحصيل', style: TextStyle(fontSize: 12, color: Colors.white)),
                ) : const Icon(Icons.check_circle, color: AppTheme.secondaryColor),
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
    int? selectedCustomerId;
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
                        return custController.customers.cast<Map<String, dynamic>>();
                      }
                      return custController.customers.cast<Map<String, dynamic>>().where((customer) {
                        return customer['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    displayStringForOption: (Map<String, dynamic> option) => option['name'],
                    onSelected: (Map<String, dynamic> selection) {
                      selectedCustomerId = selection['id'];
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
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
                  if (selectedCustomerId != null && amountController.text.isNotEmpty) {
                    setState(() => isSaving = true);
                    try {
                      await controller.addDebt(selectedCustomerId!, double.parse(amountController.text), notesController.text);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) setState(() => isSaving = false);
                      Get.snackbar('خطأ', 'حدث خطأ أثناء الإضافة');
                    }
                  } else {
                    Get.snackbar('تنبيه', 'يرجى اختيار العميل وإدخال المبلغ');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('إضافة وإشعار', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      )
    );
  }
}
