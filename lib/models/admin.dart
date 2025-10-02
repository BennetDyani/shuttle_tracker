class Admin {
  final int adminId;
  final int userId;
  final String name;
  final String surname;
  final String email;

  Admin({
    required this.adminId,
    required this.userId,
    required this.name,
    required this.surname,
    required this.email,
  });

  factory Admin.fromMap(Map<String, dynamic> map) {
    return Admin(
      adminId: map['admin_id'],
      userId: map['user_id'],
      name: map['name'],
      surname: map['surname'],
      email: map['email'],
    );
  }
}

