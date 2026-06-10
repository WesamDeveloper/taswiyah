import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/export_dialog.dart';
import '../controllers/customer_profile_controller.dart';

class CustomerProfileScreen extends StatelessWidget {
  final int customerId;
  const CustomerProfileScreen({Key? key, required this.customerId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Inject unique controller tag per customer
    final controller = Get.put(
      CustomerProfileController(customerId),
      tag: customerId.toString(),
    );

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
            icon: const Icon(Icons.schedule, color: Colors.blue),
            tooltip: 'جدولة الرسائل',
            onPressed: () => _showScheduleDialog(context, controller),
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
        final debts = controller.debts;

        double totalDebt = 0;
        double totalPaid = 0;
        for (var d in debts) {
          totalDebt += double.parse(d['amount'].toString());
          totalPaid += double.parse(d['paid'].toString());
        }
        final remaining = totalDebt - totalPaid;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
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
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'إرسال تذكير تلقائي عند إضافة سلفة',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  Switch(
                    value:
                        customer['notify_on_debt'] == 1 ||
                        customer['notify_on_debt'] == true,
                    onChanged: (val) {
                      controller.toggleDebtNotification(val);
                    },
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
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
                            '$remaining ر.ي',
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
                          onPressed: () => controller.sendReminder(),
                          icon: const Icon(Icons.message, color: Colors.green),
                          label: const Text(
                            'إرسال تذكير عبر الواتساب',
                            style: TextStyle(color: Colors.green),
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
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'سجل العمليات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              if (debts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('لا توجد عمليات مسجلة.'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: debts.length,
                  itemBuilder: (context, index) {
                    final debt = debts[index];
                    final isPaid = debt['status'] == 'paid';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          isPaid ? Icons.check_circle : Icons.warning_amber,
                          color: isPaid
                              ? AppTheme.secondaryColor
                              : AppTheme.danger,
                        ),
                        title: Text('سلفة ${debt['amount']} ر.ي'),
                        subtitle: Text(
                          debt['created_at'].toString().substring(0, 10),
                        ),
                        trailing: Text(
                          isPaid
                              ? 'مسددة'
                              : 'متبقي ${double.parse(debt['amount'].toString()) - double.parse(debt['paid'].toString())}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPaid ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
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

    Get.dialog(
      AlertDialog(
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
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                controller.addDebt(
                  double.parse(amountController.text),
                  notesController.text,
                );
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text(
              'إضافة وتنبيه',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog(
    BuildContext context,
    CustomerProfileController controller,
  ) {
    final amountController = TextEditingController();

    Get.dialog(
      AlertDialog(
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
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                controller.receivePayment(double.parse(amountController.text));
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
            ),
            child: const Text(
              'تأكيد التحصيل',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog(
    BuildContext context,
    CustomerProfileController controller,
  ) {
    final daysController = TextEditingController();
    DateTime? selectedDate;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('جدولة التذكير الآلي للعميل'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تاريخ بدء التذكير:'),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    selectedDate == null
                        ? 'لم يتم التحديد'
                        : selectedDate!.toString().substring(0, 10),
                  ),
                  trailing: const Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: daysController,
                  decoration: const InputDecoration(
                    labelText: 'تكرار (كل كم يوم؟ اختياري)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedDate == null) {
                    Get.snackbar('تنبيه', 'يرجى تحديد التاريخ');
                    return;
                  }
                  Get.back();
                  int? days = int.tryParse(daysController.text);
                  controller.updateSchedule(selectedDate, days);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
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
                onPressed: () => Get.back(),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      phoneController.text.isNotEmpty) {
                    String finalPhone = phoneController.text.trim();
                    if (finalPhone.startsWith('0')) {
                      finalPhone = finalPhone.substring(1);
                    }
                    String fullPhone =
                        '${selectedCountryCode.replaceAll('+', '')}$finalPhone';
                    controller.updateProfile(nameController.text, fullPhone);
                    Get.back();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text(
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
}
