import 'dart:async';

/// A failed Firestore stream is terminal; a later connect must subscribe again.
class FamilyPlanSignalListener {
  StreamSubscription<void>? subscription;
  String? uid;
  int generation = 0;
  bool disposed = false;
  Future<void> connect(
    String account,
    Stream<void> events, {
    required void Function() onChange,
    required void Function() onFailure,
  }) async {
    if (disposed || uid == account && subscription != null) return;
    final epoch = generation + 1;
    await disconnect();
    if (disposed || generation != epoch) return;
    uid = account;
    final version = generation;
    void failed() {
      if (disposed || version != generation) return;
      generation++;
      uid = null;
      unawaited(subscription?.cancel());
      subscription = null;
      onFailure();
    }

    subscription = events.listen(
      (_) {
        if (!disposed && version == generation) onChange();
      },
      onError: (Object error) => failed(),
      onDone: failed,
    );
  }

  Future<void> disconnect() async {
    generation++;
    uid = null;
    final old = subscription;
    subscription = null;
    await old?.cancel();
  }

  void dispose() {
    disposed = true;
    unawaited(disconnect());
  }
}
