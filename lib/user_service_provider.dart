import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/user_service.dart';

class UserServiceProvider extends StatelessWidget {
  final Widget child;
  const UserServiceProvider({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserService>(
      create: (_) => UserService(),
      child: child,
    );
  }
}
