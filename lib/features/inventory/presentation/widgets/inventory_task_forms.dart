import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/permission_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/constants/shared_workflow_terms.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/app_input_formatters.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/widgets/task_form.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../controllers/stock_inventory_controller.dart';
import '../../data/models/uncertain_inventory_write.dart';
import '../../data/models/stock_model.dart';
import 'stock_transaction_timeline.dart';

enum InventoryTask { receive, issue, sale, adjust }

String quantityText(num value) => NumberFormat('0.##').format(value);

String _saleBatchLabel(StockModel stock, String batchId) {
  final batch = stock.batches.where((batch) => batch.id == batchId).firstOrNull;
  if (batch == null) return 'Selected batch unavailable';
  final date = batch.harvestOn ?? batch.receivedOn;
  final dateLabel = DateFormat.yMMMd().format(date);
  return '$dateLabel · ${quantityText(batch.remainingQuantity)} ${stock.unit}';
}

String _newInventoryRequestId() {
  final random = math.Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String? requiredValue(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;
String? nonnegativeNumber(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return 'Enter a number.';
  final number = double.tryParse(raw);
  if (number == null || !number.isFinite) return 'Enter a valid number.';
  if (number < 0) return 'This value cannot be negative.';
  return null;
}

Future<void> showInventoryTransaction(
    BuildContext context,
    WidgetRef ref,
    StockInventoryController controller,
    StockModel stock,
    InventoryTask task) async {
  final requestId = _newInventoryRequestId();
  final isSale = task == InventoryTask.sale;
  List<ExistingSaleCustomer> existingCustomers = const [];
  String? existingCustomerLoadError;
  if (isSale) {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final loadingDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 16),
                Flexible(child: Text('Loading customer history…')),
              ],
            ),
          ),
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    try {
      existingCustomers = await controller.getExistingSaleCustomers();
    } catch (_) {
      existingCustomerLoadError =
          'Customer history could not be loaded. Check your connection and try again.';
    } finally {
      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
      await loadingDialog;
    }
    if (!context.mounted) return;
  }

  final initialAccount = ref.read(authControllerProvider).profile;
  final quantity = TextEditingController(
      text: task == InventoryTask.adjust
          ? quantityText(stock.currentQuantity)
          : '');
  var unitPrice = stock.sellingPrice;
  final notes = TextEditingController();
  final reason = TextEditingController();
  final customerFirst = TextEditingController();
  final customerMiddle = TextEditingController();
  final customerLast = TextEditingController();
  final customerContact = TextEditingController();
  final reference = TextEditingController();
  final otherPayment = TextEditingController();
  var selectedReason = '';
  var source = '';
  var targetBatchId = 'fifo';
  var payment = 'Cash';
  var saleStep = 0;
  var useExistingCustomer = false;
  ExistingSaleCustomer? selectedCustomer;
  var date = DateTime.now();
  var available = stock.currentQuantity;
  final title = switch (task) {
    InventoryTask.receive => 'Receive stock',
    InventoryTask.issue => 'Issue stock',
    InventoryTask.sale => 'Record sale',
    InventoryTask.adjust => 'Adjust quantity',
  };
  double getQuantity() => double.tryParse(quantity.text) ?? 0;
  double balance() => switch (task) {
        InventoryTask.receive => available + getQuantity(),
        InventoryTask.adjust => getQuantity(),
        _ => available - getQuantity(),
      };
  Map<String, String> summary() => {
        'Item': stock.name,
        'Available': '${quantityText(available)} ${stock.unit}',
        if (isSale && targetBatchId != 'fifo')
          'Batch': _saleBatchLabel(stock, targetBatchId),
        task == InventoryTask.adjust ? 'New total quantity' : 'Quantity':
            '${quantity.text} ${stock.unit}',
        if (task == InventoryTask.adjust)
          'Difference':
              '${quantityText(getQuantity() - available)} ${stock.unit}',
        'Resulting balance': '${quantityText(balance())} ${stock.unit}',
        if (isSale) ...{
          'Unit price':
              unitPrice == null ? 'Not set' : CurrencyFormatter.php(unitPrice!),
          'Total': CurrencyFormatter.php(getQuantity() * (unitPrice ?? 0)),
          'Sale date': DateFormat.yMMMd().add_jm().format(date),
          'Payment': payment == 'Other' ? otherPayment.text : payment,
          if (payment != 'Cash') 'Transaction ID': reference.text,
          'Customer': [
            if (selectedCustomer != null)
              selectedCustomer!.name
            else ...[
              customerFirst.text.trim(),
              if (customerMiddle.text.trim().isNotEmpty)
                '${customerMiddle.text.trim()}.',
              customerLast.text.trim()
            ],
          ].where((part) => part.isNotEmpty).join(' '),
          'Contact number':
              selectedCustomer?.contact ?? customerContact.text.trim(),
        },
        if (task == InventoryTask.adjust) 'Reason': reason.text,
        if (task == InventoryTask.issue) 'Reason': selectedReason,
        if (task == InventoryTask.receive) 'Source': source,
        if (notes.text.trim().isNotEmpty) 'Notes': notes.text,
      };
  await showTaskForm(
      context,
      TaskForm(
        title: title,
        submitLabel: title,
        contextLabel: '${stock.name} · ${stock.displayId}',
        controllers: [
          quantity,
          notes,
          reason,
          customerFirst,
          customerMiddle,
          customerLast,
          customerContact,
          reference,
          otherPayment
        ],
        shouldAdvance: () => isSale && saleStep == 0,
        advanceLabel: () => 'Continue',
        onAdvance: () => saleStep = 1,
        canGoBack: () => isSale && saleStep > 0,
        onStepBack: (fromReview) {
          if (!fromReview) saleStep = 0;
        },
        validate: () {
          if (isSale && unitPrice == null) {
            return 'Set a selling price on this inventory item before recording a sale.';
          }
          if (isSale &&
              saleStep == 1 &&
              useExistingCustomer &&
              selectedCustomer == null) {
            return 'Choose an existing customer or switch to New customer.';
          }
          return null;
        },
        canSubmit: () {
          final current = ref.read(authControllerProvider).profile;
          return current?.id == initialAccount?.id &&
              current?.hasPermission(isSale
                      ? PermissionKeys.stocksSalesRecord
                      : PermissionKeys.stocksManage) ==
                  true;
        },
        reviewBuilder: () => ReviewDetails(values: summary()),
        builder: (context, form) => TaskFields(children: [
          if (isSale) ...[
            _SaleStepIndicator(
              currentStep: form.isReviewing ? 2 : saleStep,
            ),
          ],
          Text('Available: ${quantityText(available)} ${stock.unit}',
              style: AppTypography.numericSmall),
          if (!isSale || saleStep == 0)
            if (isSale)
              _InventoryField(
                label: 'Batch',
                child: AppSelector<String>(
                  value: targetBatchId,
                  decoration: const InputDecoration(
                    hintText: 'Oldest available',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'fifo',
                      child: Text('Oldest available'),
                    ),
                    for (final batch in stock.batches
                        .where((batch) => batch.remainingQuantity > 0))
                      DropdownMenuItem<String>(
                        value: batch.id,
                        child: Text(_saleBatchLabel(stock, batch.id)),
                      ),
                  ],
                  onChanged: (value) {
                    targetBatchId = value ?? 'fifo';
                    form.changed();
                  },
                ),
              ),
          if (!isSale || saleStep == 0)
            _InventoryField(
              label: task == InventoryTask.adjust
                  ? 'New total quantity (${stock.unit})'
                  : 'Quantity (${stock.unit})',
              required: true,
              child: TextFormField(
                controller: quantity,
                style: AppTypography.numericInput,
                inputFormatters: AppInputFormatters.decimal,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: task == InventoryTask.adjust
                      ? 'e.g., ${quantityText(available)}'
                      : 'e.g., 5',
                ),
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  if (raw.isEmpty) {
                    return task == InventoryTask.adjust
                        ? 'Enter the new quantity.'
                        : 'Enter a quantity.';
                  }
                  final n = double.tryParse(raw);
                  if (n == null || !n.isFinite) {
                    return 'Use numbers only, such as 5 or 2.5.';
                  }
                  if (n < 0) return 'Quantity cannot be negative.';
                  if (task != InventoryTask.adjust && n <= 0) {
                    return 'Enter a quantity greater than zero.';
                  }
                  if ((isSale || task == InventoryTask.issue) &&
                      n > available) {
                    return 'Quantity exceeds available stock.';
                  }
                  if (isSale && targetBatchId != 'fifo') {
                    final batch = stock.batches
                        .where(
                          (batch) => batch.id == targetBatchId,
                        )
                        .firstOrNull;
                    if (batch == null || n > batch.remainingQuantity) {
                      return 'Quantity exceeds the selected batch balance.';
                    }
                  }
                  return null;
                },
              ),
            ),
          if (!isSale || saleStep == 0)
            Text('Resulting balance: ${quantityText(balance())} ${stock.unit}',
                style: AppTypography.numericSmall),
          if (task == InventoryTask.adjust) ...[
            Text(
                'Difference: ${quantityText(getQuantity() - available)} ${stock.unit}',
                style: AppTypography.numericSmall),
            _InventoryField(
              label: 'Reason',
              required: true,
              child: TextFormField(
                controller: reason,
                decoration: const InputDecoration(
                  hintText: 'e.g., Physical count',
                ),
                validator: requiredValue,
              ),
            ),
          ],
          if (task == InventoryTask.receive)
            _InventoryField(
              label: 'Source',
              required: true,
              child: AppSelector<String>(
                  value: source.isEmpty ? null : source,
                  decoration:
                      const InputDecoration(hintText: 'Choose a source'),
                  items: [
                    for (final value in SharedWorkflowChoices.receiptSources)
                      DropdownMenuItem(value: value, child: Text(value))
                  ],
                  validator: (value) =>
                      value == null ? 'Choose a source.' : null,
                  onChanged: (v) {
                    source = v!;
                    form.changed();
                  }),
            ),
          if (task == InventoryTask.issue)
            _InventoryField(
              label: 'Reason',
              required: true,
              child: AppSelector<String>(
                  value: selectedReason.isEmpty ? null : selectedReason,
                  decoration:
                      const InputDecoration(hintText: 'Choose a reason'),
                  items: [
                    for (final value in SharedWorkflowChoices.issueReasons)
                      DropdownMenuItem(value: value, child: Text(value))
                  ],
                  validator: (value) =>
                      value == null ? 'Choose a reason.' : null,
                  onChanged: (v) {
                    selectedReason = v!;
                    form.changed();
                  }),
            ),
          if (task == InventoryTask.issue && stock.batches.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Choose batch'),
              children: [
                AppSelector<String>(
                  value: targetBatchId,
                  decoration:
                      const InputDecoration(hintText: 'Oldest available'),
                  items: [
                    const DropdownMenuItem<String>(
                        value: 'fifo', child: Text('Oldest available')),
                    for (final batch in stock.batches
                        .where((batch) => batch.remainingQuantity > 0))
                      DropdownMenuItem<String>(
                        value: batch.id,
                        child: Text(
                            '${quantityText(batch.remainingQuantity)} ${stock.unit} · ${batch.profileName ?? 'Unknown product'} · ${batch.harvestOn != null ? 'harvested ${DateFormat.yMMMd().format(batch.harvestOn!)}' : 'received ${DateFormat.yMMMd().format(batch.receivedOn)}'}'),
                      ),
                  ],
                  onChanged: (value) {
                    targetBatchId = value ?? 'fifo';
                    form.changed();
                  },
                ),
              ],
            ),
          if (isSale && saleStep == 0) ...[
            _InventoryField(
              label: 'Selling price per ${stock.unit}',
              required: true,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        unitPrice == null
                            ? 'Not set'
                            : CurrencyFormatter.php(unitPrice!),
                        style: AppTypography.numericInput.copyWith(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.lock_outline, size: 18),
                  ],
                ),
              ),
            ),
            Text(
                unitPrice == null
                    ? 'Set the selling price on this item before recording the sale.'
                    : 'Total: ${CurrencyFormatter.php(getQuantity() * unitPrice!)}',
                style: AppTypography.numericSmall),
            _InventoryField(
              label: 'Sale date and time',
              required: true,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(DateFormat.yMMMd().add_jm().format(date),
                    style: AppTypography.numericSmall),
                onPressed: () async {
                  final selected = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)));
                  if (selected == null || !context.mounted) return;
                  final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(date));
                  if (time == null || !context.mounted) return;
                  date = DateTime(selected.year, selected.month, selected.day,
                      time.hour, time.minute);
                  form.changed();
                },
              ),
            ),
          ],
          if (isSale && saleStep == 1) ...[
            Text(
              unitPrice == null
                  ? 'Selling price is not set on this item.'
                  : '${quantityText(getQuantity())} ${stock.unit} × ${CurrencyFormatter.php(unitPrice!)} per ${stock.unit}',
              style: AppTypography.numericSmall,
            ),
            Text(
              'Sale total: ${CurrencyFormatter.php(getQuantity() * (unitPrice ?? 0))}',
              style: AppTypography.numericValue,
            ),
            _InventoryField(
              label: 'Payment method',
              required: true,
              child: AppSelector<String>(
                  value: payment,
                  decoration: const InputDecoration(hintText: 'Choose payment'),
                  items: [
                    for (final value in SharedWorkflowChoices.paymentMethods)
                      DropdownMenuItem(value: value, child: Text(value))
                  ],
                  onChanged: (v) {
                    payment = v!;
                    form.changed();
                  }),
            ),
            if (payment != 'Cash')
              _InventoryField(
                label: 'Transaction ID',
                required: true,
                child: TextFormField(
                  controller: reference,
                  decoration: const InputDecoration(
                    hintText: 'e.g., GCash or bank reference number',
                  ),
                  validator: requiredValue,
                ),
              ),
            if (payment == 'Other')
              _InventoryField(
                label: 'Other payment method',
                required: true,
                child: TextFormField(
                  controller: otherPayment,
                  decoration: const InputDecoration(hintText: 'e.g., Check'),
                  validator: requiredValue,
                ),
              ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('New customer')),
                ButtonSegment(value: true, label: Text('Existing customer')),
              ],
              selected: {useExistingCustomer},
              onSelectionChanged: (selection) {
                useExistingCustomer = selection.first;
                if (!useExistingCustomer) selectedCustomer = null;
                form.changed();
              },
            ),
            if (useExistingCustomer)
              if (existingCustomerLoadError != null) ...[
                Text(existingCustomerLoadError!, style: AppTypography.small),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final customers =
                          await controller.getExistingSaleCustomers();
                      if (!context.mounted) return;
                      existingCustomers = customers;
                      existingCustomerLoadError = null;
                      form.changed();
                    } catch (_) {
                      if (!context.mounted) return;
                      existingCustomerLoadError =
                          'Customer history could not be loaded. Check your connection and try again.';
                      form.changed();
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry customer history'),
                ),
              ] else if (existingCustomers.isEmpty)
                const Text(
                    'No customers with valid contact numbers were found in completed sales.')
              else
                _InventoryField(
                  label: 'Select existing customer',
                  required: true,
                  child: AppSelector<ExistingSaleCustomer>(
                    value: selectedCustomer,
                    decoration: const InputDecoration(
                      hintText: 'Choose a customer from sales history',
                    ),
                    items: [
                      for (final customer in existingCustomers)
                        DropdownMenuItem(
                          value: customer,
                          child: Text('${customer.name} · ${customer.contact}'),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? 'Choose an existing customer.' : null,
                    onChanged: (value) {
                      selectedCustomer = value;
                      form.changed();
                    },
                  ),
                )
            else ...[
              _InventoryField(
                label: 'First name',
                required: true,
                child: TextFormField(
                  controller: customerFirst,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g., Maria'),
                  validator: requiredValue,
                ),
              ),
              _InventoryField(
                label: 'Middle initial',
                suffix: ' (optional)',
                child: TextFormField(
                  controller: customerMiddle,
                  maxLength: 1,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'e.g., R'),
                ),
              ),
              _InventoryField(
                label: 'Last name',
                required: true,
                child: TextFormField(
                  controller: customerLast,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g., Santos'),
                  validator: requiredValue,
                ),
              ),
              _InventoryField(
                label: 'Contact number',
                required: true,
                child: TextFormField(
                  controller: customerContact,
                  keyboardType: TextInputType.phone,
                  inputFormatters: AppInputFormatters.phoneNumber,
                  decoration:
                      const InputDecoration(hintText: 'e.g., 09xx xxx xxxx'),
                  validator: (value) {
                    final requiredError = requiredValue(value);
                    if (requiredError != null) return requiredError;
                    return AppInputFormatters.validateContactNumber(value,
                        required: true);
                  },
                ),
              ),
            ],
            _InventoryField(
              label: 'Notes',
              suffix: ' (optional)',
              child: TextFormField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  hintText: 'e.g., Customer requested morning pickup',
                ),
              ),
            ),
          ],
          if (!isSale)
            _InventoryField(
              label: 'Notes',
              suffix: ' (optional)',
              child: TextFormField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  hintText: 'Add a note about this stock movement',
                ),
              ),
            ),
        ]),
        onReconcile: () =>
            reconcileInventoryWrite(context, controller, stock.id),
        onSubmit: () async {
          final pending = await controller.pendingWriteFor(stock.id);
          if (pending != null) return pending;
          StockModel latest;
          try {
            latest = await controller.refreshStockForReview(stock.id);
          } catch (_) {
            return const ActionOutcome.failure(
                'Could not check current stock. Nothing was submitted. Try again when connected.');
          }
          final quantityChanged = latest.currentQuantity != available;
          final priceChanged = isSale && latest.sellingPrice != unitPrice;
          if (quantityChanged) available = latest.currentQuantity;
          if (priceChanged) {
            unitPrice = latest.sellingPrice;
          }
          if (isSale && targetBatchId != 'fifo') {
            final selectedBatch = latest.batches
                .where((batch) => batch.id == targetBatchId)
                .firstOrNull;
            if (selectedBatch == null ||
                selectedBatch.remainingQuantity < getQuantity()) {
              return const ActionOutcome.failure(
                  'The selected batch changed or no longer has enough stock. Review the updated batch balance before saving.');
            }
          }
          if (quantityChanged || priceChanged) {
            return const ActionOutcome.failure(
                'Stock or its saved selling price changed. Review the updated balance and total before saving.');
          }
          final quantityValue = getQuantity();
          final performer = initialAccount?.fullName ?? 'Current user';
          final error = switch (task) {
            InventoryTask.receive => await controller.stockIn(
                stockId: stock.id,
                quantity: quantityValue,
                supplier: source,
                remarks: notes.text,
                performedBy: performer,
                requestId: requestId),
            InventoryTask.issue => await controller.stockOut(
                stockId: stock.id,
                quantity: quantityValue,
                purpose: selectedReason,
                remarks: notes.text,
                performedBy: performer,
                requestId: requestId,
                batchId: targetBatchId == 'fifo' ? null : targetBatchId),
            InventoryTask.adjust => await controller.adjustStock(
                stockId: stock.id,
                newQuantity: quantityValue,
                reason: reason.text,
                remarks: notes.text,
                performedBy: performer,
                requestId: requestId),
            InventoryTask.sale => await controller.recordSale(RecordSaleRequest(
                stock: latest,
                quantitySold: quantityValue,
                unitPrice: unitPrice!,
                saleDate: date,
                paymentMethod: payment,
                transactionReference: reference.text.trim(),
                otherPaymentMethod: otherPayment.text.trim(),
                submissionId: requestId,
                batchId: targetBatchId == 'fifo' ? null : targetBatchId,
                customerName: selectedCustomer?.name ??
                    [
                      customerFirst.text.trim(),
                      if (customerMiddle.text.trim().isNotEmpty)
                        '${customerMiddle.text.trim()}.',
                      customerLast.text.trim()
                    ].join(' '),
                customerContact:
                    selectedCustomer?.contact ?? customerContact.text.trim(),
                remarks: notes.text.trim())),
          };
          final outcome = ActionOutcome.fromError(error);
          return outcome;
        },
      ));
}

