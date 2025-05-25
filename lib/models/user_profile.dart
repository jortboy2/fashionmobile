class UserProfile {
  final int id;
  final String username;
  final String email;
  final String? phone;
  final String? address;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    this.address,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      phone: json['phone'],
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'address': address,
    };
  }

  UserProfile copyWith({
    String? username,
    String? phone,
    String? address,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      email: email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
    );
  }
}
