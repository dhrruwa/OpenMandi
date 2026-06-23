import 'package:flutter/material.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.isLive) await Backend.initialize();
  runApp(const DealerApp());
}

class DealerApp extends StatefulWidget {
  const DealerApp({super.key});

  @override
  State<DealerApp> createState() => _DealerAppState();
}

class _DealerAppState extends State<DealerApp> {
  final AppStore _store = AppStore(role: Role.dealer);

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
        title: 'OpenMandi Dealer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const AuthGate(child: DealerHomeShell()),
      ),
    );
  }
}