Future<void> showInventoryEditor(
    BuildContext context, WidgetRef ref, StockInventoryController controller,
    {StockModel? stock, bool canEditPricing = true}) async {
  final accountId = ref.read(authControllerProvider).profile?.id;
  final name = TextEditingController(text: stock?.name);
  final quantity = TextEditingController(
      text: stock == null ? '' : quantityText(stock.currentQuantity));
  final minimum = TextEditingController(
      text: stock == null ? '' : quantityText(stock.minimumStockLevel));
  final cost = TextEditingController(text: stock?.unitCost?.toStringAsFixed(2));
  final price =
      TextEditingController(text: stock?.sellingPrice?.toStringAsFixed(2));
  final storageLocations = [...SharedWorkflowChoices.storageLocations];
  final savedLocation = stock?.storageLocation.trim();
  var selectedLocation =
      savedLocation != null && storageLocations.contains(savedLocation)
          ? savedLocation
          : null;
  final notes = TextEditingController(text: stock?.notes ?? '');
  var category = stock?.category ?? StockCategory.leafyVegetables;
  Uint8List? bytes;
  String? imageName;
  String? imageMime;
  String? uncertainCreatedStockId;
  await showTaskForm(
      context,
      TaskForm(
        title: stock == null ? 'Add inventory item' : 'Edit item',
        submitLabel: stock == null ? 'Add item' : 'Save item',
        contextLabel: stock?.displayId,
        controllers: [name, quantity, minimum, cost, price, notes],
        canSubmit: () {
          final user = ref.read(authControllerProvider).profile;
          return user?.id == accountId &&
              user?.hasPermission(PermissionKeys.stocksManage) == true;
        },
        validate: () => stock == null && bytes == null
            ? 'Add the required item photo.'
            : null,
        builder: (context, form) => TaskFields(children: [
          Text('Item information', style: AppTypography.sectionHeading),
          _InventoryField(
            label: 'Item name',
            required: true,
            child: TextFormField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g., Sitaw'),
              validator: requiredValue,
            ),
          ),
          _InventoryField(
            label: 'Category',
            required: true,
            child: AppSelector<StockCategory>(
              value: category,
              decoration: const InputDecoration(hintText: 'Choose a category'),
              items: [
                for (final value in StockCategory.values)
                  DropdownMenuItem(value: value, child: Text(value.label))
              ],
              validator: (value) => value == null ? 'Choose a category.' : null,
              onChanged: (value) {
                category = value!;
                form.changed();
              },
            ),
          ),
          Text('Unit: ${stock?.unit ?? 'kg'}', style: AppTypography.small),
          if (stock == null)
            _InventoryField(
              label: 'Initial quantity (kg)',
              required: true,
              child: TextFormField(
                controller: quantity,
                style: AppTypography.numericInput,
                inputFormatters: AppInputFormatters.decimal,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'e.g., 25'),
                validator: nonnegativeNumber,
              ),
            ),
          _InventoryField(
            label: 'Minimum stock level (${stock?.unit ?? 'kg'})',
            required: true,
            child: TextFormField(
              controller: minimum,
              style: AppTypography.numericInput,
              inputFormatters: AppInputFormatters.decimal,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'e.g., 5'),
              validator: nonnegativeNumber,
            ),
          ),
          Text('Pricing and storage', style: AppTypography.sectionHeading),
          for (final entry in [(cost, 'Unit cost'), (price, 'Selling price')])
            _InventoryField(
              label: entry.$2,
              required: stock == null,
              suffix: stock == null ? null : ' (optional)',
              child: TextFormField(
                controller: entry.$1,
                enabled: canEditPricing,
                style: AppTypography.numericInput,
                inputFormatters: AppInputFormatters.decimal,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'e.g., 45.00'),
                validator: (value) =>
                    stock != null && (value ?? '').trim().isEmpty
                        ? null
                        : nonnegativeNumber(value),
              ),
            ),
          _InventoryField(
            label: 'Storage location',
            required: true,
            child: AppSelector<String>(
              value: selectedLocation,
              decoration: const InputDecoration(
                hintText: 'Choose a storage location',
              ),
              items: [
                for (final value in storageLocations)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
              ],
              validator: (value) => requiredValue(value),
              onChanged: (value) {
                selectedLocation = value;
                form.changed();
              },
            ),
          ),
          _InventoryField(
            label: 'Item notes',
            suffix: ' (optional)',
            child: TextFormField(
              controller: notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                hintText: 'Add details that help identify or store this item',
              ),
            ),
          ),
          if (stock == null) ...[
            _InventoryField(
              label: 'Item photo',
              required: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child:
                          Image.memory(bytes!, height: 160, fit: BoxFit.cover),
                    ),
                  if (bytes != null) const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                        bytes == null ? 'Add item photo' : 'Replace photo'),
                    onPressed: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                          context: context,
                          builder: (context) => SafeArea(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                    ListTile(
                                        leading: const Icon(
                                            Icons.camera_alt_outlined),
                                        title: const Text('Camera'),
                                        onTap: () => Navigator.pop(
                                            context, ImageSource.camera)),
                                    ListTile(
                                        leading: const Icon(
                                            Icons.photo_library_outlined),
                                        title: const Text('Photo library'),
                                        onTap: () => Navigator.pop(
                                            context, ImageSource.gallery)),
                                  ])));
                      if (source == null) return;
                      try {
                        final photo = await ImagePicker()
                            .pickImage(source: source, imageQuality: 80);
                        if (photo == null) return;
                        final data = await photo.readAsBytes();
                        if (!context.mounted) return;
                        if (data.length > SharedWorkflowRules.photoMaxBytes) {
                          form.showError(
                              'Stock photos must be 5 MB or smaller.');
                          return;
                        }
                        bytes = data;
                        imageName = photo.name;
                        imageMime = photo.name.toLowerCase().endsWith('.png')
                            ? 'image/png'
                            : photo.name.toLowerCase().endsWith('.webp')
                                ? 'image/webp'
                                : 'image/jpeg';
                        form.changed();
                      } catch (_) {
                        form.showError(
                            'Could not open the photo. Check camera or photo access in your phone settings and try again.');
                      }
                    },
                  ),
                  if (bytes != null)
                    TextButton.icon(
                      onPressed: () {
                        bytes = null;
                        form.changed();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove photo'),
                    ),
                ],
              ),
            ),
          ],
        ]),
        onSubmit: () async {
          if (stock != null) {
            final pending = await controller.pendingWriteFor(stock.id);
            if (pending != null) return pending;
          }
          final updated = stock?.copyWith(
              name: name.text.trim(),
              category: category,
              minimumStockLevel: double.parse(minimum.text),
              unitCost:
                  canEditPricing ? double.tryParse(cost.text) : stock.unitCost,
              sellingPrice: canEditPricing
                  ? double.tryParse(price.text)
                  : stock.sellingPrice,
              storageLocation: selectedLocation?.trim() ?? '',
              supplier: stock.supplier,
              notes: notes.text);
          if (updated != null) {
            return ActionOutcome.fromError(
                await controller.updateStock(updated));
          }
          final outcome = ActionOutcome.fromError(await controller.createStock(
              StockModel(
                id: 'new',
                displayId: 'STK-000',
                name: name.text.trim(),
                category: category,
                currentQuantity: double.parse(quantity.text),
                unit: 'kg',
                storageLocation: selectedLocation?.trim() ?? '',
                minimumStockLevel: double.parse(minimum.text),
                unitCost: double.parse(cost.text),
                sellingPrice: double.parse(price.text),
                supplier: 'Farm Harvest',
                dateAdded: DateTime.now(),
                lastUpdated: DateTime.now(),
                notes: notes.text,
                transactions: const [],
              ),
              imageUpload: StockImageUpload(
                  bytes: bytes!, fileName: imageName!, mimeType: imageMime!)));
          if (outcome.status == ActionStatus.uncertain) {
            final pending = (await controller.uncertainWrites())
                .values
                .where((write) =>
                    write.action == 'Create item' &&
                    write.attempted == name.text.trim())
                .map((write) => write.stockId)
                .toList();
            uncertainCreatedStockId = pending.isEmpty ? null : pending.first;
          }
          return outcome;
        },
        onReconcile: () => stock != null
            ? reconcileInventoryWrite(context, controller, stock.id)
            : uncertainCreatedStockId == null
                ? Future.value(const ActionOutcome.unknown(
                    'Refresh the inventory list to locate the item before resolving this write.'))
                : reconcileInventoryWrite(
                    context, controller, uncertainCreatedStockId!),
      ));
}

