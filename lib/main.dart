import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return const CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: NearbyParksScreen(isCupertino: true),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const NearbyParksScreen(isCupertino: false),
    );
  }
}

class NearbyParksScreen extends StatelessWidget {
  final bool isCupertino;
  const NearbyParksScreen({super.key, required this.isCupertino});

  @override
  Widget build(BuildContext context) {
    final title = const Text('ParkPal');

    if (isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: title),
        child: const SafeArea(child: NearbyParksBody()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: title),
      body: const NearbyParksBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.bookmark),
      ),
    );
  }
}

class NearbyParksBody extends StatelessWidget {
  const NearbyParksBody({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: "Search parks…",
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: ListTile(
            title: Text("Example Park"),
            subtitle: Text("1.2 km away"),
            trailing: Icon(Icons.chevron_right),
          ),
        ),
      ],
    );
  }
}
