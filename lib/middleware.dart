import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo_redux/app_state.dart';
import 'package:demo_redux/item.dart';
import 'package:demo_redux/reducer.dart';
import 'package:flutter/foundation.dart';
import 'package:redux/redux.dart';
import 'package:redux_epics/redux_epics.dart';
import 'package:rxdart/rxdart.dart';

List<Middleware<AppState>> createMiddleWares() {
  return [
    new EpicMiddleware(_epic),
    new TypedMiddleware((Store<AppState> store, action, NextDispatcher next) {
      debugPrint(action.runtimeType.toString());
      next(action);
    }),
  ];
}

final Epic<AppState> _epic = combineEpics(
  <Epic<AppState>>[
    _itemsEpic,
    _addItemEpic,
    _editItemEpic,
    _removeItemEpic,
  ],
);

Stream<dynamic> _itemsEpic(Stream<dynamic> actions, EpicStore<AppState> store) {
  final changeOrder = Observable(actions).ofType(TypeToken<ChangeOrderBy>());
  final request =
      Observable(actions).ofType(TypeToken<RequestItemDataEventAction>());
  final mapper = (changeOrderAction) {
    return _getItemStreamsFromFirestore(changeOrderAction.orderBy)
        .map((items) => new OnListChangedAction(items))
        .takeUntil(
            actions.where((action) => action is CancelItemDataEventAction));
  };
  return Observable
      .combineLatest2<RequestItemDataEventAction, ChangeOrderBy, ChangeOrderBy>(
        request,
        changeOrder,
        (_, changeOrderAction) => changeOrderAction,
      )
      .switchMap(mapper);
}

Observable<List<Item>> _getItemStreamsFromFirestore(OrderBy orderBy) {
  Query query = Firestore.instance.collection('items');

  if (orderBy == OrderBy.titleDesc || orderBy == OrderBy.titleAsc) {
    query = query.orderBy('title', descending: orderBy == OrderBy.titleDesc);
  } else if (orderBy == OrderBy.timeDesc || orderBy == OrderBy.timeAsc) {
    query = query.orderBy('time', descending: orderBy == OrderBy.timeDesc);
  }

  debugPrint('Order: $orderBy');

  return new Observable(query.snapshots()).map<List<Item>>((querySnapshot) {
    return querySnapshot.documents.map((docSnapshot) {
      return Item(
        id: docSnapshot.documentID,
        title: docSnapshot['title'],
        content: docSnapshot['content'],
        time: docSnapshot['time'],
      );
    }).toList();
  });
}

Stream<dynamic> _addItemEpic(
    Stream<dynamic> actions, EpicStore<AppState> store) {
  return new Observable(actions)
      .ofType(TypeToken<AddItemAction>())
      .flatMap((addItemAction) {
    final add = Firestore.instance
        .collection('items')
        .add(addItemAction.item.toJson())
        .then((_) => addItemAction.onValue())
        .catchError(addItemAction.onError);
    return new Observable.fromFuture(add);
  });
}

Stream<dynamic> _editItemEpic(
    Stream<dynamic> actions, EpicStore<AppState> store) {
  return new Observable(actions)
      .ofType(TypeToken<EditItemAction>())
      .flatMap((editItemAction) {
    final add = Firestore.instance
        .collection('items')
        .document(editItemAction.item.id)
        .setData(editItemAction.item.toJson())
        .then((_) => editItemAction.onValue())
        .catchError(editItemAction.onError);
    return new Observable.fromFuture(add);
  });
}

Stream<dynamic> _removeItemEpic(
    Stream<dynamic> actions, EpicStore<AppState> store) {
  return new Observable(actions)
      .ofType(TypeToken<RemoveItemAction>())
      .flatMap((removeItemAction) {
    final add = Firestore.instance
        .collection('items')
        .document(removeItemAction.item.id)
        .delete()
        .then((_) => removeItemAction.onValue())
        .catchError(removeItemAction.onError);
    return new Observable.fromFuture(add);
  });
}
