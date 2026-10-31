import fs from 'fs';
import path from 'path';
import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

const DEFAULT_MANIFEST = {
  version: '1.2.1',
  buildNumber: 4,
  releasedAt: '2026-10-27T23:15:00.000Z',
  mandatory: false,
  minSupportedBuild: 1,
  channel: 'stable',
  titleAr: 'تحديث هوائي مباشر (OTA v1.2.0)',
  changelogAr: [
    'تفعيل نظام التحديث الهوائي التلقائي (OTA) دون الحاجة لإعادة تثبيت ملف APK يدوياً عند كل تعديل.',
    'إضافة وضع المزامنة السحابية الفورية (Live Cloud OTA) لتشغيل أحدث التعديلات والواجهات لحظياً فور نشرها.',
    'دعم التنزيل والتثبيت المباشر من داخل التطبيق مع شريط تقدم وفحص سلامة الحزمة.',
    'تحسين استجابة قلم Huawei M-Pencil ومزامنة الجلسات السريرية.',
  ],
  apkDownloadUrl:
    'https://raw.githubusercontent.com/KierllosMedhat/Marsa/main/Marsa-Clinic-Android.apk',
  apkMirrorUrl: 'https://marsa-clinic-xi.vercel.app/ota/Marsa-Clinic-Android.apk',
  liveWebBundleUrl: 'https://marsa-clinic-xi.vercel.app/ota-bundle/index.html',
  remoteConfig: {
    enableLiveCloudOta: true,
    autoCheckOnStartup: true,
    checkIntervalMinutes: 15,
    clinicAnnouncementAr: null as string | null,
    apiBaseUrlOverride: null as string | null,
  },
};

let runtimeOverride: Record<string, unknown> | null = null;

function loadManifestFromDisk() {
  const candidates = [
    path.join(process.cwd(), 'web', 'public', 'ota', 'version.json'),
    path.join(process.cwd(), 'public', 'ota', 'version.json'),
  ];
  for (const filePath of candidates) {
    try {
      if (fs.existsSync(filePath)) {
        const raw = fs.readFileSync(filePath, 'utf8');
        const parsed = JSON.parse(raw);
        return { ...DEFAULT_MANIFEST, ...parsed };
      }
    } catch (_) {}
  }
  return { ...DEFAULT_MANIFEST };
}

export async function GET() {
  const diskManifest = loadManifestFromDisk();
  const merged = runtimeOverride
    ? {
        ...diskManifest,
        ...runtimeOverride,
        remoteConfig: {
          ...(diskManifest.remoteConfig || {}),
          ...((runtimeOverride.remoteConfig as Record<string, unknown>) || {}),
        },
      }
    : diskManifest;

  return NextResponse.json(merged, {
    headers: {
      'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
      Pragma: 'no-cache',
      Expires: '0',
    },
  });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const current = loadManifestFromDisk();
    const updated = {
      ...current,
      ...(runtimeOverride || {}),
      ...body,
      releasedAt: new Date().toISOString(),
      remoteConfig: {
        ...(current.remoteConfig || {}),
        ...((runtimeOverride?.remoteConfig as Record<string, unknown>) || {}),
        ...(body.remoteConfig || {}),
      },
    };
    runtimeOverride = updated;

    // Persist to local disk manifests when running in a writable environment
    const candidates = [
      path.join(process.cwd(), 'web', 'public', 'ota', 'version.json'),
      path.join(process.cwd(), 'public', 'ota', 'version.json'),
    ];
    for (const filePath of candidates) {
      try {
        fs.mkdirSync(path.dirname(filePath), { recursive: true });
        fs.writeFileSync(filePath, JSON.stringify(updated, null, 2), 'utf8');
      } catch (_) {}
    }

    return NextResponse.json({
      status: 'published',
      manifest: updated,
    });
  } catch (err) {
    return NextResponse.json(
      { detail: 'تعذر تحديث بيانات الإصدار الهوائي', error: String(err) },
      { status: 400 }
    );
  }
}
