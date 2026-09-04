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

  /// Converts this contact into a JSON-compatible map for storage.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'relation': relation,
      'phoneNumber': phoneNumber,
      'cnic': cnic,
      'isDefault': isDefault,
    };
  }

  /// Builds a [ContactModel] back from a stored JSON map.
  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      name: json['name'] as String? ?? '',
      relation: json['relation'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      cnic: json['cnic'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactModel &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          relation == other.relation &&
          phoneNumber == other.phoneNumber &&
          cnic == other.cnic &&
          isDefault == other.isDefault;

  @override
  int get hashCode =>
      name.hashCode ^
      relation.hashCode ^
      phoneNumber.hashCode ^
      cnic.hashCode ^
      isDefault.hashCode;
}