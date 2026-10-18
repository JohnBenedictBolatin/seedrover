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
import '../../../../core/utils/farmer_friendly_copy.dart';
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
      text: activity == CropMaintenanceActivity.watered ? 'ml' : 'grams');
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
  final waterSuggestionTask = _waterSuggestionTask(crop, task);
  final guidanceTask = task ??
      (activity == CropMaintenanceActivity.watered
          ? waterSuggestionTask
          : null);
  final isGrowth = activity == CropMaintenanceActivity.stageObserved;
  final currentStageIndex = crop.profileStages.indexWhere(
    (value) =>
        value.trim().toLowerCase() ==
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
            '${crop.displayName} · ${crop.name} · ${crop.fieldLabel} · ${crop.trackingCode}',
        controllers: [amount, unit, material, notes],
        canSubmit: () {
          final user = ref.read(authControllerProvider).profile;
          return user?.id == accountId &&
              user?.hasPermission(PermissionKeys.cropsManage) == true &&
              controller.cropById(crop.id)?.isCompleted == false &&
              (!isGrowth || observedStageChoices.isNotEmpty);
        },
        builder: (context, form) => TaskFields(children: [
          if (guidanceTask != null) ...[
            Text(guidanceTask.recommendation, style: AppTypography.body),
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
                  : activity == CropMaintenanceActivity.watered
                      ? 'Amount (ml)'
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
                      : activity == CropMaintenanceActivity.watered
                          ? 'e.g., 500'
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
            if (activity == CropMaintenanceActivity.watered)
              _CropField(
                label: 'Unit',
                child: Text('ml', style: AppTypography.body),
              )
            else
              _CropField(
                label: 'Unit',
                required: true,
                child: TextFormField(
                  controller: unit,
                  decoration: const InputDecoration(
                    hintText: 'e.g., grams',
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
              label: 'Growth stage',
              required: true,
              child: AppSelector<String>(
                  value: stage,
                  decoration: const InputDecoration(
                    hintText: 'Choose the stage you observed',
                  ),
                  items: [
                    for (final value in observedStageChoices)
                      DropdownMenuItem(
                          value: value,
                          child: Text(FarmerFriendlyCopy.growthStage(value)))
                  ],
                  validator: requiredCropValue,
                  onChanged: (value) {
                    stage = value;
                    form.changed();
                  }),
            ),
          if (isGrowth && observedStageChoices.isEmpty)
            _CropField(
              label: 'Growth stage',
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
          final suggestedWaterMl = waterSuggestionTask?.suggestedWaterMl;
          final enteredWaterMl = double.tryParse(amount.text);
          if (activity == CropMaintenanceActivity.watered &&
              suggestedWaterMl != null &&
              enteredWaterMl != null &&
              enteredWaterMl > suggestedWaterMl) {
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Water amount exceeds the limit'),
                content: Text(
                  'You entered ${NumberFormat('#,##0.##').format(enteredWaterMl)} ml, above the maximum ${NumberFormat('#,##0.##').format(suggestedWaterMl)} ml for this task. Reduce the amount before saving.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Edit amount'),
                  ),
                ],
              ),
            );
            return const ActionOutcome.failure(
                'Watering was not recorded. Reduce the amount to continue.');
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
              taskId: task?.id ??
                  (activity == CropMaintenanceActivity.watered
                      ? waterSuggestionTask?.id
                      : null),
              photos: photos.map((photo) => photo.path).toList(),
              submissionId: submissionId);
          return controller.lastEntryOutcome;
        },
      ));
}

