import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/contact_model.dart';

/// Formats CNIC input as XXXXX-XXXXXXX-X while typing.
class _CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final trimmed = digits.length > 13 ? digits.substring(0, 13) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      buffer.write(trimmed[i]);
      if ((i == 4 || i == 11) && i != trimmed.length - 1) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // Default emergency helpline is always present and cannot be removed.
  final List<ContactModel> _contacts = [
    const ContactModel(
      name: 'Emergency Helpline',
      relation: 'Emergency Service',
      phoneNumber: '911',
      isDefault: true,
    ),
  ];

  void _openAddContactSheet() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final relationController = TextEditingController();
    final phoneController = TextEditingController();
    final cnicController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
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
                    'Add Trusted Contact',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      prefixIcon: const Icon(Icons.person_outline),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red.shade600),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'This field is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: relationController,
                    decoration: InputDecoration(
                      labelText: 'Relation *',
                      hintText: 'e.g. Father, Sister, Friend',
                      prefixIcon: const Icon(Icons.diversity_3_outlined),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red.shade600),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'This field is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red.shade600),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'This field is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: cnicController,
                    keyboardType: TextInputType.number,
                    maxLength: 15,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CnicInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'CNIC (XXXXX-XXXXXXX-X)',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red.shade600),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null; // optional
                      if (v.replaceAll('-', '').length != 13) {
                        return 'Enter a valid 13-digit CNIC';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;

                        setState(() {
                          _contacts.add(
                            ContactModel(
                              name: nameController.text.trim(),
                              relation: relationController.text.trim(),
                              phoneNumber: phoneController.text.trim(),
                              cnic: cnicController.text.trim(),
                            ),
                          );
                        });

                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Save Contact',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _removeContact(ContactModel contact) {
    setState(() {
      _contacts.remove(contact);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red.shade600,
        onPressed: _openAddContactSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.grey.shade100,
              child: const Text(
                'TRUSTED CONTACTS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: _contacts.isEmpty
                  ? const Center(
                      child: Text(
                        'Trusted contacts will appear here',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: contact.isDefault
                                ? Border.all(color: Colors.red.shade200)
                                : null,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: contact.isDefault
                                    ? Colors.red.shade600
                                    : Colors.grey.shade300,
                                child: Icon(
                                  contact.isDefault
                                      ? Icons.local_phone
                                      : Icons.person,
                                  color: contact.isDefault
                                      ? Colors.white
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      contact.relation,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      contact.phoneNumber,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    if (contact.cnic.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'CNIC: ${contact.cnic}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!contact.isDefault)
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Colors.grey.shade600),
                                  onPressed: () => _removeContact(contact),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}