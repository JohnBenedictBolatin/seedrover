import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/permission_keys.dart';
import '../../../../core/constants/shared_workflow_terms.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_input_formatters.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/task_form.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../controllers/crop_monitoring_controller.dart';
import '../../data/models/crop_model.dart';

Future<void> showCropCareForm(
    BuildContext context,
    WidgetRef ref,
    CropMonitoringController controller,
    CropModel crop,
    CropMaintenanceActivity activity,
    CropCareTask? task) async {
  final amount = TextEditingController();
  final unit = TextEditingController(
      text: activity == CropMaintenanceActivity.watered ? 'liters' : 'grams');
  final material = TextEditingController();
  final notes = TextEditingController();
  final submissionId = controller.newSubmissionId();
  final accountId = ref.read(authControllerProvider).profile?.id;
  var occurredAt = DateTime.now();
  String? stage;
  final photos = <XFile>[];
  final photoBytes = <Uint8List>[];
  final hasAmount = activity == CropMaintenanceActivity.watered ||
      activity == CropMaintenanceActivity.fertilized;
  final isGrowth = activity == CropMaintenanceActivity.stageObserved;
  final currentStageIndex = crop.profileStages.indexWhere(
    (value) => value.trim().toLowerCase() ==
        crop.growthStageLabel.trim().toLowerCase(),
  );
  final observedStageChoices = currentStageIndex < 0
      ? const <String>[]
      : crop.profileStages.skip(currentStageIndex).toList(growable: false);
  final label = switch (activity) {
    CropMaintenanceActivity.watered => 'watering',
    CropMaintenanceActivity.fertilized => 'fertilizing',
    CropMaintenanceActivity.stageObserved => 'observation',
    CropMaintenanceActivity.transplanted => 'transplanting',
    _ =>
      SharedWorkflowTerms.fieldCheck.replaceFirst('Record ', '').toLowerCase(),
  };
  await showTaskForm(
      context,
      TaskForm(
        title: isGrowth ? 'Observe growth' : 'Record $label',
        submitLabel: 'Save $label',
        contextLabel:
            '${crop.name} · ${crop.fieldLabel} · ${crop.trackingCode}',
        controllers: [amount, unit, material, notes],
        canSubmit: () {
          final user = ref.read(authControllerProvider).profile;
          return user?.id == accountId &&
              user?.hasPermission(PermissionKeys.cropsManage) == true &&
              controller.cropById(crop.id)?.isCompleted == false &&
              (!isGrowth || observedStageChoices.isNotEmpty);
        },
        builder: (context, form) => TaskFields(children: [
          if (task != null) ...[
            Text(task.recommendation, style: AppTypography.body),
            const SizedBox(height: AppSpacing.xs),
          ],
          _CropField(
            label: SharedWorkflowTerms.dateAndTime,
            required: true,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                DateFormat.yMMMd().add_jm().format(occurredAt),
                style: AppTypography.numericInput,
              ),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: occurredAt,
                  firstDate: crop.plantingDate,
                  lastDate: DateTime.now(),
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(occurredAt),
                );
                if (time == null || !context.mounted) return;
                occurredAt = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                form.changed();
              },
            ),
          ),
          if (hasAmount) ...[
            _CropField(
              label: activity == CropMaintenanceActivity.harvested
                  ? 'Total batch weight (kg)'
                  : 'Amount',
              required: true,
              child: TextFormField(
                controller: amount,
                style: AppTypography.numericInput,
                inputFormatters: AppInputFormatters.decimal,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: activity == CropMaintenanceActivity.harvested
                      ? 'e.g., 12.5'
                      : 'e.g., 2.5',
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null || !n.isFinite || n <= 0
                      ? 'Enter an amount greater than zero.'
                      : null;
                },
              ),
            ),
            _CropField(
              label: 'Unit',
              required: true,
              child: TextFormField(
                controller: unit,
                decoration: const InputDecoration(
                  hintText: 'e.g., liters or grams',
                ),
                validator: requiredCropValue,
              ),
            ),
          ],
          if (activity == CropMaintenanceActivity.fertilized)
            _CropField(
              label: 'Fertilizer used',
              required: true,
              child: TextFormField(
                controller: material,
                decoration: const InputDecoration(
                  hintText: 'e.g., NPK 14-14-14',
                ),
                validator: requiredCropValue,
              ),
            ),
          if (activity == CropMaintenanceActivity.inspected)
            _CropField(
              label: 'Observation',
              required: true,
              child: AppSelector<String>(
                  value: material.text.isEmpty ? null : material.text,
                  decoration: const InputDecoration(
                    hintText: 'Choose an observation',
                  ),
                  items: [
                    for (final value
                        in SharedWorkflowChoices.fieldCheckObservations)
                      DropdownMenuItem(value: value, child: Text(value))
                  ],
                  validator: (value) =>
                      value == null ? 'Choose an observation.' : null,
                  onChanged: (value) {
                    material.text = value!;
                    form.changed();
                  }),
            ),
          if (activity == CropMaintenanceActivity.transplanted)
            _CropField(
              label: 'Transplanted to',
              required: true,
              child: TextFormField(
                controller: material,
                decoration: const InputDecoration(
                  hintText: 'e.g., North field, row 3',
                ),
                validator: requiredCropValue,
              ),
            ),
          if (isGrowth && observedStageChoices.isNotEmpty)
            _CropField(
              label: 'Observed growth stage',
              required: true,
              child: AppSelector<String>(
                  value: stage,
                  decoration: const InputDecoration(
                    hintText: 'Choose the stage you observed',
                  ),
                  items: [
                    for (final value in observedStageChoices)
                      DropdownMenuItem(value: value, child: Text(value))
                  ],
                  validator: requiredCropValue,
                  onChanged: (value) {
                    stage = value;
                    form.changed();
                  }),
            ),
          if (isGrowth && observedStageChoices.isEmpty)
            _CropField(
              label: 'Observed growth stage',
              required: true,
              child: Text(
                'No later stage is available for this crop profile. Update its stage plan before recording another observation.',
                style: AppTypography.caption.copyWith(color: AppColors.warning),
              ),
            ),
          _CropField(
            label: 'Notes',
            suffix: ' (optional)',
            child: TextFormField(
              controller: notes,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                hintText: 'e.g., Watered after the morning inspection',
              ),
            ),
          ),
          if (isGrowth) ...[
            for (var index = 0; index < photos.length; index++)
              ListTile(
                  leading: Image.memory(photoBytes[index],
                      width: 56, height: 56, fit: BoxFit.cover),
                  title: Text(photos[index].name),
                  trailing: IconButton(
                      tooltip: 'Remove photo',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        photos.removeAt(index);
                        photoBytes.removeAt(index);
                        form.changed();
                      })),
            _CropField(
              label: 'Growth photos',
              suffix: ' (optional)',
              child: OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(photos.isEmpty
                    ? 'Add growth photos'
                    : 'Add more growth photos'),
                onPressed: () async {
                  try {
                    final picker = ImagePicker();
                    final source = await showModalBottomSheet<ImageSource>(
                        context: context,
                        builder: (context) => SafeArea(
                                child: Wrap(children: [
                              ListTile(
                                  title: const Text('Camera'),
                                  leading:
                                      const Icon(Icons.camera_alt_outlined),
                                  onTap: () => Navigator.pop(
                                      context, ImageSource.camera)),
                              ListTile(
                                  title: const Text('Photo library'),
                                  leading:
                                      const Icon(Icons.photo_library_outlined),
                                  onTap: () => Navigator.pop(
                                      context, ImageSource.gallery))
                            ])));
                    if (source == null) return;
                    final List<XFile> selected;
                    if (source == ImageSource.camera) {
                      final photo = await picker.pickImage(
                          source: source, imageQuality: 85);
                      selected = photo == null ? [] : [photo];
                    } else {
                      selected = await picker.pickMultiImage(imageQuality: 85);
                    }
                    for (final photo in selected) {
                      final mime = photo.mimeType ??
                          (photo.name.toLowerCase().endsWith('.png')
                              ? 'image/png'
                              : photo.name.toLowerCase().endsWith('.webp')
                                  ? 'image/webp'
                                  : 'image/jpeg');
                      final bytes = await photo.readAsBytes();
                      if (!SharedWorkflowRules.photoMimeTypes.contains(mime) ||
                          bytes.length > SharedWorkflowRules.photoMaxBytes) {
                        form.showError(
                            'Growth photos must be JPG, PNG or WebP, up to 5 MB each.');
                        continue;
                      }
                      photos.add(photo);
                      photoBytes.add(bytes);
                    }
                    form.changed();
                  } catch (_) {
                    form.showError(
                        'Camera access is unavailable. Allow camera access in your phone settings, then try again. Your entry is still here.');
                  }
                },
              ),
            ),
            Text(
              'JPG, PNG, or WebP, up to 5 MB each. Photos appear in Growth.',
              style: AppTypography.small,
            ),
          ],
        ]),
        onSubmit: () async {
          if (isGrowth && stage == null) {
            return const ActionOutcome.failure(
                'Choose the growth stage observed in the field.');
          }
          await controller.recordCareEntry(
              cropId: crop.id,
              activity: activity,
              date: occurredAt,
              notes: notes.text,
              quantity: hasAmount ? double.tryParse(amount.text) : null,
              unit: hasAmount ? unit.text.trim() : null,
              material: material.text,
              observedStage: stage,
              taskId: task?.id,
              photos: photos.map((photo) => photo.path).toList(),
              submissionId: submissionId);
          return controller.lastEntryOutcome;
        },
      ));
}

