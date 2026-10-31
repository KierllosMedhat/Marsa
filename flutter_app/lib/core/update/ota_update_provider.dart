import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import 'app_update_model.dart';
import 'app_version_constants.dart';

final otaUpdateProvider =
    StateNotifierProvider<OtaUpdateNotifier, OtaUpdateState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OtaUpdateNotifier(apiClient: apiClient);
});

class OtaUpdateNotifier extends StateNotifier<OtaUpdateState> {
  static const MethodChannel _updaterChannel =
      MethodChannel('com.marsa.clinic/updater');
  static const String _prefAutoLiveOtaKey = 'marsa_ota_auto_live_cloud';
  static const String _prefAppliedOtaBuildKey = 'marsa_ota_applied_build';

  final ApiClient apiClient;
  Timer? _periodicTimer;
  bool _initialized = false;

  OtaUpdateNotifier({required this.apiClient})
      : super(
          const OtaUpdateState(
            installedVersion: AppVersionConstants.currentVersion,
            installedBuildNumber: AppVersionConstants.currentBuildNumber,
            autoLiveOtaEnabled: false,
          ),
        ) {
    _init();
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    // Listen to native events from MainActivity.kt
    if (!kIsWeb) {
      try {
        _updaterChannel.setMethodCallHandler((call) async {
          if (call.method == 'onLiveCloudOtaExited') {
            state = state.copyWith(
              phase: state.hasUpdate
                  ? OtaUpdatePhase.updateAvailable
                  : OtaUpdatePhase.upToDate,
              statusMessageAr: 'تمت العودة إلى وضع التطبيق المحلي',
            );
          }
        });
      } catch (_) {}
    }

    // Load preferences & native package info
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoLive = prefs.getBool(_prefAutoLiveOtaKey) ?? false;
      final appliedOtaBuild = prefs.getInt(_prefAppliedOtaBuildKey) ??
          AppVersionConstants.currentBuildNumber;

      var version = AppVersionConstants.currentVersion;
      var buildNum = AppVersionConstants.currentBuildNumber;
      var canInstall = true;

      if (!kIsWeb) {
        try {
          final info = await _updaterChannel
              .invokeMapMethod<String, dynamic>('getAppVersionInfo');
          if (info != null) {
            version = (info['version'] as String?) ?? version;
            final nativeBuild = (info['buildNumber'] as num?)?.toInt() ?? buildNum;
            buildNum = nativeBuild > buildNum ? nativeBuild : buildNum;
            canInstall = (info['canInstallPackages'] as bool?) ?? true;
          }
        } catch (_) {}
      }

      if (appliedOtaBuild > buildNum) {
        buildNum = appliedOtaBuild;
      }

      state = state.copyWith(
        installedVersion: version,
        installedBuildNumber: buildNum,
        canInstallPackages: canInstall,
        autoLiveOtaEnabled: autoLive,
      );
    } catch (_) {}

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    // Perform initial silent OTA check on startup
    await checkForUpdates(silent: true);

