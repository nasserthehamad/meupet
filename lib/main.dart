import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/db.dart';
import 'core/models.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/provider/provider_shell.dart';
import 'screens/tutor/tutor_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // O app é sempre em retrato (como o protótipo), inclusive no BlueStacks.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MeuPetApp());
}

class MeuPetApp extends StatelessWidget {
  const MeuPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu Pet+',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const SplashView();
        final user = snap.data;
        if (user == null) {
          Session.current.value = null;
          return const LoginScreen();
        }
        return StreamBuilder<AppUser>(
          stream: Db.userStream(user.uid),
          builder: (context, us) {
            if (!us.hasData) return const SplashView();
            final u = us.data!;
            // O documento pode ainda não existir logo após o cadastro.
            if (u.email.isEmpty && u.name.isEmpty) return const SplashView();
            Session.current.value = u;
            return u.isProvider ? ProviderShell(key: ValueKey('p${u.id}')) : TutorShell(key: ValueKey('t${u.id}'));
          },
        );
      },
    );
  }
}

class SplashView extends StatelessWidget {
  const SplashView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/logo.png', width: 140),
          const SizedBox(height: 16),
          const Text('Um lugar onde o cuidado e o amor\npela vida andam juntos!',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ]),
      ),
    );
  }
}
