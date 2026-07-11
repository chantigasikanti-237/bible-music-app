import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../services/user_service.dart';
import '../../config/supported_languages.dart';
import '../../widgets/adaptive_layout.dart';
import '../../theme/clay_decorations.dart';

import 'profile_controller.dart';
import 'bookmarked_verses_page.dart';
import 'favorite_music_page.dart';
import '../bible/downloads_manager_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileController(
          userService: Provider.of<UserService>(context, listen: false)),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const Map<String, List<String>> _sectionKeywords = <String, List<String>>{
    'account': <String>['account', 'login', 'register', 'logout', 'sign', 'email', 'password', 'user', 'guest', 'profile'],
    'language': <String>['language', 'bible', 'music', 'translation', 'version', 'lang', 'telugu', 'hindi', 'english', 'tamil'],
    'theme': <String>['theme', 'dark', 'light', 'system', 'appearance', 'color', 'mode'],
    'saved': <String>['saved', 'bookmark', 'verse', 'favorite', 'music', 'song', 'history', 'content'],
    'downloads': <String>['download', 'offline', 'bible', 'audio', 'storage'],
    'about': <String>['about', 'version', 'privacy', 'contact', 'rate', 'app', 'info'],
  };

  bool _sectionVisible(String key) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return _sectionKeywords[key]?.any((kw) => kw.contains(q)) ?? false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ProfileController>(context);
    final user = controller.user;

    final showAccount = _sectionVisible('account');
    final showLanguage = _sectionVisible('language');
    final showTheme = _sectionVisible('theme');
    final showSaved = _sectionVisible('saved');
    final showDownloads = _sectionVisible('downloads');
    final showAbout = _sectionVisible('about');
    final anyVisible = showAccount || showLanguage || showTheme || showSaved || showDownloads || showAbout;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget searchBar = DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2822) : const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(18),
        boxShadow: clayShadows(isDark),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v.trim()),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search settings, history…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );

    Widget noResults = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No settings found for "$_query"',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    List<Widget> buildSections() => <Widget>[
          if (showAccount) ...<Widget>[
            _AccountSection(controller: controller, user: user),
            const SizedBox(height: 20),
          ],
          if (showLanguage) ...<Widget>[
            _LanguageSection(controller: controller, user: user),
            const SizedBox(height: 20),
          ],
          if (showTheme) ...<Widget>[
            _ThemeSection(controller: controller, user: user),
            const SizedBox(height: 20),
          ],
          if (showSaved) ...<Widget>[
            _SavedContentSection(controller: controller, user: user),
            const SizedBox(height: 20),
          ],
          if (showDownloads) ...<Widget>[
            const _DownloadsSection(),
            const SizedBox(height: 20),
          ],
          if (showAbout) const _AboutSection(),
        ];

    return AdaptiveScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Profile')),
      bodyBuilder: (BuildContext context, AdaptiveLayoutInfo layout) {
        if (!layout.useTwoPane) {
          return ListView(
            padding: layout.pagePadding,
            children: <Widget>[
              searchBar,
              const SizedBox(height: 16),
              if (!anyVisible) noResults else ...buildSections(),
            ],
          );
        }

        final primarySections = <Widget>[
          searchBar,
          const SizedBox(height: 16),
          if (showAccount) ...<Widget>[
            _AccountSection(controller: controller, user: user),
            const SizedBox(height: 20),
          ],
          if (showLanguage) ...<Widget>[
            _LanguageSection(controller: controller, user: user),
            const SizedBox(height: 20),
          ],
          if (showTheme) _ThemeSection(controller: controller, user: user),
        ];

        final secondarySections = <Widget>[
          if (showSaved) ...<Widget>[
            _SavedContentSection(controller: controller, user: user),
            const SizedBox(height: 20),
          ],
          if (showDownloads) ...<Widget>[
            const _DownloadsSection(),
            const SizedBox(height: 20),
          ],
          if (showAbout) const _AboutSection(),
          if (!anyVisible) noResults,
        ];

        return Padding(
          padding: layout.pagePadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: layout.splitPrimaryFlex,
                child: ListView(children: primarySections),
              ),
              SizedBox(width: layout.paneSpacing),
              Expanded(
                flex: layout.splitSecondaryFlex,
                child: ListView(children: secondarySections),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Auth dialog result types
// ---------------------------------------------------------------------------

enum _AccountDialogAction { cancel, submit, forgotPassword }

// Result from the login dialog: holds the entered credentials and the chosen action.
class _LoginDialogResult {
  const _LoginDialogResult({
    required this.action,
    this.email = '',
    this.password = '',
  });

  final _AccountDialogAction action;
  final String email;
  final String password;
}

// Result from the register dialog.
class _RegisterDialogResult {
  const _RegisterDialogResult({
    required this.submitted,
    this.name = '',
    this.email = '',
    this.password = '',
  });

  final bool submitted;
  final String name;
  final String email;
  final String password;
}

// ---------------------------------------------------------------------------
// Login dialog — owns its own TextEditingControllers so they are disposed
// after the dialog's exit animation, not before.
// ---------------------------------------------------------------------------

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Login'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const _LoginDialogResult(action: _AccountDialogAction.forgotPassword),
          ),
          child: const Text('Forgot password?'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const _LoginDialogResult(action: _AccountDialogAction.cancel),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _LoginDialogResult(
              action: _AccountDialogAction.submit,
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text,
            ),
          ),
          child: const Text('Login'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Register dialog
// ---------------------------------------------------------------------------

class _RegisterDialog extends StatefulWidget {
  const _RegisterDialog();

  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _passwordVisible = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Register'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 10 characters',
                suffixIcon: IconButton(
                  icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const _RegisterDialogResult(submitted: false),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _RegisterDialogResult(
              submitted: true,
              name: _nameCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text,
            ),
          ),
          child: const Text('Register'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Forgot-password dialog (email entry)
// ---------------------------------------------------------------------------

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});
  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Forgot password'),
      content: SingleChildScrollView(
        child: TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(labelText: 'Account email'),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _emailCtrl.text.trim()),
          child: const Text('Send OTP'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reset-password dialog (OTP + new password)
// ---------------------------------------------------------------------------

class _ResetPasswordDialogResult {
  const _ResetPasswordDialogResult({
    required this.submitted,
    this.otpCode = '',
    this.password = '',
    this.confirmPassword = '',
  });

  final bool submitted;
  final String otpCode;
  final String password;
  final String confirmPassword;
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog();

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmVisible = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _otpCtrl,
              decoration: const InputDecoration(
                labelText: 'Email OTP code',
                helperText: 'Enter the 6-digit code from your email',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'New password',
                helperText: 'At least 10 characters',
                suffixIcon: IconButton(
                  icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                ),
              ),
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _confirmCtrl,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                suffixIcon: IconButton(
                  icon: Icon(_confirmVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _confirmVisible = !_confirmVisible),
                ),
              ),
              obscureText: !_confirmVisible,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const _ResetPasswordDialogResult(submitted: false),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            _ResetPasswordDialogResult(
              submitted: true,
              otpCode: _otpCtrl.text.trim(),
              password: _passwordCtrl.text,
              confirmPassword: _confirmCtrl.text,
            ),
          ),
          child: const Text('Reset'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Account section widget
// ---------------------------------------------------------------------------

class _AccountSection extends StatelessWidget {
  final ProfileController controller;
  final UserModel user;
  final AuthService _authService = AuthService();
  static const int _minimumPasswordLength = 10;

  _AccountSection({required this.controller, required this.user});

  void _showMessage(BuildContext context, String message) {
    showClaySnackBar(context, message, type: ClaySnackType.error);
  }

  bool _validatePassword(BuildContext context, String password) {
    if (password.length >= _minimumPasswordLength) return true;
    _showMessage(
      context,
      'Password must be at least $_minimumPasswordLength characters long',
    );
    return false;
  }

  Future<void> _handleLogin(BuildContext context) async {
    final result = await showDialog<_LoginDialogResult>(
      context: context,
      builder: (_) => const _LoginDialog(),
    );

    if (!context.mounted) return;

    if (result == null || result.action == _AccountDialogAction.cancel) return;

    if (result.action == _AccountDialogAction.forgotPassword) {
      await _handleForgotPassword(context);
      return;
    }

    if (result.email.isEmpty || result.password.isEmpty) {
      _showMessage(context, 'Email and password are required');
      return;
    }

    try {
      await _authService.login(result.email, result.password);
      if (!context.mounted) return;
      controller.signIn(
        name: result.email.contains('@')
            ? result.email.split('@').first
            : result.email,
        email: result.email,
      );
      showClaySnackBar(context, 'Login successful', type: ClaySnackType.success);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      _showMessage(context, error.message);
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'Login failed');
    }
  }

  Future<void> _handleRegister(BuildContext context) async {
    final result = await showDialog<_RegisterDialogResult>(
      context: context,
      builder: (_) => const _RegisterDialog(),
    );

    if (!context.mounted) return;
    if (result == null || !result.submitted) return;

    if (result.name.isEmpty || result.email.isEmpty || result.password.isEmpty) {
      _showMessage(context, 'Name, email, and password are required');
      return;
    }

    if (!_validatePassword(context, result.password)) return;

    try {
      await _authService.register(result.name, result.email, result.password);
      if (!context.mounted) return;
      showClaySnackBar(context, 'Registration successful. Please log in.', type: ClaySnackType.success);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      _showMessage(context, error.message);
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'Registration failed');
    }
  }

  Future<void> _handleForgotPassword(BuildContext context) async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(initialEmail: user.email ?? ''),
    );

    if (!context.mounted || email == null || email.isEmpty) return;

    try {
      final result = await _authService.requestPasswordReset(email);
      if (!context.mounted) return;
      _showMessage(context, result.message);
      await _showResetPasswordDialog(context);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      _showMessage(context, error.message);
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'Password reset request failed');
    }
  }

  Future<void> _showResetPasswordDialog(BuildContext context) async {
    final result = await showDialog<_ResetPasswordDialogResult>(
      context: context,
      builder: (_) => const _ResetPasswordDialog(),
    );

    if (!context.mounted || result == null || !result.submitted) return;

    if (result.otpCode.isEmpty ||
        result.password.isEmpty ||
        result.confirmPassword.isEmpty) {
      _showMessage(
          context, 'OTP code, password, and confirmation are required');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(result.otpCode)) {
      _showMessage(context, 'OTP code must be 6 digits');
      return;
    }

    if (!_validatePassword(context, result.password)) return;

    if (result.password != result.confirmPassword) {
      _showMessage(context, 'Passwords do not match');
      return;
    }

    try {
      await _authService.resetPassword(
        otpCode: result.otpCode,
        password: result.password,
        confirmPassword: result.confirmPassword,
      );
      if (!context.mounted) return;
      _showMessage(context, 'Password reset successful. Please login.');
    } on ApiException catch (error) {
      if (!context.mounted) return;
      _showMessage(context, error.message);
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'Password reset failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2822) : const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        boxShadow: clayShadows(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            if (user.authStatus == AuthStatus.guest) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Login'),
                onPressed: () => _handleLogin(context),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Register'),
                onPressed: () => _handleRegister(context),
              ),
              TextButton.icon(
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Forgot password?'),
                onPressed: () => _handleForgotPassword(context),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Continue as Guest'),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_circle, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name ?? '',
                            style: const TextStyle(fontSize: 16)),
                        Text(
                          user.email ?? '',
                          style: const TextStyle(color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  controller.signOut();
                },
                child: const Text('Logout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanguageSection extends StatelessWidget {
  final ProfileController controller;
  final UserModel user;
  const _LanguageSection({required this.controller, required this.user});

  static const Set<String> _musicCodes = <String>{
    'te', 'hi', 'ta', 'ml', 'kn', 'mr', 'as', 'br',
    'en', 'kok', 'mni', 'or', 'pa', 'bn', 'ne', 'doi', 'ks', 'gu', 'sd',
  };

  @override
  Widget build(BuildContext context) {
    final supportedCodes = supportedLanguages.map((item) => item.code).toSet();
    final selectedBibleLanguage = supportedCodes.contains(user.bibleLanguage)
        ? user.bibleLanguage
        : supportedLanguages.first.code;

    final musicLanguages = supportedLanguages
        .where((l) => _musicCodes.contains(l.code))
        .toList(growable: false);
    final musicCodes = musicLanguages.map((l) => l.code).toSet();
    final selectedSongsLanguage = musicCodes.contains(user.songsLanguage)
        ? user.songsLanguage
        : (musicLanguages.isNotEmpty ? musicLanguages.first.code : 'te');

    final bibleLanguageItems = supportedLanguages
        .map(
          (language) => DropdownMenuItem<String>(
            value: language.code,
            child: Text(language.label),
          ),
        )
        .toList();

    final musicLanguageItems = musicLanguages
        .map(
          (language) => DropdownMenuItem<String>(
            value: language.code,
            child: Text(language.label),
          ),
        )
        .toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2822) : const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        boxShadow: clayShadows(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Language Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            _SettingsDropdownRow(
              label: 'Bible Language',
              value: selectedBibleLanguage,
              items: bibleLanguageItems,
              onChanged: (String? val) {
                if (val != null) controller.setBibleLanguage(val);
              },
            ),
            const SizedBox(height: 12),
            _SettingsDropdownRow(
              label: 'Music Language',
              value: selectedSongsLanguage,
              items: musicLanguageItems,
              onChanged: (String? val) {
                if (val != null) controller.setSongsLanguage(val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDropdownRow extends StatelessWidget {
  const _SettingsDropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: DropdownButtonFormField<String>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: UnderlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeSection extends StatelessWidget {
  final ProfileController controller;
  final UserModel user;
  const _ThemeSection({required this.controller, required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2822) : const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        boxShadow: clayShadows(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Appearance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Column(
              children: [
                ListTile(
                  title: const Text('Light'),
                  leading: Icon(
                    user.theme == AppTheme.light
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () => controller.setTheme(AppTheme.light),
                ),
                ListTile(
                  title: const Text('Dark'),
                  leading: Icon(
                    user.theme == AppTheme.dark
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () => controller.setTheme(AppTheme.dark),
                ),
                ListTile(
                  title: const Text('System'),
                  leading: Icon(
                    user.theme == AppTheme.system
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () => controller.setTheme(AppTheme.system),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedContentSection extends StatelessWidget {
  final ProfileController controller;
  final UserModel user;
  const _SavedContentSection({required this.controller, required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2822) : const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        boxShadow: clayShadows(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saved Content',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('Bookmarked Verses'),
              subtitle: Text('${user.savedVerses.length} saved'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookmarkedVersesPage(),
                  ),
                );
              },
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Favorite Music'),
              subtitle: Text('${user.favoriteSongs.length} saved'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FavoriteMusicPage(),
                  ),
                );
              },
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadsSection extends StatelessWidget {
  const _DownloadsSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2822) : const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        boxShadow: clayShadows(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Downloads',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Bible'),
              subtitle: const Text(
                  'Download Bible text and audio for offline use'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DownloadsManagerPage(),
                  ),
                );
              },
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2822) : const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        boxShadow: clayShadows(isDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('About & App Info',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('App Version')),
                FutureBuilder<String>(
                  future: _getAppVersion(),
                  builder: (context, snapshot) {
                    return Text(snapshot.data ?? '...');
                  },
                ),
              ],
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Privacy Policy'),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Contact: support@email.com'),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Rate App'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getAppVersion() async {
    return '1.1.0';
  }
}
