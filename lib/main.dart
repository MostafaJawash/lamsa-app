import 'package:flutter/material.dart';
import 'package:lamsa_app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deps = AppDependencies.create();
  runApp(LamsaApp(deps: deps));
  // Not awaited: the splash route shows until the session is known.
  await deps.push.init();
  await deps.session.restore();
}
