/// A paired friend/device. The onion address is the identity and the friend
/// list is the only discovery surface (no public directory).
class Friend {
  const Friend({required this.onion, required this.name});

  final String onion;
  final String name;
}
