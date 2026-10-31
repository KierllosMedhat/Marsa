class RemoteClinicConfig {
  final bool enableLiveCloudOta;
  final bool autoCheckOnStartup;
  final int checkIntervalMinutes;
  final String? clinicAnnouncementAr;
  final String? apiBaseUrlOverride;

  const RemoteClinicConfig({
    this.enableLiveCloudOta = true,
    this.autoCheckOnStartup = true,
    this.checkIntervalMinutes = 15,
    this.clinicAnnouncementAr,
    this.apiBaseUrlOverride,
  });

  factory RemoteClinicConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RemoteClinicConfig();
    return RemoteClinicConfig(
      enableLiveCloudOta: json['enableLiveCloudOta'] as bool? ?? true,
      autoCheckOnStartup: json['autoCheckOnStartup'] as bool? ?? true,
      checkIntervalMinutes:
          (json['checkIntervalMinutes'] as num?)?.toInt() ?? 15,
      clinicAnnouncementAr: json['clinicAnnouncementAr'] as String?,
      apiBaseUrlOverride: json['apiBaseUrlOverride'] as String?,
    );
  }
}

class AppUpdateManifest {
  final String version;
  final int buildNumber;
  final String releasedAt;
  final bool mandatory;
  final int minSupportedBuild;
  final String channel;
  final String titleAr;
  final List<String> changelogAr;
  final String apkDownloadUrl;
  final String apkMirrorUrl;
  final String liveWebBundleUrl;
  final RemoteClinicConfig remoteConfig;

  const AppUpdateManifest({
    required this.version,
    required this.buildNumber,
    required this.releasedAt,
    this.mandatory = false,
    this.minSupportedBuild = 1,
    this.channel = 'stable',
    required this.titleAr,
    required this.changelogAr,
    required this.apkDownloadUrl,
    required this.apkMirrorUrl,
    required this.liveWebBundleUrl,
    this.remoteConfig = const RemoteClinicConfig(),
  });

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    final rawChangelog = json['changelogAr'] as List<dynamic>? ?? const [];
    return AppUpdateManifest(
      version: (json['version'] as String?)?.trim() ?? '1.2.0',
      buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 3,
      releasedAt:
          (json['releasedAt'] as String?) ?? DateTime.now().toIso8601String(),
      mandatory: json['mandatory'] as bool? ?? false,
      minSupportedBuild: (json['minSupportedBuild'] as num?)?.toInt() ?? 1,
      channel: (json['channel'] as String?) ?? 'stable',
      titleAr: (json['titleAr'] as String?) ?? 'تحديث هوائي مباشر (OTA)',
      changelogAr: rawChangelog.map((e) => e.toString()).toList(),
      apkDownloadUrl: (json['apkDownloadUrl'] as String?) ??
          'https://raw.githubusercontent.com/KierllosMedhat/Marsa/master/Marsa-Clinic-Android.apk',
      apkMirrorUrl: (json['apkMirrorUrl'] as String?) ??
          'https://marsa-clinic-xi.vercel.app/ota/Marsa-Clinic-Android.apk',
      liveWebBundleUrl: (json['liveWebBundleUrl'] as String?) ??
          'https://marsa-clinic-xi.vercel.app/ota-bundle/index.html',
      remoteConfig: RemoteClinicConfig.fromJson(
        json['remoteConfig'] as Map<String, dynamic>?,
      ),
    );
  }
}

enum OtaUpdatePhase {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloadingApk,
  installingApk,
  liveCloudActive,
  error,
}

class OtaUpdateState {
  final String installedVersion;
  final int installedBuildNumber;
  final bool canInstallPackages;
  final OtaUpdatePhase phase;
  final AppUpdateManifest? remoteManifest;
  final double downloadProgress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final bool autoLiveOtaEnabled;
  final bool bannerDismissed;
  final String? statusMessageAr;
  final String? errorMessageAr;
  final DateTime? lastCheckedAt;

  const OtaUpdateState({
    required this.installedVersion,
    required this.installedBuildNumber,
    this.canInstallPackages = true,
    this.phase = OtaUpdatePhase.idle,
    this.remoteManifest,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.autoLiveOtaEnabled = true,
    this.bannerDismissed = false,
    this.statusMessageAr,
    this.errorMessageAr,
    this.lastCheckedAt,
  });

  bool get hasUpdate {
    if (remoteManifest == null) return false;
    if (remoteManifest!.buildNumber > installedBuildNumber) return true;
    return compareSemver(remoteManifest!.version, installedVersion) > 0;
  }

  bool get isMandatoryUpdate {
    if (!hasUpdate || remoteManifest == null) return false;
    return remoteManifest!.mandatory ||
        installedBuildNumber < remoteManifest!.minSupportedBuild;
  }

  static int compareSemver(String a, String b) {
    final partsA = a
        .split('+')[0]
        .split('.')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList();
    final partsB = b
        .split('+')[0]
        .split('.')
        .map((e) => int.tryParse(e.trim()) ?? 0)
        .toList();
    for (var i = 0; i < 3; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  OtaUpdateState copyWith({
    String? installedVersion,
    int? installedBuildNumber,
    bool? canInstallPackages,
    OtaUpdatePhase? phase,
    AppUpdateManifest? remoteManifest,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    bool? autoLiveOtaEnabled,
    bool? bannerDismissed,
    String? statusMessageAr,
    bool clearStatus = false,
    String? errorMessageAr,
    bool clearError = false,
    DateTime? lastCheckedAt,
  }) {
    return OtaUpdateState(
      installedVersion: installedVersion ?? this.installedVersion,
      installedBuildNumber: installedBuildNumber ?? this.installedBuildNumber,
      canInstallPackages: canInstallPackages ?? this.canInstallPackages,
      phase: phase ?? this.phase,
      remoteManifest: remoteManifest ?? this.remoteManifest,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      autoLiveOtaEnabled: autoLiveOtaEnabled ?? this.autoLiveOtaEnabled,
      bannerDismissed: bannerDismissed ?? this.bannerDismissed,
      statusMessageAr:
          clearStatus ? null : (statusMessageAr ?? this.statusMessageAr),
      errorMessageAr:
          clearError ? null : (errorMessageAr ?? this.errorMessageAr),
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}
