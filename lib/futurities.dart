import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class DelayedFuture<T> with ChangeNotifier {
  final Create<Future<T>> create;

  ConnectionState state;
  late Future<T> future;

  T? data;

  bool get isSleeping => state == ConnectionState.none;
  bool get isWaiting => state == ConnectionState.waiting;
  bool get isDone => state == ConnectionState.done;

  DelayedFuture({required this.create}) : state = ConnectionState.none;

  DelayedFuture.started({required Future<T> value})
    : state = ConnectionState.waiting,
      future = value,
      create = ((_) => value);

  DelayedFuture.done({required T value})
    : state = ConnectionState.done,
      future = Future.value(value),
      create = ((_) => Future.value(value));

  void start(BuildContext context, {bool allowRestarts = false}) {
    // if an operation has already been started, don't restart again (it could corrupt us)
    if (isWaiting) return;

    // if we don't support restarts, then exit if we're already done
    if (!allowRestarts && isDone) return;

    // 1. Create (and thus start) the future
    // 2. Update the state and notify our listeners without awaiting the future
    // 3. Attach a completion callback to the future
    // 4. ???
    // 5. When the future is done, it'll call [_onFutureDone], and update the state
    //    back to done (as well as notify the listeners)

    // The reason we do things in this weird/convoluted order is basically
    // to avoid data races, in two ways:
    //
    // (1) assign `future` before [notifyListeners], so that listeners can do whatever
    //     they want with the future (e.g. await it, add callbacks, etc.)
    future = create(context);
    state = ConnectionState.waiting;
    notifyListeners();

    // (2) only set the completion callback *after* we've set the state to [waiting], so
    //     we don't risk overwriting [done] with [waiting] and end up in that state forever
    //     (yes, some futures can complete before the next line of code, e.g. [SynchronousFuture])
    future = future.then((val) {
      _onFutureDone(val);
      return val;
    });
  }

  void _onFutureDone(T val) {
    data = val;
    state = ConnectionState.done;
    notifyListeners();
  }
}

class DelayedFutureProvider<T> extends SingleChildStatelessWidget {
  final Create<Future<T>> create;
  final T initialValue;
  final T? loadingValue;

  final T Function(BuildContext, Object?)? catchError;

  // widget builder function/callback for a SingleChildWidget
  final TransitionBuilder? builder;

  const DelayedFutureProvider({
    super.key,
    required this.create,
    required this.initialValue,
    this.loadingValue,
    this.catchError,
    this.builder,
    super.child,
  });

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return ChangeNotifierProvider(
      // using [create] instead of [.value] fixes hot reload somehow??
      // man i really don't understand this stuff ;-;
      create: (_) => DelayedFuture(create: create),
      child: child,
      builder: (context, child) {
        var delayedFuture = context.watch<DelayedFuture<T>>();
        if (delayedFuture.isSleeping) {
          // if it hasn't started yet, just send the initial value
          return Provider.value(
            value: initialValue,
            builder: builder,
            child: child,
          );
        } else {
          // if we've already started, delegate the rest of the responsibility to FutureProvider
          return FutureProvider.value(
            value: delayedFuture.future,
            initialData: loadingValue ?? initialValue,
            catchError: catchError,
            builder: builder,
            child: child,
          );
        }
      },
    );
  }
}

class DelayedFutureBuilder<T> extends StatelessWidget {
  final DelayedFuture<T> future;

  final WidgetBuilder onNone, onWaiting;
  final Widget Function(BuildContext, T) onDone;

  const DelayedFutureBuilder({
    super.key,
    required this.future,
    required this.onNone,
    required this.onWaiting,
    required this.onDone,
  });

  DelayedFutureBuilder.builder({
    super.key,
    required this.future,
    required AsyncWidgetBuilder<T> builder,
  }) : onNone = ((ctx) => builder(ctx, AsyncSnapshot.nothing())),
       onWaiting = ((ctx) => builder(ctx, AsyncSnapshot.waiting())),
       onDone =
           ((ctx, data) => builder(
             ctx,
             AsyncSnapshot.withData(ConnectionState.done, data),
           ));

  @override
  Widget build(BuildContext context) {
    return switch (future.state) {
      ConnectionState.none => onNone(context),
      ConnectionState.waiting => onWaiting(context),
      ConnectionState.done => onDone(context, future.data as T),
      _ =>
        throw UnimplementedError("How did we get a ${future.state} state???"),
    };
  }
}
