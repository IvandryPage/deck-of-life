import 'package:flutter/material.dart';

import '../../app/design/tokens.dart';

import 'date_time_field.dart';

/// Dropdown untuk enum. `key` mengikuti nilai agar tampilan selalu sinkron
/// bila nilai diubah dari luar (mis. saran otomatis).
class EnumDropdown<T> extends StatelessWidget {
  const EnumDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey<T>(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final i in items)
          DropdownMenuItem<T>(value: i, child: Text(labelOf(i))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class ReminderPreset {
  const ReminderPreset(this.label, this.before);

  final String label;
  final Duration before;
}

/// Kolom pengingat opsional + tombol preset relatif terhadap [anchor].
class ReminderField extends StatelessWidget {
  const ReminderField({
    super.key,
    required this.value,
    required this.onChanged,
    this.anchor,
    this.presets = const [],
    this.label = 'Reminder',
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? anchor;
  final List<ReminderPreset> presets;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DateTimeField(
          label: label,
          value: value,
          onChanged: onChanged,
          emptyText: 'No reminder',
        ),
        if (anchor != null && presets.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            children: [
              for (final p in presets)
                ActionChip(
                  label: Text(p.label),
                  onPressed: () => onChanged(anchor!.subtract(p.before)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Keeps infrequently used fields available without crowding the main form.
class AdvancedOptions extends StatefulWidget {
  const AdvancedOptions({
    super.key,
    required this.children,
    this.initiallyOpen = false,
    this.label = 'More options',
  });

  final List<Widget> children;

  /// Dibuka otomatis bila ada isian lanjutan yang sudah terisi (mis. saat mengubah).
  final bool initiallyOpen;
  final String label;

  @override
  State<AdvancedOptions> createState() => _AdvancedOptionsState();
}

class _AdvancedOptionsState extends State<AdvancedOptions> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              minimumSize: const Size(AppSize.tap, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              textStyle: Theme.of(context).textTheme.labelMedium,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            onPressed: () => setState(() => _open = !_open),
            icon: AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: AppMotion.of(context, AppMotion.micro),
              child: const Icon(Icons.expand_more, size: AppSize.iconSm),
            ),
            iconAlignment: IconAlignment.end,
            label: Text(
              _open ? 'Hide ${widget.label.toLowerCase()}' : widget.label,
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.standard),
          curve: AppMotion.standardCurve,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in widget.children) ...[
                        c,
                        const SizedBox(height: AppSpace.lg),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Shared form layout with a persistent primary action above the keyboard.
class FormPage extends StatelessWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.saving = false,
    this.saveLabel = 'Save',
    this.formKey,
    this.actions = const [],
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final bool saving;
  final String saveLabel;
  final GlobalKey<FormState>? formKey;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: formKey,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSize.maxContentWidth,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.gutter,
                      AppSpace.sm,
                      AppSpace.gutter,
                      AppSpace.xl,
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      for (final c in children) ...[
                        c,
                        const SizedBox(height: AppSpace.lg),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.sm,
                AppSpace.gutter,
                AppSpace.md,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSize.maxContentWidth,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving ? null : onSave,
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(saveLabel),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard form-page padding that remains clear of the keyboard.
class FormScroll extends StatelessWidget {
  const FormScroll({super.key, required this.children, this.formKey});

  final List<Widget> children;
  final GlobalKey<FormState>? formKey;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          for (final c in children) ...[c, const SizedBox(height: 14)],
        ],
      ),
    );
  }
}
