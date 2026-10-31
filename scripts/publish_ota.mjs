#!/usr/bin/env node
/**
 * Marsa Clinic — Automated Online OTA Update Publisher
 *
 * Synchronizes version & build numbers across Flutter, Android, Next.js, and Vercel,
 * builds the Live Cloud OTA bundle (and optionally the Android APK), and broadcasts
 * the update to `/api/app-update` so connected tablets update online without manual APK reinstalls.
 */

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');
const FLUTTER_DIR = path.join(ROOT_DIR, 'flutter_app');

const args = process.argv.slice(2);
const isWebOnly = args.includes('--web-only');
const skipBuild = args.includes('--manifest-only');
const autoPush = args.includes('--push');

function getArgValue(prefix) {
  const found = args.find((a) => a.startsWith(`${prefix}=`));
  return found ? found.slice(prefix.length + 1) : null;
}

function readCurrentManifest() {
  const manifestPath = path.join(ROOT_DIR, 'web', 'public', 'ota', 'version.json');
  if (fs.existsSync(manifestPath)) {
    return JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  }
  return {
    version: '1.2.0',
    buildNumber: 3,
    mandatory: false,
    minSupportedBuild: 1,
    channel: 'stable',
    titleAr: 'تحديث هوائي مباشر (OTA)',
    changelogAr: [
      'تحديث سحابي فوري للواجهات والميزات دون الحاجة لإعادة تثبيت APK يدوياً.',
    ],
    apkDownloadUrl:
      'https://raw.githubusercontent.com/KierllosMedhat/Marsa/master/Marsa-Clinic-Android.apk',
    apkMirrorUrl: 'https://marsa-clinic-xi.vercel.app/ota/Marsa-Clinic-Android.apk',
    liveWebBundleUrl: 'https://marsa-clinic-xi.vercel.app/ota-bundle/index.html',
    remoteConfig: {
      enableLiveCloudOta: true,
      autoCheckOnStartup: true,
      checkIntervalMinutes: 15,
      clinicAnnouncementAr: null,
      apiBaseUrlOverride: null,
    },
  };
}

function bumpPatchVersion(ver) {
  const parts = String(ver)
    .split('+')[0]
    .split('.')
    .map((n) => parseInt(n, 10) || 0);
  while (parts.length < 3) parts.push(0);
  parts[2] += 1;
  return parts.join('.');
}

