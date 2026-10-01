import 'package:flutter/material.dart';

/// Form-field selector with a readable, searchable sheet on every module.
class AppSelector<T> extends FormField<T> {
  AppSelector({
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    T? value,
    InputDecoration decoration = const InputDecoration(),
    Color? dropdownColor,
    super.validator,
    super.key,
  }) : super(
          initialValue: value,
          enabled: onChanged != null,
          builder: (field) {
            final selected = items.where((item) => item.value == field.value);
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onChanged == null
                  ? null
                  : () async {
                      var query = '';
                      final result = await showModalBottomSheet<T>(
                        context: field.context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (context) =>
                            StatefulBuilder(builder: (context, setState) {
                          final filtered = items.where((item) {
                            final label = item.child is Text
                                ? (item.child as Text).data ?? ''
                                : item.value.toString();
                            return label
                                .toLowerCase()
                                .contains(query.toLowerCase());
                          }).toList();
                          return Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.viewInsetsOf(context).bottom),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.sizeOf(context).height * .7),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                        title: Text(decoration.labelText ??
                                            decoration.hintText ??
                                            'Choose an option')),
                                    if (items.length > 8)
                                      Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: TextField(
                                            decoration: const InputDecoration(
                                                labelText: 'Search options',
                                                prefixIcon: Icon(Icons.search)),
                                            onChanged: (value) =>
                                                setState(() => query = value),
                                          )),
                                    Flexible(
                                        child: ListView(
                                            shrinkWrap: true,
                                            children: [
                                          if (filtered.isEmpty)
                                            const ListTile(
                                                title: Text(
                                                    'No matching options')),
                                          for (final item in filtered)
                                            ListTile(
                                              title: item.child,
                                              enabled: item.enabled,
                                              selected:
                                                  item.value == field.value,
                                              trailing:
                                                  item.value == field.value
                                                      ? const Icon(Icons.check)
                                                      : null,
                                              onTap: () => Navigator.pop(
                                                  context, item.value),
                                            ),
                                        ])),
                                  ]),
                            ),
                          );
                        }),
                      );
                      if (result != null && field.mounted) {
                        field.didChange(result);
                        onChanged(result);
                      }
                    },
              child: InputDecorator(
                decoration: decoration.copyWith(
                    errorText: field.errorText,
                    enabled: onChanged != null,
                    suffixIcon: const Icon(Icons.expand_more),
                    hintText: decoration.hintText ?? 'Choose an option'),
                isEmpty: selected.isEmpty,
                child: selected.isEmpty
                    ? const SizedBox.shrink()
                    : selected.first.child,
              ),
            );
          },
        );
}
