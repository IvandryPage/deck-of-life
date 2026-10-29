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
      appBar: AppBar(title: const Text('Settings')),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const _Header('Reminders'),
            ListTile(
              leading: Icon(
                controller.notificationsEnabled.value
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
              title: Text(
                controller.notificationsEnabled.value
                    ? 'Notifications are on'
                    : 'Notifications are not allowed',
              ),
              subtitle: Text(
                controller.notificationsEnabled.value
                    ? 'Battery saver may delay notifications, so exact delivery times are not guaranteed.'
                    : 'Without permission, task and bill reminders will not alert you. Your data is still saved.',
              ),
              trailing: controller.notificationsEnabled.value
                  ? null
                  : FilledButton.tonal(
                      onPressed: controller.requestNotificationPermission,
                      child: const Text('Allow'),
                    ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.fact_check_outlined),
              title: const Text('Review tasks after work'),
              subtitle: Text(
                'Daily reminder at ${controller.postWorkTime.value} to review your schedule and deadlines',
              ),
              value: controller.postWorkEnabled.value,
              onChanged: controller.setPostWork,
            ),
            ListTile(
              enabled: controller.postWorkEnabled.value,
              leading: const SizedBox(width: 24),
              title: const Text('Review time'),
              trailing: Text(controller.postWorkTime.value),
              onTap: () async {
                final t = await pickHhmm(context, initial: controller.postWorkTime.value);
                if (t != null) await controller.setPostWorkTime(t);
              },
            ),
            const Divider(),
            const _Header('Backup & restore'),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Export backup'),
              subtitle: const Text(
                'Creates a JSON file with all your data. It is not encrypted and contains personal information; only share it with places you trust.',
              ),
              enabled: !controller.busy.value,
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Export backup?',
                  message:
                      'The backup contains all your notes, tasks, and financial data without encryption. Store it somewhere safe.',
                  confirmLabel: 'Continue',
                );
                if (ok) await controller.exportBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Restore from backup'),
              subtitle: const Text(
                'Replaces all current data with the backup. A safety backup is created first.',
              ),
              enabled: !controller.busy.value,
              onTap: () => controller.restoreBackup(context),
            ),
            if (controller.busy.value) const LinearProgressIndicator(),
            const Divider(),
            const _Header('About'),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('${AppInfo.name} · ${AppInfo.tagline}'),
              subtitle: Text(
                'Version ${AppInfo.version}\nYour data stays on this device. No account, server, or cloud sync is used. A manual backup is the only way to recover your data if your phone is lost.',
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
