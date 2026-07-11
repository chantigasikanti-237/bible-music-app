import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/app_shell_controller.dart';
import 'controllers/bible_controller.dart';
import 'services/user_service.dart';

class UserServiceProvider extends StatelessWidget {
  final Widget child;
  const UserServiceProvider({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserService>(create: (_) => UserService()),
        ChangeNotifierProvider<AppShellController>(
          create: (_) => AppShellController(),
        ),
        ChangeNotifierProxyProvider<UserService, BibleController>(
          create: (_) => BibleController(),
          update: (
            BuildContext context,
            UserService userService,
            BibleController? controller,
          ) {
            final resolvedController = controller ?? BibleController();
            resolvedController.bindUserService(userService);
            return resolvedController;
          },
        ),
      ],
      child: child,
    );
  }
}