String? requiredCropValue(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;

CropCareTask? _waterSuggestionTask(CropModel crop, CropCareTask? task) {
  if (task != null && task.type == 'Water' && task.suggestedWaterMl != null) {
    return task;
  }
  for (final candidate in crop.careTasks) {
    if (candidate.type == 'Water' &&
        const ['Due', 'Overdue', 'Upcoming', 'Postponed']
            .contains(candidate.status) &&
        candidate.suggestedWaterMl != null) {
      return candidate;
    }
  }
  return task?.type == 'Water' ? task : null;
}

Future<void> showCropClosureForm(BuildContext context, WidgetRef ref,
    CropMonitoringController controller, CropModel crop,
    {required bool harvest}) async {
  final quantity = TextEditingController();
  final notes = TextEditingController();
  var occurredAt = DateTime.now();
  DateTime? nextCheckOn;
  String? endReason;
  final submissionId = controller.newSubmissionId();
  final accountId = ref.read(authControllerProvider).profile?.id;
  final pendingHarvest = await controller.hasPendingCropEntries(crop.id);
  if (!context.mounted) return;
  Map<String, dynamic>? destination;
  final repeated = crop.harvestMode == 'repeat';
  await showTaskForm(
      context,
      TaskForm(
        title: harvest
            ? repeated
                ? 'Record harvest'
                : 'Record final harvest'
            : 'End crop',
        submitLabel: harvest
            ? repeated
                ? 'Record harvest'
                : SharedWorkflowTerms.harvestAndClose
            : 'End crop',
        contextLabel:
            '${crop.displayName} · ${crop.name} · ${crop.fieldLabel} · ${crop.trackingCode}',
        controllers: [quantity, notes],
        canSubmit: () {
          final user = ref.read(authControllerProvider).profile;
          return user?.id == accountId &&
              user?.hasPermission(PermissionKeys.cropsManage) == true &&
              controller.cropById(crop.id)?.isCompleted == false &&
              !pendingHarvest;
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
            if (repeated)
              _CropField(
                label: 'Check again on (optional)',
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(nextCheckOn == null
                      ? 'No reminder'
                      : DateFormat.yMMMd().format(nextCheckOn!)),
                  onPressed: () async {
                    final today = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: nextCheckOn ?? today,
                      firstDate: DateTime(today.year, today.month, today.day),
                      lastDate: DateTime(today.year + 5, 12, 31),
                    );
                    if (picked == null || !context.mounted) return;
                    nextCheckOn = picked;
                    form.changed();
                  },
                ),
              ),
          ],
          if (!harvest)
            _CropField(
              label: 'Why are you ending this crop?',
              required: true,
              child: DropdownButtonFormField<String>(
                value: endReason,
                decoration: const InputDecoration(hintText: 'Choose a reason'),
                items: const [
                  DropdownMenuItem(
                      value: 'Plants stopped producing',
                      child: Text('Plants stopped producing')),
                  DropdownMenuItem(
                      value: 'Plants removed', child: Text('Plants removed')),
                  DropdownMenuItem(
                      value: 'Plants died', child: Text('Plants died')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  endReason = value;
                  form.changed();
                },
                validator: (value) => value == null ? 'Choose a reason.' : null,
              ),
            ),
          if (harvest || endReason == 'Other')
            _CropField(
              label: harvest ? 'Harvest note' : 'What happened?',
              suffix: harvest ? ' (optional)' : null,
              required: !harvest,
              child: TextFormField(
                controller: notes,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  alignLabelWithHint: true,
                  hintText: harvest
                      ? 'e.g., Picked the ready pods today'
                      : 'Explain why this crop is ending',
                ),
                validator:
                    harvest || endReason == 'Other' ? null : requiredCropValue,
              ),
            ),
        ]),
        validate: () {
          if (pendingHarvest)
            return 'Sync or resolve this crop\'s saved harvest before continuing.';
          if (harvest && destination == null)
            return 'Load the destination inventory before reviewing this harvest.';
          if (!harvest && endReason == null)
            return 'Choose why this crop is ending.';
          if (!harvest && endReason == 'Other' && notes.text.trim().isEmpty)
            return 'Explain why this crop is ending.';
          return null;
        },
        reviewBuilder: () => ReviewDetails(
            values: {
              'Batch': '${crop.name} · ${crop.fieldLabel}',
              if (harvest) 'Harvest': '${quantity.text} kg',
              if (harvest && repeated && nextCheckOn != null)
                'Check again on': DateFormat.yMMMd().format(nextCheckOn!),
              if (harvest)
                'Destination inventory': '${destination?['name'] ?? ''}',
              if (!harvest && endReason != null) 'Reason': endReason!,
              if (notes.text.trim().isNotEmpty)
                harvest ? 'Note' : 'Details': notes.text,
            },
            consequence: harvest
                ? repeated
                    ? 'This adds today\'s harvest to inventory. The crop stays active so you can record future harvests.'
                    : 'This adds the harvest to inventory and closes the crop.'
                : 'This ends the crop and stops its care reminders. Past harvests remain in history; no inventory is added.'),
        onSubmit: () async {
          if (harvest) {
            await controller.recordCareEntry(
                cropId: crop.id,
                activity: CropMaintenanceActivity.harvested,
                date: occurredAt,
                notes: notes.text.trim(),
                quantity: double.parse(quantity.text),
                unit: 'kg',
                submissionId: submissionId,
                nextCheckOn: nextCheckOn);
          } else {
            await controller.endCrop(
                cropId: crop.id,
                reason: endReason!,
                explanation: endReason == 'Other' ? notes.text.trim() : null,
                submissionId: submissionId);
          }
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