String? requiredCropValue(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

Future<void> showCropClosureForm(BuildContext context, WidgetRef ref,
    CropMonitoringController controller, CropModel crop,
    {required bool harvest}) async {
  final quantity = TextEditingController();
  final notes = TextEditingController();
  var occurredAt = DateTime.now();
  final submissionId = controller.newSubmissionId();
  final accountId = ref.read(authControllerProvider).profile?.id;
  Map<String, dynamic>? destination;
  await showTaskForm(
      context,
      TaskForm(
        title: harvest ? 'Harvest batch' : 'Close without harvest',
        submitLabel:
            harvest ? 'Harvest and close batch' : 'Close without harvest',
        contextLabel:
            '${crop.name} · ${crop.fieldLabel} · ${crop.trackingCode}',
        controllers: [quantity, notes],
        canSubmit: () {
          final user = ref.read(authControllerProvider).profile;
          return user?.id == accountId &&
              user?.hasPermission(PermissionKeys.cropsManage) == true &&
              controller.cropById(crop.id)?.isCompleted == false;
        },
        builder: (context, form) => TaskFields(children: [
          _CropField(
            label: SharedWorkflowTerms.dateAndTime,
            required: true,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                DateFormat.yMMMd().add_jm().format(occurredAt),
                style: AppTypography.numericInput,
              ),
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: occurredAt,
                  firstDate: crop.plantingDate,
                  lastDate: DateTime.now(),
                );
                if (pickedDate == null || !context.mounted) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(occurredAt),
                );
                if (pickedTime == null || !context.mounted) return;
                occurredAt = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
                form.changed();
              },
            ),
          ),
          if (harvest) ...[
            _CropField(
              label: 'Total batch weight (kg)',
              required: true,
              child: TextFormField(
                controller: quantity,
                style: AppTypography.numericInput,
                inputFormatters: AppInputFormatters.decimal,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'e.g., 12.5'),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null || !n.isFinite || n <= 0
                      ? 'Enter a weight greater than zero.'
                      : null;
                },
              ),
            ),
            _CropField(
              label: 'Inventory destination',
              child: _HarvestDestination(
                load: () => controller.getHarvestDestination(crop.id),
                onLoaded: (value) => destination = value,
              ),
            ),
          ],
          _CropField(
            label: harvest ? 'Harvest note' : 'Reason for closure',
            suffix: harvest ? ' (optional)' : null,
            required: !harvest,
            child: TextFormField(
              controller: notes,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                hintText: harvest
                    ? 'e.g., Harvested ripe pods from this batch'
                    : 'e.g., Crop damaged by flooding',
              ),
              validator: harvest ? null : requiredCropValue,
            ),
          ),
        ]),
        validate: () => harvest && destination == null
            ? 'Load the destination inventory before reviewing this harvest.'
            : null,
        reviewBuilder: () => ReviewDetails(
            values: {
              'Batch': '${crop.name} · ${crop.fieldLabel}',
              if (harvest) 'Harvest': '${quantity.text} kg',
              if (harvest)
                'Destination inventory': '${destination?['name'] ?? ''}',
              if (notes.text.trim().isNotEmpty)
                harvest ? 'Note' : 'Reason': notes.text,
            },
            consequence: harvest
                ? 'This adds the entire harvest to the destination inventory and closes this batch.'
                : 'This closes the batch without adding any inventory.'),
        onSubmit: () async {
          await controller.recordCareEntry(
              cropId: crop.id,
              activity: harvest
                  ? CropMaintenanceActivity.harvested
                  : CropMaintenanceActivity.notHarvested,
              date: occurredAt,
              notes: notes.text.trim(),
              quantity: harvest ? double.parse(quantity.text) : null,
              unit: harvest ? 'kg' : null,
              submissionId: submissionId);
          return controller.lastEntryOutcome;
        },
      ));
}