Future<ActionOutcome> reconcileInventoryWrite(BuildContext context,
    StockInventoryController controller, String stockId) async {
  final pending = (await controller.uncertainWrites())[stockId];
  if (pending == null) {
    return const ActionOutcome(
        ActionStatus.confirmed, 'No unresolved inventory write remains.');
  }
  if (pending.submissionId != null && pending.operation != null) {
    Map<String, dynamic>? committed;
    try {
      committed = await controller.checkPendingOperation(stockId);
    } catch (_) {
      return const ActionOutcome.unknown(
        'The server could not confirm whether this change was saved. Keep it unresolved and check again when connected.',
      );
    }
    if (committed != null) {
      await controller.resolveUncertainWrite(stockId);
      return const ActionOutcome(
        ActionStatus.confirmed,
        'The server confirmed this change was saved. No second write was sent.',
      );
    }
  }
  StockModel? latest;
  try {
    latest = await controller.refreshStockForReview(stockId);
  } catch (_) {
    // Deletion may have removed the item. Keep the write unresolved until the
    // operator explicitly checks the authoritative inventory state.
  }
  if (!context.mounted) {
    return const ActionOutcome.unknown(
        'This screen closed before the inventory change could be checked. Please check the item record before trying again.');
  }
  final choice = await Navigator.of(context)
      .push<_InventoryReconciliationChoice>(
          MaterialPageRoute<_InventoryReconciliationChoice>(
              builder: (_) => _InventoryReconciliationPage(
                  write: pending, latest: latest)));
  if (choice == null) {
    return const ActionOutcome.unknown(
        'The inventory change could not be confirmed. Check the item record before trying again.');
  }
  if (choice == _InventoryReconciliationChoice.retry) {
    final error = await controller.retrySavedOperation(stockId);
    if (error != null) return ActionOutcome.unknown(error);
    return const ActionOutcome(ActionStatus.confirmed,
        'The saved action was confirmed. Inventory has been refreshed.');
  }
  if (choice == _InventoryReconciliationChoice.found) {
    await controller.resolveUncertainWrite(stockId);
    return const ActionOutcome(ActionStatus.confirmed,
        'Existing operation confirmed. No second write was sent.');
  }
  return const ActionOutcome.unknown(
      'Keep checking this saved action before submitting another change.');
}

