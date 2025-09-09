import 'package:meta/meta.dart';

@immutable
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
  });

  final int id;
  final String name;
  final String email;
  final String? avatar;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? avatar,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == id &&
          other.name == name &&
          other.email == email &&
          other.avatar == avatar);

  @override
  int get hashCode => Object.hash(id, name, email, avatar);

  @override
  String toString() => 'User(id: $id, name: $name, email: $email, avatar: $avatar)';
}