class _HarvestDestination extends StatefulWidget {
  const _HarvestDestination({required this.load, required this.onLoaded});
  final Future<Map<String, dynamic>> Function() load;
  final ValueChanged<Map<String, dynamic>> onLoaded;
  @override
  State<_HarvestDestination> createState() => _HarvestDestinationState();
}

class _HarvestDestinationState extends State<_HarvestDestination> {
  late Future<Map<String, dynamic>> _request;
  @override
  void initState() {
    super.initState();
    _request = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final value = await widget.load();
    widget.onLoaded(value);
    return value;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _request,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Could not load a compatible destination inventory. Your input is still here.'),
                  TextButton(
                      onPressed: () => setState(() => _request = _load()),
                      child: const Text('Retry destination')),
                ]);
          }
          if (!snapshot.hasData) {
            return const InputDecorator(
              decoration: InputDecoration(hintText: 'Loading inventory...'),
              child: LinearProgressIndicator(
                semanticsLabel: 'Loading destination inventory',
              ),
            );
          }
          return InputDecorator(
            decoration: const InputDecoration(),
            child: Text(snapshot.data!['name'] as String),
          );
        },
      );
}

class _CropField extends StatelessWidget {
  const _CropField({
    required this.label,
    required this.child,
    this.required = false,
    this.suffix,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? suffix;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
              children: [
                TextSpan(text: label),
                if (suffix != null) TextSpan(text: suffix),
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      );
}
