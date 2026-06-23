import 'package:flutter/material.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

import 'screens/farmer_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.isLive) await Backend.initialize();
  runApp(const FarmerApp());
}

class FarmerApp extends StatefulWidget {
  const FarmerApp({super.key});

  @override
  State<FarmerApp> createState() => _FarmerAppState();
}

class _FarmerAppState extends State<FarmerApp> {
  final AppStore _store = AppStore(role: Role.farmer);

  @override
  void initState() {
    super.initState();
    _store.bootstrap();
    if (AppConfig.isLive) {
      Backend.I.authChanges.listen((_) => _store.bootstrap());
    }
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: _store,
      child: MaterialApp(
        title: 'OpenMandi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const AuthGate(child: FarmerShell()),
      ),
    );
  }
}
