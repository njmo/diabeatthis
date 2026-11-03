import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/nightscout/nightscout_storage_keys.dart';
import '../../../../core/data_sources/nightscout/treatments/nightscout_carbohydrate_writer.dart';
import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../application/nightscout_low_treatment_settings.dart';
import '../../application/process_low_treatment_uploads_use_case.dart';
import '../../application/register_low_treatment_upload_use_case.dart';
import '../../application/resolve_low_treatment_upload_status_use_case.dart';
import '../repositories/low_treatment_upload_repository.dart';
import 'recorded_low_treatment_repository_provider.dart';

final nightscoutLowTreatmentSettingsLoaderProvider =
    Provider<Future<NightscoutLowTreatmentSettings> Function()>(
      (ref) => () async {
        if (kIsWeb || !Platform.isAndroid) {
          return const NightscoutLowTreatmentSettings();
        }
        final prefs = await ref.read(sharedPrefsProvider.future);
        await prefs.reload();
        return NightscoutLowTreatmentSettings(
          enabled: prefs.getBool(nightscoutLowTreatmentsEnabledKey) ?? false,
          revision: prefs.getString(nightscoutDeliveryRevisionKey) ?? '',
          url: prefs.getString(nightscoutUrlKey) ?? '',
          token: prefs.getString(nightscoutTokenKey) ?? '',
        );
      },
    );

final lowTreatmentUploadRepositoryProvider =
    Provider<LowTreatmentUploadRepository>(
      (ref) => LowTreatmentUploadRepository(ref.watch(databaseProvider)),
    );

final registerLowTreatmentUploadUseCaseProvider =
    Provider<RegisterLowTreatmentUploadUseCase>(
      (ref) => RegisterLowTreatmentUploadUseCase(
        repository: ref.watch(lowTreatmentUploadRepositoryProvider),
        loadSettings: ref.watch(nightscoutLowTreatmentSettingsLoaderProvider),
        loadRecorded: ref
            .watch(recordedLowTreatmentRepositoryProvider)
            .fetchByMealId,
      ),
    );

final processLowTreatmentUploadsUseCaseProvider =
    Provider<ProcessLowTreatmentUploadsUseCase>(
      (ref) => ProcessLowTreatmentUploadsUseCase(
        repository: ref.watch(lowTreatmentUploadRepositoryProvider),
        writer: NightscoutCarbohydrateWriter(),
        loadSettings: ref.watch(nightscoutLowTreatmentSettingsLoaderProvider),
        loadRecorded: ref
            .watch(recordedLowTreatmentRepositoryProvider)
            .fetchByMealId,
      ),
    );

final lowTreatmentUploadStatusProvider = StreamProvider.autoDispose
    .family<LowTreatmentUploadData?, int>(
      (ref, mealId) => kIsWeb || !Platform.isAndroid
          ? Stream.value(null)
          : ref.watch(lowTreatmentUploadRepositoryProvider).watch(mealId),
    );

final lowTreatmentUploadDisplayStatusProvider = Provider.autoDispose
    .family<AsyncValue<LowTreatmentUploadDisplayStatus?>, int>((ref, mealId) {
      final prefs = ref.watch(sharedPrefsProvider).asData?.value;
      final settings = prefs == null
          ? null
          : NightscoutLowTreatmentSettings(
              enabled:
                  prefs.getBool(nightscoutLowTreatmentsEnabledKey) ?? false,
              url: prefs.getString(nightscoutUrlKey) ?? '',
              revision: prefs.getString(nightscoutDeliveryRevisionKey) ?? '',
            );
      return ref
          .watch(lowTreatmentUploadStatusProvider(mealId))
          .whenData(
            (upload) => upload == null
                ? null
                : const ResolveLowTreatmentUploadStatusUseCase()(
                    state: upload.state,
                    sourceKey: upload.sourceKey,
                    settings: settings,
                  ),
          );
    });