async function main() {
  const current = readCurrentManifest();
  const shouldBump = !args.includes('--no-bump');
  const nextBuild = parseInt(
    getArgValue('--build') ||
      (shouldBump ? current.buildNumber + 1 : current.buildNumber),
    10
  );
  const nextVersion =
    getArgValue('--version') ||
    (shouldBump ? bumpPatchVersion(current.version) : current.version);
  const customNote = getArgValue('--note');

  console.log(`\n========================================================`);
  console.log(`  Marsa Clinic OTA Publisher -> v${nextVersion} (Build #${nextBuild})`);
  console.log(`========================================================\n`);

  // 1. Update flutter_app/pubspec.yaml
  const pubspecPath = path.join(FLUTTER_DIR, 'pubspec.yaml');
  if (fs.existsSync(pubspecPath)) {
    let pubspec = fs.readFileSync(pubspecPath, 'utf8');
    pubspec = pubspec.replace(
      /^version:\s*.*$/m,
      `version: ${nextVersion}+${nextBuild}`
    );
    fs.writeFileSync(pubspecPath, pubspec, 'utf8');
    console.log(`[1/5] Updated flutter_app/pubspec.yaml -> ${nextVersion}+${nextBuild}`);
  }

  // 2. Update flutter_app/android/app/build.gradle.kts
  const gradlePath = path.join(FLUTTER_DIR, 'android', 'app', 'build.gradle.kts');
  if (fs.existsSync(gradlePath)) {
    let gradle = fs.readFileSync(gradlePath, 'utf8');
    gradle = gradle
      .replace(/versionCode\s*=\s*\d+/, `versionCode = ${nextBuild}`)
      .replace(/versionName\s*=\s*"[^"]*"/, `versionName = "${nextVersion}"`);
    fs.writeFileSync(gradlePath, gradle, 'utf8');
    console.log(`[2/5] Updated build.gradle.kts -> versionCode=${nextBuild}, versionName="${nextVersion}"`);
  }

  // 3. Update flutter_app/lib/core/update/app_version_constants.dart
  const constantsPath = path.join(
    FLUTTER_DIR,
    'lib',
    'core',
    'update',
    'app_version_constants.dart'
  );
  if (fs.existsSync(constantsPath)) {
    let dartFile = fs.readFileSync(constantsPath, 'utf8');
    dartFile = dartFile
      .replace(
        /currentVersion\s*=\s*'[^']*'/,
        `currentVersion = '${nextVersion}'`
      )
      .replace(
        /currentBuildNumber\s*=\s*\d+/,
        `currentBuildNumber = ${nextBuild}`
      );
    fs.writeFileSync(constantsPath, dartFile, 'utf8');
    console.log(`[3/5] Updated app_version_constants.dart`);
  }

  // 4. Write updated OTA Manifests
  const updatedManifest = {
    ...current,
    version: nextVersion,
    buildNumber: nextBuild,
    releasedAt: new Date().toISOString(),
    titleAr: `تحديث هوائي مباشر (OTA v${nextVersion})`,
    changelogAr: customNote
      ? [customNote, ...(current.changelogAr || []).slice(0, 3)]
      : current.changelogAr,
  };

  for (const rel of [
    path.join('web', 'public', 'ota', 'version.json'),
    path.join('public', 'ota', 'version.json'),
  ]) {
    const full = path.join(ROOT_DIR, rel);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, JSON.stringify(updatedManifest, null, 2), 'utf8');
  }

  // Also synchronize default fallback version in API handlers
  for (const apiRel of [
    path.join('web', 'public', 'api', 'index.js'),
    path.join('src', 'app', 'api', 'app-update', 'route.ts'),
    path.join('src', 'app', 'api', 'health', 'route.ts'),
  ]) {
    const apiPath = path.join(ROOT_DIR, apiRel);
    if (fs.existsSync(apiPath)) {
      let content = fs.readFileSync(apiPath, 'utf8');
      content = content
        .replace(/version:\s*'[^']*'/, `version: '${nextVersion}'`)
        .replace(/appVersion:\s*'[^']*'/, `appVersion: '${nextVersion}'`)
        .replace(/buildNumber:\s*\d+/g, `buildNumber: ${nextBuild}`);
      fs.writeFileSync(apiPath, content, 'utf8');
    }
  }
  console.log(`[4/5] Updated OTA version.json manifests & API handlers`);

  // 5. Build Live Cloud OTA Bundle & Release APK
  if (!skipBuild) {
    console.log(`\n-> Building Live Cloud OTA Web Bundle (/ota-bundle/)...`);
    execSync(`flutter build web --release --base-href /ota-bundle/`, {
      cwd: FLUTTER_DIR,
      stdio: 'inherit',
    });

    const webBuildOut = path.join(FLUTTER_DIR, 'build', 'web');
    if (fs.existsSync(webBuildOut)) {
      for (const targetRel of [
        path.join('web', 'public', 'ota-bundle'),
        path.join('public', 'ota-bundle'),
      ]) {
        const dest = path.join(ROOT_DIR, targetRel);
        fs.rmSync(dest, { recursive: true, force: true });
        fs.cpSync(webBuildOut, dest, { recursive: true });
      }
      console.log(`   Copied Live Cloud OTA bundle to web/public/ota-bundle/`);
    }

    if (!isWebOnly) {
      console.log(`\n-> Building Release Android APK (arm64)...`);
      execSync(`flutter build apk --release --target-platform android-arm64`, {
        cwd: FLUTTER_DIR,
        stdio: 'inherit',
      });

      const builtApk = path.join(
        FLUTTER_DIR,
        'build',
        'app',
        'outputs',
        'flutter-apk',
        'app-release.apk'
      );
      if (fs.existsSync(builtApk)) {
        const rootApk = path.join(ROOT_DIR, 'Marsa-Clinic-Android.apk');
        fs.copyFileSync(builtApk, rootApk);
        console.log(`   Updated ${rootApk}`);
      }
    }
  }

  // 6. Broadcast live update metadata to online Vercel server
  try {
    const res = await fetch('https://marsa-clinic-xi.vercel.app/api/app-update', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updatedManifest),
    });
    if (res.ok) {
      console.log(`[5/5] Broadcasted live OTA manifest to https://marsa-clinic-xi.vercel.app/api/app-update`);
    }
  } catch (_) {}

  if (autoPush) {
    console.log(`\n-> Committing and pushing OTA update to GitHub...`);
    execSync(`git add .`, { cwd: ROOT_DIR, stdio: 'inherit' });
    try {
      execSync(
        `git commit -m "chore(ota): publish online OTA update v${nextVersion} (build #${nextBuild})"`,
        { cwd: ROOT_DIR, stdio: 'inherit' }
      );
    } catch (_) {}
    execSync(`git push origin HEAD`, { cwd: ROOT_DIR, stdio: 'inherit' });
  }

  console.log(`\n✅ Online OTA Update v${nextVersion} (Build #${nextBuild}) is ready!`);
}

main().catch((err) => {
  console.error('OTA Publish Error:', err);
  process.exit(1);
});
