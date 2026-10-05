import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_dialog.dart';
import '../controllers/customer_profile_controller.dart';
import '../controllers/customers_controller.dart';
import '../models/customer_trust_status.dart';

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
        final rawTrust = customer['trust_status'] ?? customer['trustStatus'];
        final trustStatus = CustomerTrustStatus.fromString(rawTrust?.toString());

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
                if (trustStatus == CustomerTrustStatus.trusted) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'عميل موثوق',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (trustStatus == CustomerTrustStatus.untrusted) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'عميل غير موثوق',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Customer Trust Status Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 20,
                                  color: AppTheme.primaryColor,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'حالة العميل',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              trustStatus.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: trustStatus == CustomerTrustStatus.trusted
                                    ? Colors.green
                                    : trustStatus == CustomerTrustStatus.untrusted
                                        ? Colors.orange.shade800
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTrustOption(
                                status: CustomerTrustStatus.unknown,
                                isSelected: trustStatus == CustomerTrustStatus.unknown,
                                icon: Icons.help_outline,
                                activeColor: Colors.grey.shade700,
                                onTap: () => controller.updateTrustStatus(CustomerTrustStatus.unknown),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTrustOption(
                                status: CustomerTrustStatus.trusted,
                                isSelected: trustStatus == CustomerTrustStatus.trusted,
                                icon: Icons.check_circle_outline,
                                activeColor: Colors.green,
                                onTap: () => controller.updateTrustStatus(CustomerTrustStatus.trusted),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTrustOption(
                                status: CustomerTrustStatus.untrusted,
                                isSelected: trustStatus == CustomerTrustStatus.untrusted,
                                icon: Icons.warning_amber_rounded,
                                activeColor: Colors.orange.shade800,
                                onTap: () => controller.updateTrustStatus(CustomerTrustStatus.untrusted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                            onPressed: () => _showReminderOptions(context, controller),
                            icon: const Icon(Icons.send_to_mobile, color: AppTheme.primaryColor),
                            label: const Text(
                              'إرسال تذكير بالرصيد',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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

  Widget _buildTrustOption({
    required CustomerTrustStatus status,
    required bool isSelected,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : Colors.grey.shade300,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 15,
                    color: isSelected ? activeColor : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? activeColor : Colors.grey.shade500,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                status.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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
    final notesController = TextEditingController();
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
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    hintText: 'مثال: تسديد نقدي، حوالة، دفعة...',
                  ),
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
                      await controller.receivePayment(
                        parsedAmount,
                        notes: notesController.text.trim(),
                      );
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

  void _showReminderOptions(
    BuildContext context,
    CustomerProfileController controller,
  ) {
    final currentCustomer = controller.customer;
    final remaining = double.tryParse((currentCustomer['remaining_balance'] ?? 0).toString()) ?? 0.0;
    final phone = currentCustomer['primary_phone']?.toString().trim() ?? '';

    if (remaining <= 0) {
      Get.snackbar(
        'تنبيه',
        'لا يوجد رصيد متبقي على هذا العميل',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    if (phone.isEmpty) {
      Get.snackbar(
        'خطأ',
        'رقم هاتف العميل غير متوفر لإرسال التذكير',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'إرسال تذكير بالرصيد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اختر طريقة إرسال التذكير للعميل (${currentCustomer['name'] ?? ''})',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat,
                      color: Color(0xFF25D366),
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'واتساب (WhatsApp)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: const Text(
                    'إرسال رسالة تذكير منسقة عبر تطبيق واتساب',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller.sendWhatsAppReminder();
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sms_outlined,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'رسالة نصية (SMS)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: const Text(
                    'إرسال رسالة SMS مباشرة إلى رقم هاتف العميل',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    controller.sendSmsReminder();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