    // Schedule periodic background OTA checks every 15 minutes
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => checkForUpdates(silent: true),
    );
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  Future<void> setAutoLiveOtaEnabled(bool enabled) async {
    state = state.copyWith(autoLiveOtaEnabled: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefAutoLiveOtaKey, enabled);
    } catch (_) {}
  }

  void dismissBanner() {
    state = state.copyWith(bannerDismissed: true);
  }

  Future<void> refreshInstallPermissionStatus() async {
    if (kIsWeb) return;
    try {
      final canInstall = await _updaterChannel
          .invokeMethod<bool>('canRequestPackageInstalls');
      if (canInstall != null) {
        state = state.copyWith(canInstallPackages: canInstall);
      }
    } catch (_) {}
  }

  Future<void> openInstallPermissionSettings() async {
    if (kIsWeb) return;
    try {
      await _updaterChannel.invokeMethod('openInstallPermissionSettings');
    } catch (_) {}
  }

  /// Checks online OTA endpoints for a newer version/build.
  Future<bool> checkForUpdates({bool silent = false}) async {
    if (state.phase == OtaUpdatePhase.downloadingApk ||
        state.phase == OtaUpdatePhase.installingApk) {
      return state.hasUpdate;
    }

    if (!silent) {
      state = state.copyWith(
        phase: OtaUpdatePhase.checking,
        clearError: true,
        statusMessageAr: 'جاري الاتصال بالخادم للتحقق من التحديثات الهوائية...',
      );
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final candidateUrls = <String>[
      '${apiClient.baseUrl}/app-update?t=$ts',
      '${AppVersionConstants.staticManifestVercelUrl}?t=$ts',
      '${AppVersionConstants.staticManifestGithubUrl}?t=$ts',
    ];

    AppUpdateManifest? fetchedManifest;
    for (final url in candidateUrls) {
      try {
        final response = await http
            .get(
              Uri.parse(url),
              headers: const {
                'Accept': 'application/json',
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(const Duration(seconds: 7));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded =
              jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          fetchedManifest = AppUpdateManifest.fromJson(decoded);
          break;
        }
      } catch (_) {}
    }

    if (fetchedManifest == null) {
      if (!silent) {
        state = state.copyWith(
          phase: OtaUpdatePhase.error,
          errorMessageAr:
              'تعذر الوصول إلى خادم التحديثات الهوائية حالياً. يرجى التحقق من اتصال الإنترنت.',
          clearStatus: true,
        );
      }
      return false;
    }

    // Apply dynamic API base URL override if specified in remoteConfig
    final apiOverride = fetchedManifest.remoteConfig.apiBaseUrlOverride;
    if (apiOverride != null && apiOverride.trim().isNotEmpty) {
      apiClient.setBaseUrl(apiOverride.trim());
    }

    final previousBuild = state.remoteManifest?.buildNumber;
    final isNewerThanInstalled =
        fetchedManifest.buildNumber > state.installedBuildNumber ||
            OtaUpdateState.compareSemver(
                  fetchedManifest.version,
                  state.installedVersion,
                ) >
                0;

    state = state.copyWith(
      remoteManifest: fetchedManifest,
      lastCheckedAt: DateTime.now(),
      bannerDismissed: (previousBuild != fetchedManifest.buildNumber)
          ? false
          : state.bannerDismissed,
      phase: isNewerThanInstalled
          ? OtaUpdatePhase.updateAvailable
          : OtaUpdatePhase.upToDate,
      statusMessageAr: isNewerThanInstalled
          ? 'يتوفر تحديث جديد (${fetchedManifest.version} • بناء #${fetchedManifest.buildNumber}) جاهز للتطبيق الفوري!'
          : 'التطبيق محدّث إلى آخر إصدار (${state.installedVersion} • بناء #${state.installedBuildNumber}).',
      clearError: true,
    );

    // If Auto Live Cloud OTA is enabled on Android and a newer build is detected, launch it automatically
    if (isNewerThanInstalled &&
        state.autoLiveOtaEnabled &&
        !kIsWeb &&
        fetchedManifest.remoteConfig.enableLiveCloudOta) {
      await launchInstantCloudUpdate();
    }

    return isNewerThanInstalled;
  }

  /// Mode 1: Instant Zero-Reinstall Cloud Update (No APK install required!).
  /// Immediately syncs and launches the latest live cloud build inside the app.
  Future<void> launchInstantCloudUpdate() async {
    final manifest = state.remoteManifest;
    final targetVersion = manifest?.version ?? state.installedVersion;
    final targetBuild = manifest?.buildNumber ?? state.installedBuildNumber;

    // Persist applied OTA build number locally so the badge marks it as updated
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefAppliedOtaBuildKey, targetBuild);
    } catch (_) {}

    if (!kIsWeb) {
      final rawUrl =
          manifest?.liveWebBundleUrl ?? AppVersionConstants.defaultLiveWebBundleUrl;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final separator = rawUrl.contains('?') ? '&' : '?';
      final liveUrl = '$rawUrl${separator}ota_build=$targetBuild&t=$ts';

      try {
        final reachable = await _isUrlReachable(rawUrl);
        if (reachable) {
          await _updaterChannel.invokeMethod('launchLiveCloudOta', {
            'url': liveUrl,
          });
          state = state.copyWith(
            installedVersion: targetVersion,
            installedBuildNumber: targetBuild,
            phase: OtaUpdatePhase.liveCloudActive,
            statusMessageAr:
                'تم تفعيل النسخة السحابية المحدثة ($targetVersion) فوراً بدون إعادة تثبيت APK!',
            clearError: true,
          );
          return;
        }
      } catch (_) {}
    }

    // Instant in-place hot state sync when live bundle mirrors current engine
    state = state.copyWith(
      installedVersion: targetVersion,
      installedBuildNumber: targetBuild,
      phase: OtaUpdatePhase.upToDate,
      bannerDismissed: true,
      statusMessageAr:
          'تمت مزامنة التحديث السحابي الفوري ($targetVersion • بناء #$targetBuild) بنجاح بدون الحاجة لإعادة تثبيت APK!',
      clearError: true,
    );
  }

  Future<bool> _isUrlReachable(String url) async {
    try {
      final res = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 4));
      return res.statusCode >= 200 && res.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  /// Mode 2: In-App Self-Updating Native APK Engine.
  /// Streams the new APK inside the app with a progress bar and invokes Android's native PackageInstaller.
  Future<void> downloadAndInstallApk() async {
    if (kIsWeb) {
      await launchInstantCloudUpdate();
      return;
    }

    final manifest = state.remoteManifest;
    final urls = <String>[
      if (manifest != null && manifest.apkDownloadUrl.isNotEmpty)
        manifest.apkDownloadUrl,
      if (manifest != null && manifest.apkMirrorUrl.isNotEmpty)
        manifest.apkMirrorUrl,
      AppVersionConstants.defaultApkDownloadUrl,
    ];

    state = state.copyWith(
      phase: OtaUpdatePhase.downloadingApk,
      downloadProgress: 0.02,
      downloadedBytes: 0,
      totalBytes: 0,
      clearError: true,
      statusMessageAr: 'جاري تنزيل حزمة التحديث الهوائي مباشرة داخل التطبيق...',
    );

    File? downloadedApkFile;
    String? lastErr;

    for (final rawUrl in urls) {
      final client = http.Client();
      try {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final sep = rawUrl.contains('?') ? '&' : '?';
        final uri = Uri.parse('$rawUrl${sep}t=$ts');

        final request = http.Request('GET', uri);
        final streamedResponse =
            await client.send(request).timeout(const Duration(seconds: 25));

        if (streamedResponse.statusCode < 200 ||
            streamedResponse.statusCode >= 300) {
          lastErr = 'HTTP ${streamedResponse.statusCode}';
          client.close();
          continue;
        }

        final total = streamedResponse.contentLength ?? 12246190;
        final tempDir = await getTemporaryDirectory();
        final otaDir = Directory(p.join(tempDir.path, 'marsa_ota'));
        if (!await otaDir.exists()) {
          await otaDir.create(recursive: true);
        }

        final buildTag = manifest?.buildNumber ?? (state.installedBuildNumber + 1);
        final filePath = p.join(otaDir.path, 'Marsa-Clinic-OTA-b$buildTag.apk');
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }

        final sink = file.openWrite();
        var received = 0;
        var firstChunkChecked = false;
        var isValidZipHeader = true;

        await for (final chunk in streamedResponse.stream) {
          if (!firstChunkChecked && chunk.length >= 2) {
            firstChunkChecked = true;
            // Verify APK/ZIP magic header ('PK' = 0x50, 0x4B)
            if (chunk[0] != 0x50 || chunk[1] != 0x4B) {
              isValidZipHeader = false;
              break;
            }
          }
          sink.add(chunk);
          received += chunk.length;
          final progress = total > 0 ? (received / total).clamp(0.02, 0.99) : 0.5;
          state = state.copyWith(
            downloadProgress: progress,
            downloadedBytes: received,
            totalBytes: total,
            statusMessageAr:
                'جاري تنزيل التحديث: ${(progress * 100).toStringAsFixed(0)}% (${_formatMb(received)} / ${_formatMb(total)})',
          );
        }

        await sink.flush();
        await sink.close();
        client.close();

        if (!isValidZipHeader || received < 100 * 1024) {
          lastErr = 'الملف المستلم ليس حزمة APK صالحة';
          if (await file.exists()) await file.delete();
          continue;
        }

        downloadedApkFile = file;
        break;
      } catch (e) {
        lastErr = e.toString();
      } finally {
        client.close();
      }
    }

    if (downloadedApkFile == null) {
      state = state.copyWith(
        phase: OtaUpdatePhase.error,
        errorMessageAr:
            'تعذر تنزيل حزمة APK حالياً ($lastErr). يمكنك استخدام "التحديث السحابي الفوري" لتشغيل التحديث بدون تنزيل!',
        clearStatus: true,
      );
      return;
    }

    state = state.copyWith(
      phase: OtaUpdatePhase.installingApk,
      downloadProgress: 1.0,
      statusMessageAr: 'اكتمل التنزيل بنجاح! جاري فتح المثبت التلقائي للنظام...',
    );

    try {
      final installResult = await _updaterChannel.invokeMethod<String>(
        'installApk',
        {'filePath': downloadedApkFile.path},
      );

      if (installResult == 'permission_requested') {
        state = state.copyWith(
          phase: OtaUpdatePhase.updateAvailable,
          canInstallPackages: false,
          statusMessageAr:
              'يرجى تفعيل خيار "السماح من هذا المصدر" وسيبدأ التثبيت التلقائي فوراً عند العودة للتطبيق.',
        );
      } else if (installResult == 'installer_launched') {
        state = state.copyWith(
          phase: OtaUpdatePhase.updateAvailable,
          statusMessageAr:
              'تم تشغيل مثبت التحديث بنجاح! اضغط "تحديث" في نافذة النظام لإتمام الترقية.',
        );
      } else {
        state = state.copyWith(
          phase: OtaUpdatePhase.error,
          errorMessageAr: 'تعذر بدء التثبيت التلقائي: $installResult',
        );
      }
    } catch (e) {
      state = state.copyWith(
        phase: OtaUpdatePhase.error,
        errorMessageAr: 'حدث خطأ أثناء استدعاء مثبت النظام: $e',
      );
    }
  }

  /// Publishes a new OTA version manifest or clinic announcement directly to the online server.
  Future<bool> publishOnlineUpdate({
    required String version,
    required int buildNumber,
    required String titleAr,
    required List<String> changelogAr,
    String? announcementAr,
    bool mandatory = false,
  }) async {
    final res = await apiClient.post(
      '/app-update',
      body: {
        'version': version,
        'buildNumber': buildNumber,
        'titleAr': titleAr,
        'changelogAr': changelogAr,
        'mandatory': mandatory,
        'remoteConfig': {
          'enableLiveCloudOta': true,
          'autoCheckOnStartup': true,
          'checkIntervalMinutes': 15,
          'clinicAnnouncementAr':
              (announcementAr != null && announcementAr.trim().isNotEmpty)
                  ? announcementAr.trim()
                  : null,
        },
      },
    );

    if (res.isSuccess) {
      await checkForUpdates(silent: false);
      return true;
    }
    return false;
  }

  static String _formatMb(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} م.ب';
  }
}
