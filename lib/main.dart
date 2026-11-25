import 'package:flutter/material.dart';
import 'home_page.dart';
import 'widgets.dart';

void main() => runApp(const VigiaPampaApp());

class VigiaPampaApp extends StatelessWidget {
  const VigiaPampaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VigiaPampa',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: teal,
          scaffoldBackgroundColor: bg,
          fontFamily: 'Roboto',
        ),
        home: const HomePage(),
      );
}
