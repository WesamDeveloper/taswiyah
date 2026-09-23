import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/customers_controller.dart';
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

        if (controller.customers.isEmpty && controller.searchQuery.isEmpty) {
          return const Center(
            child: Text('لا توجد بيانات بعد. قم بإضافة عميل جديد.'),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: controller.searchCustomers,
                decoration: InputDecoration(
                  hintText: 'ابحث عن اسم العميل أو رقمه...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (controller.customers.isEmpty)
              const Expanded(
                child: Center(child: Text('لم يتم العثور على نتائج.')),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: controller.customers.length,
                  itemBuilder: (context, index) {
                    final customer = controller.customers[index];
                    final balance = customer['remaining_balance'] ?? 0;

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
                                  .withOpacity(0.1),
                              child: const Icon(
                                Icons.business,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            title: Text(
                              customer['name'] ?? 'بدون اسم',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
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
