import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class DelayedFuture<T> with ChangeNotifier {
  Create<Future<T>> create;

  ConnectionState state;
  Future<T>? future;

  T? data;

  bool get isSleeping => state == ConnectionState.none;
  bool get isWaiting => state == ConnectionState.waiting;
  bool get isDone => state == ConnectionState.done;

  DelayedFuture({required this.create}) : state = ConnectionState.none;

  DelayedFuture.started({required Future<T> value})
    : state = ConnectionState.waiting,
      future = value,
      create = ((_) => value);

  DelayedFuture.done({required FutureOr<T> value})
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
    future = future!.then((val) {
      _onFutureDone(val);
      return val;
    });
  }

  void _onFutureDone(T val) {
    data = val;
    state = ConnectionState.done;
    notifyListeners();
  }

  @override
  void dispose() {
    // make sure we don't emit any error after this has been disposed
    future?.ignore();
    super.dispose();
  }
}

class DelayedFutureProvider<T> extends SingleChildStatefulWidget {
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
  State<DelayedFutureProvider<T>> createState() =>
      _DelayedFutureProviderState<T>();
}

class _DelayedFutureProviderState<T>
    extends SingleChildState<DelayedFutureProvider<T>> {
  late DelayedFuture<T> future;

  @override
  void initState() {
    future = DelayedFuture(create: widget.create);
    super.initState();
  }

  @override
  void didUpdateWidget(DelayedFutureProvider<T> oldWidget) {
    // replace the DelayedFuture's [create], so that when (re)started
    // it will use the correct one (and not just the one from the first
    // construction, as was assigned in `initState`)
    //
    // note: yes, mutation is ugly; but unfortunately, in this case, we
    //       can't just create a new copy and then mutate the [create]
    //       method: if the DelayedFuture has already been started, the
    //       completion callback would be called on the "old" future,
    //       not the new/mutated one that we'd be using. this would, in
    //       turn, prevent the new DelayedFuture's from updating and
    //       notifying its listeners, including the UI (through both the
    //       [ChangeNotifierProvider] and the [FutureProvider])
    future.create = widget.create;
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget buildWithChild(BuildContext context, Widget? child) {
    return ChangeNotifierProvider.value(
      value: future,
      child: child,
      builder: (context, child) {
        var delayedFuture = context.watch<DelayedFuture<T>>();
        if (delayedFuture.isSleeping) {
          // if it hasn't started yet, just send the initial value
          return Provider.value(
            value: widget.initialValue,
            builder: widget.builder,
            child: child,
          );
        } else {
          // if we've already started, delegate the rest of the responsibility to FutureProvider
          return FutureProvider.value(
            value: delayedFuture.future,
            initialData: widget.loadingValue ?? widget.initialValue,
            builder: widget.builder,
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
  final Widget Function(BuildContext context, T data) onDone;

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
