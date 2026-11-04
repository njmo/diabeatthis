import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ingredient_catalog_exception.dart';
import 'ingredient_search_item.dart';
import 'ingredient_search_normalizer.dart';
import 'unified_ingredient_search_use_case.dart';

class IngredientSearchState {
  IngredientSearchState({
    this.query = '',
    this.languageCode = 'en',
    List<IngredientSearchItem> local = const [],
    List<IngredientSearchItem> remote = const [],
    this.loadingLocal = false,
    this.loadingRemote = false,
    this.nextCursor,
    this.remoteFailure,
    this.localFailed = false,
  }) : local = List.unmodifiable(local),
       remote = List.unmodifiable(remote);
  final String query;
  final String languageCode;
  final List<IngredientSearchItem> local;
  final List<IngredientSearchItem> remote;
  final bool loadingLocal;
  final bool loadingRemote;
  final bool localFailed;
  final String? nextCursor;
  final IngredientCatalogFailure? remoteFailure;
  List<IngredientSearchItem> get items =>
      UnifiedIngredientSearchUseCase.merge(local, remote);
}

class IngredientSearchController extends ChangeNotifier {
  IngredientSearchController(
    this.useCase, {
    this.debounce = const Duration(milliseconds: 300),
  });
  final UnifiedIngredientSearchUseCase useCase;
  final Duration debounce;
  IngredientSearchState state = IngredientSearchState();
  Timer? timer;
  int generation = 0;
  bool closed = false;

  void search(String query, {required String languageCode}) {
    final request = ++generation;
    timer?.cancel();
    state = IngredientSearchState(
      query: query,
      languageCode: languageCode,
      loadingLocal: true,
    );
    notifyListeners();
    unawaited(loadLocal(request, query));
    if (normalizeIngredientSearch(query).length >= 2) {
      timer = Timer(debounce, () => unawaited(loadRemote(request)));
    }
  }

  Future<void> loadLocal(int request, String query) async {
    try {
      final items = await useCase.searchLocal(query);
      if (!active(request)) return;
      update(local: items, loadingLocal: false);
    } catch (_) {
      if (active(request)) update(loadingLocal: false, localFailed: true);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingRemote || state.nextCursor == null) return;
    await loadRemote(generation, cursor: state.nextCursor);
  }

  Future<void> loadRemote(int request, {String? cursor}) async {
    if (!active(request)) return;
    final query = state.query;
    final language = state.languageCode;
    update(loadingRemote: true, clearFailure: true);
    try {
      final page = await useCase.searchCatalog(query, language, cursor: cursor);
      if (!active(request)) return;
      update(
        remote: cursor == null ? page.items : [...state.remote, ...page.items],
        loadingRemote: false,
        cursor: page.nextCursor,
        replaceCursor: true,
      );
    } on IngredientCatalogException catch (error) {
      if (!active(request)) return;
      update(
        loadingRemote: false,
        failure: error.failure,
        replaceCursor: error.failure == IngredientCatalogFailure.staleCursor,
      );
    } catch (_) {
      if (active(request)) {
        update(
          loadingRemote: false,
          failure: IngredientCatalogFailure.unavailable,
        );
      }
    }
  }

  bool active(int request) => !closed && request == generation;
  void update({
    List<IngredientSearchItem>? local,
    List<IngredientSearchItem>? remote,
    bool? loadingLocal,
    bool? loadingRemote,
    bool? localFailed,
    String? cursor,
    bool replaceCursor = false,
    IngredientCatalogFailure? failure,
    bool clearFailure = false,
  }) {
    state = IngredientSearchState(
      query: state.query,
      languageCode: state.languageCode,
      local: local ?? state.local,
      remote: remote ?? state.remote,
      loadingLocal: loadingLocal ?? state.loadingLocal,
      loadingRemote: loadingRemote ?? state.loadingRemote,
      localFailed: localFailed ?? state.localFailed,
      nextCursor: replaceCursor ? cursor : state.nextCursor,
      remoteFailure: clearFailure ? null : failure ?? state.remoteFailure,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    closed = true;
    generation++;
    timer?.cancel();
    super.dispose();
  }
}
