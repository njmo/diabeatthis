import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CallableIdentity {
  const CallableIdentity(this.uid, this.idToken, this.appCheckToken);
  final String uid;
  final String idToken;
  final String appCheckToken;
}

class CallableFailure implements Exception {
  const CallableFailure(this.code, {this.rejectionCode, this.rejectionReason});
  final String code;

  /// Whitelisted definitive server refusal; absent for ambiguous transport errors.
  final String? rejectionCode;
  final String? rejectionReason;
}

/// Authenticated calls never accept an identity, family or recipient override.
class AuthenticatedCallableTransport {
  const AuthenticatedCallableTransport({
    required this.client,
    required this.projectId,
    required this.identity,
    required this.currentUid,
  });
  final http.Client client;
  final String projectId;
  final Future<CallableIdentity> Function() identity;
  final String? Function() currentUid;
  static const functions = {
    'getFamilyChatConfig',
    'configureFamilyChat',
    'clearFamilyChatHistory',
    'reserveFamilyChatOperations',
    'sendFamilyChatMessage',
    'fetchFamilyChatMessages',
    'fetchFamilyChatConversations',
    'acknowledgeFamilyChatMessage',
    'acknowledgeFamilyChatMessages',
    'fetchFamilyChatMessageStates',
    'fetchFamilyChatShortcuts',
    'saveFamilyChatShortcuts',
    'orderFamilyChatShortcuts',
    'registerFamilyChatNotifications',
    'claimFamilyChatTreatment',
    'completeFamilyChatTreatment',
    'mealDecision',
    'registerMealDecisionNotifications',
    'claimFamilyPlan',
    'submitFamilyPlan',
    'fetchFamilyPlans',
    'acknowledgeFamilyPlan',
    'registerFamilyMirror',
    'publishFamilyMirror',
    'fetchFamilyMirror',
    'fetchFamilyMirrorView',
    'fetchFamilyMealHeaders',
    'completeFamilyMealHeaderExport',
    'fetchFamilyMealProgress',
    'searchFamilyMirrorIngredients',
    'createFamilyInvite',
    'requestFamilyJoin',
    'requestFamilyJoinByCode',
    'decideFamilyJoin',
    'getFamilyStatus',
    'disconnectFamilyMember',
    'finalizeFamilySetup',
  };
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, Object?> data, {
    String? expectedUid,
    Future<bool> Function()? allowRequest,
  }) async {
    if (!functions.contains(function)) {
      throw const CallableFailure('invalid-argument');
    }
    final initiatingUid = expectedUid ?? currentUid();
    if (initiatingUid == null) throw const CallableFailure('unauthenticated');
    final trace =
        kDebugMode &&
        const {
          'mealDecision',
          'fetchFamilyMirror',
          'fetchFamilyMirrorView',
          'fetchFamilyMealHeaders',
          'fetchFamilyPlans',
        }.contains(function);
    final timing = trace ? (Stopwatch()..start()) : null;
    final operation = function == 'mealDecision' ? data['action'] : function;
    try {
      final account = await identity().timeout(const Duration(seconds: 15));
      if (timing != null) {
        debugPrint(
          'MealDecisionTiming callable.$operation.identity ms=${timing.elapsedMilliseconds}',
        );
      }
      if (account.uid != initiatingUid ||
          account.uid != currentUid() ||
          account.idToken.isEmpty ||
          account.appCheckToken.isEmpty ||
          projectId.isEmpty) {
        throw const CallableFailure('unauthenticated');
      }
      if (allowRequest != null && !await allowRequest()) {
        throw const CallableFailure('cancelled');
      }
      if (currentUid() != initiatingUid) {
        throw const CallableFailure('unauthenticated');
      }
      timing?.reset();
      final response = await client
          .post(
            Uri.https(
              'europe-west1-$projectId.cloudfunctions.net',
              '/$function',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${account.idToken}',
              'X-Firebase-AppCheck': account.appCheckToken,
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 20));
      if (timing != null) {
        debugPrint(
          'MealDecisionTiming callable.$operation.http ms=${timing.elapsedMilliseconds} status=${response.statusCode}',
        );
      }
      if (account.uid != currentUid()) {
        throw const CallableFailure('unauthenticated');
      }
      if (const {
            'fetchFamilyMirrorView',
            'fetchFamilyMealHeaders',
            'fetchFamilyMealProgress',
          }.contains(function) &&
          response.statusCode == 404 &&
          !(response.headers['content-type'] ?? '').contains(
            'application/json',
          )) {
        throw const CallableFailure('endpoint-not-deployed');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['error'] != null) {
        const rejections = {
          'INVALID_ARGUMENT': 'invalid-argument',
          'UNAUTHENTICATED': 'unauthenticated',
          'PERMISSION_DENIED': 'permission-denied',
          'FAILED_PRECONDITION': 'failed-precondition',
          'ALREADY_EXISTS': 'already-exists',
          'NOT_FOUND': 'not-found',
        };
        final error = body['error'];
        final rejection =
            response.statusCode >= 400 &&
                response.statusCode < 500 &&
                error is Map
            ? rejections[error['status']]
            : null;
        if (function == 'mealDecision' &&
            operation == 'create' &&
            response.statusCode == 400 &&
            rejection == 'invalid-argument' &&
            data.containsKey('advisorSuggestion')) {
          final legacyData = Map<String, Object?>.of(data)
            ..remove('advisorSuggestion');
          return await call(
            function,
            legacyData,
            expectedUid: initiatingUid,
            allowRequest: allowRequest,
          );
        }
        final details = error is Map ? error['details'] : null;
        final reason = details is Map ? details['reason'] : null;
        final consumptionReason =
            function == 'claimFamilyChatTreatment' &&
                response.statusCode == 404 &&
                rejection == 'not-found' &&
                const {
                  'consumption-request-expired',
                  'consumption-request-unavailable',
                }.contains(reason)
            ? reason as String
            : null;
        final safeReason =
            consumptionReason ??
            (function == 'sendFamilyChatMessage' &&
                    response.statusCode == 400 &&
                    rejection == 'failed-precondition' &&
                    reason == 'chat-send-outcome-unknown'
                ? reason as String
                : null);
        throw CallableFailure(
          'unavailable',
          rejectionCode: rejection,
          rejectionReason: safeReason,
        );
      }
      return Map<String, dynamic>.from(body['result'] as Map);
    } on CallableFailure {
      rethrow;
    } catch (_) {
      throw const CallableFailure('unavailable');
    }
  }
}
