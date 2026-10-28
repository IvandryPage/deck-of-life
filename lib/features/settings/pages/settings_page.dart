import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_info.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/date_time_field.dart';
import '../controllers/settings_controller.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const _Header('Pengingat'),
            ListTile(
              leading: Icon(
                controller.notificationsEnabled.value
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
              title: Text(
                controller.notificationsEnabled.value
                    ? 'Notifikasi aktif'
                    : 'Notifikasi belum diizinkan',
              ),
              subtitle: Text(
                controller.notificationsEnabled.value
                    ? 'Android dapat menunda notifikasi saat hemat baterai; waktunya tidak dijamin tepat detik.'
                    : 'Tanpa izin ini, deadline, tagihan, dan rutinitas tidak akan membunyikan pengingat. Data tetap tersimpan.',
              ),
              trailing: controller.notificationsEnabled.value
                  ? null
                  : FilledButton.tonal(
                      onPressed: controller.requestNotificationPermission,
                      child: const Text('Izinkan'),
                    ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fact_check_outlined),
              title: const Text('Tinjau tugas setelah kerja'),
              subtitle: Text(
                'Pengingat harian pukul ${controller.postWorkTime.value} untuk melihat kembali agenda dan deadline',
              ),
              value: controller.postWorkEnabled.value,
              onChanged: controller.setPostWork,
            ),
            ListTile(
              enabled: controller.postWorkEnabled.value,
              leading: const SizedBox(width: 24),
              title: const Text('Jam tinjauan'),
              trailing: Text(controller.postWorkTime.value),
              onTap: () async {
                final t = await pickHhmm(context, initial: controller.postWorkTime.value);
                if (t != null) await controller.setPostWorkTime(t);
              },
            ),
            const Divider(),
            const _Header('Backup & pemulihan'),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Ekspor backup'),
              subtitle: const Text(
                'Membuat berkas JSON berisi semua data. Berkas ini TIDAK terenkripsi dan berisi informasi pribadi; bagikan hanya ke tempat yang Anda percaya.',
              ),
              enabled: !controller.busy.value,
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Ekspor backup?',
                  message:
                      'Berkas backup berisi semua catatan, tugas, dan data keuangan Anda tanpa enkripsi. Simpan di tempat yang aman.',
                  confirmLabel: 'Lanjut',
                );
                if (ok) await controller.exportBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Pulihkan dari backup'),
              subtitle: const Text(
                'Mengganti SEMUA data saat ini dengan isi berkas backup. Backup pengaman dibuat otomatis lebih dulu.',
              ),
              enabled: !controller.busy.value,
              onTap: () => controller.restoreBackup(context),
            ),
            if (controller.busy.value) const LinearProgressIndicator(),
            const Divider(),
            const _Header('Tentang'),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('${AppInfo.name} · ${AppInfo.tagline}'),
              subtitle: Text(
                'Versi ${AppInfo.version}\nData disimpan hanya di perangkat ini. Tidak ada akun, server, atau sinkronisasi cloud. Backup manual adalah satu-satunya cara memulihkan data bila ponsel hilang.',
                style: theme.textTheme.bodySmall,
              ),
              isThreeLine: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );
}
