import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/customers_controller.dart';
import '../models/customer_trust_status.dart';
import 'customer_profile_screen.dart';

class CustomersScreen extends StatelessWidget {
  CustomersScreen({super.key});

  final CustomersController controller = Get.put(CustomersController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceLight,
        elevation: 0,
        title: const Text(
          'العملاء',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () => controller.fetchCustomers(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: controller.searchCustomers,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن اسم العميل أو رقمه...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterButton(context),
                ],
              ),
            ),
            if (controller.customers.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    controller.searchQuery.isNotEmpty
                        ? 'لم يتم العثور على نتائج للبحث.'
                        : controller.selectedFilter.value != CustomerTrustFilter.all
                            ? 'لا يوجد عملاء بحالة "${controller.selectedFilter.value.label}".'
                            : 'لا توجد بيانات بعد. قم بإضافة عميل جديد.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: controller.customers.length,
                  itemBuilder: (context, index) {
                    final customer = controller.customers[index];
                    final balance = customer['remaining_balance'] ?? 0;
                    final trustStatus = customer['trust_status'] ?? customer['trustStatus'] ?? 'unknown';

                    return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          child: ListTile(
                            onTap: () {
                              Get.to(
                                () => CustomerProfileScreen(
                                  customerId: customer['id'],
                                ),
                              );
                            },
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              child: const Icon(
                                Icons.business,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    customer['name'] ?? 'بدون اسم',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (trustStatus == 'trusted') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'موثوق',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ] else if (trustStatus == 'untrusted') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade800.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'غير موثوق',
                                      style: TextStyle(
                                        color: Colors.orange.shade800,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              customer['primary_phone'] ?? '',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$balance ر.ي',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  balance > 0 ? 'متبقي' : 'خالص',
                                  style: TextStyle(
                                    color: balance > 0
                                        ? AppTheme.danger
                                        : AppTheme.secondaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fade(delay: Duration(milliseconds: 50 * index))
                        .slideX();
                  },
                ),
              ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: () => _showAddCustomerDialog(context),
        child: const Icon(Icons.person_add, color: Colors.white),
      ).animate().scale(delay: 500.ms),
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    final currentFilter = controller.selectedFilter.value;
    final isFiltered = currentFilter != CustomerTrustFilter.all;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      child: PopupMenuButton<CustomerTrustFilter>(
        tooltip: 'فلترة حسب حالة الثقة',
        initialValue: currentFilter,
        onSelected: (filter) => controller.setFilter(filter),
        elevation: 4,
        offset: const Offset(0, 52),
        itemBuilder: (context) => [
          const PopupMenuItem<CustomerTrustFilter>(
            enabled: false,
            height: 36,
            child: Text(
              'حالة العملاء',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          const PopupMenuDivider(height: 8),
          ...CustomerTrustFilter.values.map((filter) {
            final isSelected = currentFilter == filter;
            return PopupMenuItem<CustomerTrustFilter>(
              value: filter,
              height: 40,
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    filter.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryColor : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFiltered ? AppTheme.primaryColor : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list,
                size: 20,
                color: isFiltered ? AppTheme.primaryColor : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                currentFilter.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isFiltered ? AppTheme.primaryColor : Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: isFiltered ? AppTheme.primaryColor : Colors.grey.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedCountryCode = '+967';
    final List<Map<String, String>> countryCodes = [
      {'code': '+967', 'flag': '🇾🇪'},
      {'code': '+966', 'flag': '🇸🇦'},
      {'code': '+20', 'flag': '🇪🇬'},
      {'code': '+971', 'flag': '🇦🇪'},
    ];

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('إضافة عميل جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    if (await FlutterContacts.permissions.request(
                          PermissionType.read,
                        ) ==
                        PermissionStatus.granted) {
                      final contact = await FlutterContacts.native.showPicker(
                        properties: {ContactProperty.phone},
                      );
                      if (contact != null) {
                        setState(() {
                          nameController.text = contact.displayName!;
                          if (contact.phones.isNotEmpty) {
                            String rawPhone = contact.phones.first.number
                                .replaceAll(RegExp(r'[\s\-()]+'), '');

                            // Auto-select country code if detected in the phone
                            for (var c in countryCodes) {
                              if (rawPhone.startsWith(c['code']!)) {
                                selectedCountryCode = c['code']!;
                                rawPhone = rawPhone.substring(
                                  c['code']!.length,
                                );
                                break;
                              }
                            }
                            phoneController.text = rawPhone;
                          }
                        });
                      }
                    } else {
                      Get.snackbar(
                        'صلاحية مرفوضة',
                        'لم يتم منح صلاحية الوصول لجهات الاتصال',
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.contacts,
                    color: AppTheme.primaryColor,
                  ),
                  label: const Text(
                    'استيراد من جهات الاتصال',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                    // Combine country code and number, remove leading zeros from number
                    String finalPhone = phoneController.text.trim();
                    if (finalPhone.startsWith('0')) {
                      finalPhone = finalPhone.substring(1);
                    }
                    String fullPhone =
                        '${selectedCountryCode.replaceAll('+', '')}$finalPhone';

                    // Close dialog immediately for better UX
                    Get.back();

                    // Add customer in the background
                    controller.addCustomer(nameController.text, fullPhone);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text(
                  'إضافة',
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
