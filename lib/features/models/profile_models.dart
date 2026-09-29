class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String? phone;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
    );
  }
}