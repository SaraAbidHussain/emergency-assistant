class UserModel {
  final String fullName;
  final String phoneNumber;
  final String dateOfBirth; // stored as string e.g. "2000-05-14"
  final String bloodGroup;
  final String homeAddress;
  final String passwordHash;

  UserModel({
    required this.fullName,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.bloodGroup,
    required this.homeAddress,
    required this.passwordHash,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'dateOfBirth': dateOfBirth,
        'bloodGroup': bloodGroup,
        'homeAddress': homeAddress,
        'passwordHash': passwordHash,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        fullName: json['fullName'] as String,
        phoneNumber: json['phoneNumber'] as String,
        dateOfBirth: json['dateOfBirth'] as String,
        bloodGroup: json['bloodGroup'] as String,
        homeAddress: json['homeAddress'] as String,
        passwordHash: json['passwordHash'] as String,
      );
}