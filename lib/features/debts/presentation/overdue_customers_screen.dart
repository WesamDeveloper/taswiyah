import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_theme.dart';
import '../../customers/models/customer_trust_status.dart';
import '../../customers/presentation/customer_profile_screen.dart';
import '../controllers/overdue_controller.dart';
import '../models/overdue_period.dart';

class OverdueCustomersScreen extends StatelessWidget {
  const OverdueCustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OverdueController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'المتأخرين عن السداد',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () => controller.fetchOverdueCustomers(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Section: Period Selector Card & Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row of period selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Obx(
                          () => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'حسبة المتأخرين عن السداد',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                OverduePeriod.getLabelForDays(
                                  controller.selectedDays.value,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => _showCustomDaysDialog(context, controller),
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('تخصيص', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick choice chips for predefined periods
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Obx(() {
                    final currentDays = controller.selectedDays.value;
                    return Row(
                      children: [
                        ...OverduePeriod.predefined.map((period) {
                          final isSelected = currentDays == period.days;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(period.label),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                              selectedColor: Colors.orange.shade800,
                              backgroundColor: Colors.grey.shade100,
                              checkmarkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? Colors.orange.shade800 : Colors.grey.shade300,
                                ),
                              ),
                              onSelected: (_) => controller.setThresholdDays(period.days),
                            ),
                          );
                        }),
                        // Custom Chip if a non-predefined duration is chosen
                        if (!OverduePeriod.predefined.any((p) => p.days == currentDays))
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: FilterChip(
                              selected: true,
                              label: Text('$currentDays يوم (مخصص)'),
                              labelStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              selectedColor: Colors.orange.shade800,
                              checkmarkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onSelected: (_) {},
                            ),
                          ),
                      ],
                    );
                  }),
                ),

                const SizedBox(height: 12),

                // Search Box
                TextField(
                  onChanged: controller.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو رقم الهاتف...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Summary KPI Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade100,
            child: Obx(
              () => Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, size: 18, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('العدد', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                Text(
                                  '${controller.filteredCustomers.length} عميل',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.money_off, size: 18, color: AppTheme.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('إجمالي المتأخرات', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                Text(
                                  '${controller.totalOverdueBalance.value.toStringAsFixed(0)} ر.ي',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.danger,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Customers List
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.filteredCustomers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 64,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا يوجد عملاء متأخرين عن السداد',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'لم يتجاوز أي عميل فترة ${OverduePeriod.getShortLabelForDays(controller.selectedDays.value)} بدون سداد.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: controller.filteredCustomers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final customer = controller.filteredCustomers[index];
                  final name = customer['name']?.toString() ?? 'عميل';
                  final phone = customer['primary_phone']?.toString() ?? '';
                  final remaining = double.tryParse((customer['remaining_balance'] ?? 0).toString()) ?? 0.0;
                  final daysOverdue = customer['days_overdue'] as int? ?? 0;
                  final lastPayment = customer['last_payment_date']?.toString();
                  final trustStatus = CustomerTrustStatus.fromDbValue(customer['trust_status']);

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await Get.to(() => CustomerProfileScreen(customerId: customer['id']));
                        controller.fetchOverdueCustomers();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Customer name + Trust Badge + Arrow
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  child: Text(
                                    name.isNotEmpty ? name.substring(0, 1) : 'ع',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (trustStatus != CustomerTrustStatus.unknown) ...[
                                        const SizedBox(width: 6),
                                        _buildTrustBadge(trustStatus),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                              ],
                            ),
                            const Divider(height: 18),

                            // Phone & Remaining balance
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.phone_outlined, size: 15, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      phone.isNotEmpty ? phone : 'لا يوجد هاتف',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text('المتبقي: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(
                                      '${remaining.toStringAsFixed(0)} ر.ي',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.danger,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Overdue details banner
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, size: 15, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        'متأخر منذ $daysOverdue يوماً',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    lastPayment != null && lastPayment.length >= 10
                                        ? 'آخر سداد: ${lastPayment.substring(0, 10)}'
                                        : 'لم يقم بأي سداد مسبقاً',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(CustomerTrustStatus status) {
    final isTrusted = status == CustomerTrustStatus.trusted;
    final color = isTrusted ? Colors.green : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isTrusted ? Icons.check_circle : Icons.warning_amber_rounded, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            status.label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  void _showCustomDaysDialog(BuildContext context, OverdueController controller) {
    final textController = TextEditingController(text: controller.selectedDays.value.toString());
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.tune, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('تحديد مدة التأخير'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل عدد الأيام التي إذا مرت على العميل دون سداد يُعتبر متأخراً:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'عدد الأيام',
                suffixText: 'يوم',
                hintText: 'مثال: 30، 45، 60',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(textController.text.trim());
              if (parsed != null && parsed > 0) {
                Get.back();
                controller.setThresholdDays(parsed);
              } else {
                Get.snackbar('تنبيه', 'يرجى إدخال عدد أيام صحيح أكبر من الصفر');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('تطبيق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
