import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_update_model.dart';
import 'ota_update_provider.dart';

/// Global wrapper that renders a top OTA Update banner across all screens
/// whenever a newer version or remote clinic announcement is detected online.
class OtaUpdateWrapper extends ConsumerWidget {
  final Widget child;

  const OtaUpdateWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otaState = ref.watch(otaUpdateProvider);
    final announcement =
        otaState.remoteManifest?.remoteConfig.clinicAnnouncementAr;
    final showUpdateBanner = otaState.hasUpdate && !otaState.bannerDismissed;
    final showAnnouncement =
        announcement != null && announcement.trim().isNotEmpty;

    if (!showUpdateBanner && !showAnnouncement) {
      return child;
    }

    return Column(
      children: [
        if (showUpdateBanner)
          Material(
            color: const Color(0xFF1B4F72),
            elevation: 4,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB58728),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            otaState.remoteManifest?.titleAr ??
                                'يتوفر تحديث هوائي جديد للتطبيق (v${otaState.remoteManifest?.version})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          const Text(
                            'يمكنك التحديث فورياً عبر السحابة بدون إعادة تثبيت APK يدوياً',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB58728),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        ref
                            .read(otaUpdateProvider.notifier)
                            .launchInstantCloudUpdate();
                      },
                      icon: const Icon(Icons.bolt_rounded, size: 15),
                      label: const Text(
                        'تحديث فوري',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => showOtaUpdateDialog(context),
                      child: const Text(
                        'التفاصيل',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    if (!otaState.isMandatoryUpdate)
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: 'إخفاء مؤقتاً',
                        onPressed: () =>
                            ref.read(otaUpdateProvider.notifier).dismissBanner(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (showAnnouncement)
          Material(
            color: const Color(0xFFFEF5E7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.campaign_rounded,
                    color: Color(0xFFB58728),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      announcement,
                      style: const TextStyle(
                        color: Color(0xFF5D4037),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

/// AppBar button that opens the OTA Update Center and shows a badge when an update is available.
class OtaUpdateActionButton extends ConsumerWidget {
  const OtaUpdateActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otaState = ref.watch(otaUpdateProvider);
    final hasUpdate = otaState.hasUpdate;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            hasUpdate
                ? Icons.cloud_download_rounded
                : Icons.cloud_sync_rounded,
          ),
          tooltip: hasUpdate
              ? 'يتوفر تحديث جديد (${otaState.remoteManifest?.version}) — اضغط للتحديث الفوري'
              : 'التحديث الهوائي التلقائي (OTA v${otaState.installedVersion})',
          onPressed: () => showOtaUpdateDialog(context),
        ),
        if (hasUpdate)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.amberAccent.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

void showOtaUpdateDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => const OtaUpdateDialog(),
  );
}

class OtaUpdateDialog extends ConsumerStatefulWidget {
  const OtaUpdateDialog({super.key});

  @override
  ConsumerState<OtaUpdateDialog> createState() => _OtaUpdateDialogState();
}

class _OtaUpdateDialogState extends ConsumerState<OtaUpdateDialog> {
  bool _showPublishPanel = false;
  late final TextEditingController _versionCtrl;
  late final TextEditingController _buildCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _changelogCtrl;
  late final TextEditingController _announcementCtrl;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(otaUpdateProvider);
    final nextBuild =
        (state.remoteManifest?.buildNumber ?? state.installedBuildNumber) + 1;
    _versionCtrl = TextEditingController(text: '1.2.$nextBuild');
    _buildCtrl = TextEditingController(text: '$nextBuild');
    _titleCtrl = TextEditingController(
      text: 'تحديث هوائي مباشر (OTA v1.2.$nextBuild)',
    );
    _changelogCtrl = TextEditingController(
      text: 'تحديث سحابي فوري للواجهات والميزات دون الحاجة لإعادة تثبيت APK.',
    );
    _announcementCtrl = TextEditingController(
      text: state.remoteManifest?.remoteConfig.clinicAnnouncementAr ?? '',
    );

    // Trigger a fresh check when opening the dialog
    Future.microtask(() {
      ref.read(otaUpdateProvider.notifier).checkForUpdates(silent: false);
    });
  }

  @override
  void dispose() {
    _versionCtrl.dispose();
    _buildCtrl.dispose();
    _titleCtrl.dispose();
    _changelogCtrl.dispose();
    _announcementCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otaState = ref.watch(otaUpdateProvider);
    final notifier = ref.read(otaUpdateProvider.notifier);
    final manifest = otaState.remoteManifest;
    final hasUpdate = otaState.hasUpdate;
    final isDownloading = otaState.phase == OtaUpdatePhase.downloadingApk ||
        otaState.phase == OtaUpdatePhase.installingApk;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasUpdate
                  ? Colors.amber.shade800
                  : const Color(0xFF45632D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasUpdate
                  ? Icons.system_update_alt_rounded
                  : Icons.cloud_done_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مركز التحديث الهوائي التلقائي (OTA)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'تحديث التطبيق سحابياً أونلاين دون الحاجة لتثبيت APK يدوياً',
                  style: TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Version comparison cards
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD5E2CE)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الإصدار المثبت حالياً',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'v${otaState.installedVersion} (بناء #${otaState.installedBuildNumber})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF2F451E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFFB58728),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'أحدث إصدار سحابي (Online)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            manifest != null
                                ? 'v${manifest.version} (بناء #${manifest.buildNumber})'
                                : 'جاري الفحص...',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: hasUpdate
                                  ? Colors.amber.shade900
                                  : Colors.teal.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Status or Error Banner
              if (otaState.statusMessageAr != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: hasUpdate
                        ? Colors.amber.shade50
                        : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasUpdate
                          ? Colors.amber.shade300
                          : Colors.teal.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (otaState.phase == OtaUpdatePhase.checking)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          hasUpdate
                              ? Icons.new_releases_rounded
                              : Icons.verified_rounded,
                          size: 18,
                          color: hasUpdate
                              ? Colors.amber.shade900
                              : Colors.teal.shade700,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          otaState.statusMessageAr!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (otaState.errorMessageAr != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    otaState.errorMessageAr!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                  ),
                ),

              // Live Download Progress Bar
              if (isDownloading) ...[
                LinearProgressIndicator(
                  value: otaState.downloadProgress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF45632D)),
                ),
                const SizedBox(height: 12),
              ],

              // Release Notes / Changelog
              if (manifest != null && manifest.changelogAr.isNotEmpty) ...[
                Text(
                  manifest.titleAr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFF1B4F72),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: manifest.changelogAr
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB58728),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Action Option 1: Instant Live Cloud Update (Zero APK Install)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4F72),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isDownloading
                    ? null
                    : () async {
                        await notifier.launchInstantCloudUpdate();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم تطبيق التحديث السحابي الفوري بنجاح دون الحاجة لتثبيت APK!',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.bolt_rounded),
                label: const Text(
                  'تحديث سحابي فوري الآن (بدون إعادة تثبيت APK)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),

              // Action Option 2: Self-Updating Native APK Installer (Android)
              if (!kIsWeb) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF45632D),
                    side: const BorderSide(
                      color: Color(0xFF45632D),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isDownloading
                      ? null
                      : () => notifier.downloadAndInstallApk(),
                  icon: const Icon(Icons.install_mobile_rounded),
                  label: const Text(
                    'تنزيل وتثبيت حزمة APK المحدثة تلقائياً من داخل التطبيق',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Auto-Update Switch
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                dense: true,
                title: const Text(
                  'التحديث السحابي التلقائي فور تشغيل التطبيق',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'عند التفعيل، يتم جلب وتشغيل أي تعديل جديد سحابياً بشكل تلقائي دون أي تدخل يدوي',
                  style: TextStyle(fontSize: 11),
                ),
                value: otaState.autoLiveOtaEnabled,
                onChanged: (val) => notifier.setAutoLiveOtaEnabled(val),
              ),

              const Divider(height: 20),

              // Developer / Admin Live OTA Broadcast Panel
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () =>
                    setState(() => _showPublishPanel = !_showPublishPanel),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.rocket_launch_outlined,
                        size: 18,
                        color: Color(0xFFB58728),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'بث تحديث هوائي جديد / إعلان لجميع أجهزة العيادة',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8E6513),
                          ),
                        ),
                      ),
                      Icon(
                        _showPublishPanel
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: const Color(0xFF8E6513),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showPublishPanel) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9E7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5D0A1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _versionCtrl,
                              decoration: const InputDecoration(
                                labelText: 'رقم الإصدار الجديد',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _buildCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'رقم البناء (Build #)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'عنوان التحديث',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _changelogCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملخص التعديلات (سطر لكل ميزة)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _announcementCtrl,
                        decoration: const InputDecoration(
                          labelText: 'إعلان فوري أعلى التطبيق (اختياري)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB58728),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isPublishing
                            ? null
                            : () async {
                                setState(() => _isPublishing = true);
                                final buildNum =
                                    int.tryParse(_buildCtrl.text.trim()) ??
                                        (otaState.installedBuildNumber + 1);
                                final notes = _changelogCtrl.text
                                    .split('\n')
                                    .map((s) => s.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toList();
                                final ok = await notifier.publishOnlineUpdate(
                                  version: _versionCtrl.text.trim(),
                                  buildNumber: buildNum,
                                  titleAr: _titleCtrl.text.trim(),
                                  changelogAr: notes.isEmpty
                                      ? ['تحديث سحابي مباشر للتطبيق']
                                      : notes,
                                  announcementAr: _announcementCtrl.text,
                                );
                                if (mounted) {
                                  setState(() {
                                    _isPublishing = false;
                                    if (ok) _showPublishPanel = false;
                                  });
                                }
                              },
                        icon: _isPublishing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: const Text('نشر التحديث فوراً على السحابة'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: isDownloading
              ? null
              : () => notifier.checkForUpdates(silent: false),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('فحص التحديثات الآن'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
