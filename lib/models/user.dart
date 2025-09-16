class User {
  final int userId;
  final String name;
  final String surname;
  final String email;
  final String userType;

  User({
    required this.userId,
    required this.name,
    required this.surname,
    required this.email,
    required this.userType,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['user_id'],
      name: map['name'],
      surname: map['surname'],
      email: map['email'],
      userType: map['user_type'] ?? 'student',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'surname': surname,
      'email': email,
      'user_type': userType,
    };
  }
}