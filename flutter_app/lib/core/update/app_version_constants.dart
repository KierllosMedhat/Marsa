/// Auto-synchronized application version constants.
/// Updated automatically by `scripts/publish_ota.mjs` / `publish_update.bat`.
class AppVersionConstants {
  static const String currentVersion = '1.2.1';
  static const int currentBuildNumber = 4;
  static const String channel = 'stable';

  static const String defaultLiveWebBundleUrl =
      'https://marsa-clinic-xi.vercel.app/ota-bundle/index.html';
  static const String defaultApkDownloadUrl =
      'https://raw.githubusercontent.com/KierllosMedhat/Marsa/main/Marsa-Clinic-Android.apk';
  static const String defaultApkMirrorUrl =
      'https://marsa-clinic-xi.vercel.app/ota/Marsa-Clinic-Android.apk';
  static const String staticManifestVercelUrl =
      'https://marsa-clinic-xi.vercel.app/ota/version.json';
  static const String staticManifestGithubUrl =
      'https://raw.githubusercontent.com/KierllosMedhat/Marsa/main/web/public/ota/version.json';
}
