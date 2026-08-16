import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/app_user.dart';
import '../auth/login_page.dart';
import '../screens/shell/dashboard_shell.dart';
import 'theme.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  static const _kSessionEmail = 'session_email';

  AppUser? _user;
  var _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_kSessionEmail);

    if (!mounted) return;

    if (email != null && email.isNotEmpty) {
      setState(() {
        _user = AppUser(email: email);
        _restoring = false;
      });
      return;
    }

    setState(() => _restoring = false);
  }

  Future<void> _saveSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionEmail, user.email);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionEmail);
  }

  @override
  Widget build(BuildContext context) {
    final home = _restoring
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : (_user == null
            ? LoginPage(
                onSignedIn: (u) async {
                  await _saveSession(u);
                  if (!mounted) return;
                  setState(() => _user = u);
                },
              )
            : DashboardShell(
                user: _user!,
                onLogout: () async {
                  await _clearSession();
                  if (!mounted) return;
                  setState(() => _user = null);
                },
              ));

    return MaterialApp(
      title: 'BDS School Management',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: home,
    );
  }
}
