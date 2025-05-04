import 'package:flutter/material.dart';
import 'package:futurities/futurities.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: DelayedFutureProvider(
        create: getMessage,
        initialValue: "Not started yet...",
        loadingValue: "Wisdom loading...",
        child: MyHomePage(title: 'Flutter Demo Home Page'),
      ),
    );
  }

  static int _counter = 1;
  static Future<String> getMessage(BuildContext context) async {
    print("fetching message ${_counter++}...");
    await Future.delayed(Duration(seconds: 2));
    return Future.value(
      "Read 'How Do We Relationship' at least $_counter times!",
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            DelayedFutureBuilder(
              future: context.watch<DelayedFuture<String>>(),
              onNone:
                  (_) => Text(
                    "Click the floating button for some wisdom!",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
              onWaiting: (_) => CircularProgressIndicator(),
              onDone:
                  (_, message) => Text(
                    message,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
            ),
            Text("Live state: ${context.watch<DelayedFuture<String>>().state}"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () => context.read<DelayedFuture<String>>().start(
              context,
              allowRestarts: true,
            ),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
