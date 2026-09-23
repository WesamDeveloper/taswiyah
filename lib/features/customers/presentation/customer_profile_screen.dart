import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_dialog.dart';
import '../controllers/customer_profile_controller.dart';
import '../controllers/customers_controller.dart';

class CustomerProfileScreen extends StatefulWidget {
  final dynamic customerId;
  const CustomerProfileScreen({super.key, required this.customerId});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late final CustomerProfileController controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Inject unique controller tag per customer and fetch fresh profile
    controller = Get.put(
      CustomerProfileController(widget.customerId),
      tag: widget.customerId.toString(),
    );
    controller.fetchProfile();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= (maxScroll - 80)) {
      controller.loadMoreTransactions();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    Get.delete<CustomerProfileController>(tag: widget.customerId.toString());
    super.dispose();
  }

  String _normalizeDigits(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return result;
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '';
    final str = rawDate.toString().trim();
    if (str.isEmpty) return '';
    try {
      final parsed = DateTime.tryParse(str);
      if (parsed != null) {
        final year = parsed.year.toString().padLeft(4, '0');
        final month = parsed.month.toString().padLeft(2, '0');
        final day = parsed.day.toString().padLeft(2, '0');
        return '$year-$month-$day';
      }
    } catch (_) {}
    if (str.length >= 10) return str.substring(0, 10);
    return str;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'ملف العميل',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            tooltip: 'تعديل البيانات',
            onPressed: () => _showEditCustomerDialog(context, controller),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'حذف العميل',
            onPressed: () => _showDeleteConfirmation(context, widget.customerId),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black87),
            tooltip: 'تصدير كشف حساب',
            onPressed: () {
              Get.dialog(
                ExportDialog(
                  onExport: (format, start, end) {
                    controller.exportStatement(format, start, end);
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        final customer = controller.customer;
        final displayedTx = controller.displayedTransactions;

        // Safely parse remaining balance
        final remaining = double.tryParse(
          (customer['remaining_balance'] ?? 0).toString(),
        ) ?? 0.0;
        final formattedRemaining = remaining.toStringAsFixed(
          remaining.truncateToDouble() == remaining ? 0 : 2,
        );

        return RefreshIndicator(
          onRefresh: () => controller.fetchProfile(),
          color: AppTheme.primaryColor,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.business,
                    size: 40,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  customer['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  customer['primary_phone'] ?? '',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),

                // Summary Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'إجمالي المتبقي',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '$formattedRemaining ر.ي',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.danger,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _showAddPaymentDialog(context, controller),
                                icon: const Icon(
                                  Icons.payments,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'تحصيل',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.secondaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _showAddDebtDialog(context, controller),
                                icon: const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'سلفة جديدة',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: controller.isSendingReminder.value ? null : () => controller.sendReminder(),
                            icon: controller.isSendingReminder.value 
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                              : const Icon(Icons.message, color: Colors.green),
                            label: Text(
                              controller.isSendingReminder.value ? 'جاري الإرسال...' : 'إرسال تذكير عبر الواتساب',
                              style: const TextStyle(color: Colors.green),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.green),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'سجل العمليات',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'المعروض: ${displayedTx.length} من أصل ${controller.transactions.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (displayedTx.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد عمليات مسجلة بعد لهذا العميل',
                            style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'اضغط على "سلفة جديدة" أو "تحصيل" لإضافة عملية',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedTx.length,
                    itemBuilder: (context, index) {
                      final tx = displayedTx[index];
                      final isPayment = tx['tx_type'] == 'payment';
                      final dateStr = _formatDate(tx['created_at']);
                      final notes = tx['notes']?.toString().trim() ?? '';
                      final subtitleText = notes.isNotEmpty ? '$dateStr • $notes' : dateStr;

                      if (isPayment) {
                        final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
                        final formattedAmount = amount.toStringAsFixed(
                          amount.truncateToDouble() == amount ? 0 : 2,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.arrow_downward,
                              color: Colors.green,
                            ),
                            title: Text('تحصيل مبلغ $formattedAmount ر.ي'),
                            subtitle: Text(subtitleText),
                            trailing: const Text(
                              'دفعة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        );
                      } else {
                        final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
                        final paid = double.tryParse(tx['paid']?.toString() ?? '0') ?? 0.0;
                        final remainingDebt = (amount - paid) < 0 ? 0.0 : (amount - paid);
                        final isPaid = tx['status'] == 'paid' || remainingDebt == 0;
                        final formattedAmount = amount.toStringAsFixed(
                          amount.truncateToDouble() == amount ? 0 : 2,
                        );
                        final formattedDebtRemaining = remainingDebt.toStringAsFixed(
                          remainingDebt.truncateToDouble() == remainingDebt ? 0 : 2,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.arrow_upward, color: Colors.red),
                            title: Text('سلفة $formattedAmount ر.ي'),
                            subtitle: Text(subtitleText),
                            trailing: Text(
                              isPaid ? 'مسددة' : 'متبقي $formattedDebtRemaining ر.ي',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isPaid ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),

                  // Pagination footer
                  if (controller.isLoadingMore.value)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'جاري تحميل المزيد من العمليات...',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (controller.hasMoreTransactions.value)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => controller.loadMoreTransactions(),
                          icon: const Icon(
                            Icons.arrow_downward,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          label: const Text(
                            'عرض المزيد (5 عمليات إضافية)',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (controller.displayedTransactions.isNotEmpty &&
                      controller.transactions.length > CustomerProfileController.pageSize)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          'تم عرض جميع العمليات (${controller.transactions.length})',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showAddDebtDialog(
    BuildContext context,
    CustomerProfileController controller,
  ) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isSaving = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('إضافة سلفة جديدة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  final cleanText = _normalizeDigits(amountController.text.trim());
                  final parsedAmount = double.tryParse(cleanText);
                  if (parsedAmount != null && parsedAmount > 0) {
                    setState(() => isSaving = true);
                    try {
                      await controller.addDebt(
                        parsedAmount,
                        notesController.text.trim(),
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) setState(() => isSaving = false);
                      Get.snackbar('خطأ', 'حدث خطأ أثناء الإضافة');
                    }
                  } else {
                    Get.snackbar('تنبيه', 'يرجى إدخال مبلغ صحيح أكبر من الصفر');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('إضافة وتنبيه', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showAddPaymentDialog(
    BuildContext context,
    CustomerProfileController controller,
  ) {
    final amountController = TextEditingController();
    bool isSaving = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('تحصيل دفعة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'سيتم خصم هذا المبلغ من أقدم سلفة غير مسددة على العميل تلقائياً.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'المبلغ المحصل'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  final cleanText = _normalizeDigits(amountController.text.trim());
                  final parsedAmount = double.tryParse(cleanText);
                  if (parsedAmount != null && parsedAmount > 0) {
                    setState(() => isSaving = true);
                    try {
                      await controller.receivePayment(parsedAmount);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) setState(() => isSaving = false);
                      Get.snackbar('خطأ', 'حدث خطأ أثناء التحصيل');
                    }
                  } else {
                    Get.snackbar('تنبيه', 'يرجى إدخال مبلغ صحيح أكبر من الصفر');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                ),
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('تأكيد التحصيل', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showEditCustomerDialog(
    BuildContext context,
    CustomerProfileController controller,
  ) {
    final nameController = TextEditingController(
      text: controller.customer['name'],
    );
    String originalPhone = controller.customer['primary_phone'] ?? '';
    String selectedCountryCode = '+967';
    String phoneWithoutCode = originalPhone;
    bool isSaving = false;

    final List<Map<String, String>> countryCodes = [
      {'code': '+967', 'flag': '🇾🇪'},
      {'code': '+966', 'flag': '🇸🇦'},
      {'code': '+20', 'flag': '🇪🇬'},
      {'code': '+971', 'flag': '🇦🇪'},
    ];

    for (var c in countryCodes) {
      if (originalPhone.startsWith(c['code']!.substring(1))) {
        selectedCountryCode = c['code']!;
        phoneWithoutCode = originalPhone.substring(c['code']!.length - 1);
        break;
      }
    }

    final phoneController = TextEditingController(text: phoneWithoutCode);

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('تعديل بيانات العميل'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل / المتجر',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCountryCode,
                          items: countryCodes.map((country) {
                            return DropdownMenuItem<String>(
                              value: country['code'],
                              child: Text(
                                '${country['flag']} ${country['code']}',
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedCountryCode = val!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف للواتساب',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (nameController.text.isNotEmpty &&
                      phoneController.text.isNotEmpty) {
                    setState(() => isSaving = true);
                    String finalPhone = phoneController.text.trim();
                    if (finalPhone.startsWith('0')) {
                      finalPhone = finalPhone.substring(1);
                    }
                    String fullPhone =
                        '${selectedCountryCode.replaceAll('+', '')}$finalPhone';
                    try {
                      await controller.updateProfile(nameController.text, fullPhone);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) setState(() => isSaving = false);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text(
                  'حفظ التعديلات',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, dynamic customerId) {
    Get.dialog(
      AlertDialog(
        title: const Text('حذف العميل', style: TextStyle(color: Colors.red)),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف هذا العميل وجميع ديونه ومدفوعاته؟\n\nلا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back(); // close dialog
              Get.back(); // close profile screen
              Get.find<CustomersController>().deleteCustomer(customerId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'حذف نهائي',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
