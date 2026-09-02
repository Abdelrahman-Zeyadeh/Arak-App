class UserProfile {
  final String id;
  final String displayName;
  final String email;
  final String photoUrl;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.photoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      displayName: json['displayName'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
    );
  }
}
