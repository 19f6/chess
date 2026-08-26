import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'main_menu_screen.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _controller = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = context.read<UserProvider>().username;
    if (existing != null) {
      _controller.text = existing;
      SchedulerBinding.instance.addPostFrameCallback((_) => _continue());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a display name');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });

    final reachable = await ApiService.isServerReachable();
    if (!reachable) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = 'Cannot reach server at ${AppConfig.serverUrl}';
      });
      return;
    }

    try {
      await SocketService.instance.open();
      final res = await SocketService.instance.emitAck('identify', {'username': name});
      if (res['ok'] != true) {
        if (!mounted) return;
        setState(() {
          _connecting = false;
          _error = res['error']?.toString() ?? 'Could not join';
        });
        return;
      }
      if (!mounted) return;
      await context.read<UserProvider>().setUsername(name);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainMenuScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = 'Connection failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('♞', style: TextStyle(fontSize: 52, color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chess',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Play online against friends, or take on the bot.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _controller,
                    textAlign: TextAlign.center,
                    enabled: !_connecting,
                    decoration: const InputDecoration(labelText: 'Display name'),
                    onSubmitted: (_) => _continue(),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _connecting ? null : _continue,
                      child: _connecting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