enum _InventoryReconciliationChoice { found, retry }

class _InventoryReconciliationPage extends StatelessWidget {
  const _InventoryReconciliationPage(
      {required this.write, required this.latest});
  final UncertainInventoryWrite write;
  final StockModel? latest;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Check transaction')),
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('${write.action}: ${write.attempted}',
              style: AppTypography.sectionHeading),
          Text(
              'Attempted ${DateFormat.yMMMd().add_jm().format(write.createdAt)}'),
          if (write.reference != null && write.reference!.isNotEmpty)
            Text('Payment reference: ${write.reference}'),
          const SizedBox(height: 16),
          Text(latest == null
              ? 'The item is not in the refreshed inventory list.'
              : 'Current balance: ${quantityText(latest!.currentQuantity)} ${latest!.unit}'),
          const SizedBox(height: 16),
          if (latest?.transactions.isNotEmpty == true)
            StockTransactionTimeline(
              transactions: latest!.transactions.take(20).toList(),
              unit: latest!.unit,
            )
          else
            const Text(
                'No transactions are available in the refreshed record.'),
          const Text(
              'Check the time and quantity against the change you tried to make. The app will not repeat the change automatically.'),
        ])),
        Padding(
            padding: const EdgeInsets.all(16),
            child: TaskFields(children: [
              FilledButton(
                  onPressed: () => Navigator.pop(
                      context, _InventoryReconciliationChoice.found),
                  child: const Text('I found this operation in the records')),
              if (write.operation != null &&
                  write.submissionId != null &&
                  write.payload != null)
                OutlinedButton(
                    onPressed: () => Navigator.pop(
                        context, _InventoryReconciliationChoice.retry),
                    child: const Text('Retry this saved action')),
            ])),
      ])));
}

