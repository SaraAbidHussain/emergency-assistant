class ContactModel {
  final String name;
  final String relation;
  final String phoneNumber;
  final String cnic;
  final bool isDefault;

  const ContactModel({
    required this.name,
    required this.relation,
    required this.phoneNumber,
    this.cnic = '',
    this.isDefault = false,
  });
}