class _SaleStepIndicator extends StatelessWidget {
  const _SaleStepIndicator({required this.currentStep});

  final int currentStep;

  static const _steps = ['Sale details', 'Customer', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var index = 0; index < _steps.length - 1; index++)
                    Positioned(
                      left: constraints.maxWidth * (index + .5) / _steps.length,
                      top: 13,
                      width: constraints.maxWidth / _steps.length,
                      child: Container(
                        height: 2,
                        color: currentStep > index
                            ? AppColors.primaryGreen
                            : AppColors.primaryBorder,
                      ),
                    ),
                  Row(
                    children: [
                      for (var index = 0; index < _steps.length; index++)
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: index <= currentStep
                                    ? AppColors.primaryGreen
                                    : AppColors.secondaryBackground,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: index <= currentStep
                                      ? AppColors.primaryGreen
                                      : AppColors.primaryBorder,
                                ),
                              ),
                              child: index < currentStep
                                  ? const Icon(Icons.check,
                                      size: 17, color: Colors.white)
                                  : Text(
                                      '${index + 1}',
                                      style: AppTypography.small.copyWith(
                                        color: index == currentStep
                                            ? Colors.white
                                            : AppColors.secondaryText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (var index = 0; index < _steps.length; index++)
                  Expanded(
                    child: Text(
                      _steps[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: index <= currentStep
                            ? AppColors.primaryGreen
                            : AppColors.secondaryText,
                        fontWeight: index == currentStep
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryField extends StatelessWidget {
  const _InventoryField({
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
