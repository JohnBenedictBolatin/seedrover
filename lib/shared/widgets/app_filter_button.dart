import 'package:flutter/material.dart';

class AppFilterButton extends StatelessWidget {
  const AppFilterButton(
      {required this.label,
      required this.icon,
      required this.options,
      required this.onSelected,
      super.key});
  final String label;
  final IconData icon;
  final List<String> options;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: Icon(icon, size: 20),
        label: Text(label),
        onPressed: () async {
          var query = '';
          final selected = await showModalBottomSheet<int>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => StatefulBuilder(
                  builder: (context, setState) => Padding(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.viewInsetsOf(context).bottom),
                        child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.sizeOf(context).height * .7),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(title: Text(label)),
                                  if (options.length > 8)
                                    Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: TextField(
                                            decoration: const InputDecoration(
                                                labelText: 'Search options',
                                                prefixIcon: Icon(Icons.search)),
                                            onChanged: (value) =>
                                                setState(() => query = value))),
                                  Flexible(
                                      child:
                                          ListView(shrinkWrap: true, children: [
                                    for (var i = 0; i < options.length; i++)
                                      if (options[i]
                                          .toLowerCase()
                                          .contains(query.toLowerCase()))
                                        ListTile(
                                            title: Text(options[i]),
                                            selected: options[i] == label,
                                            trailing: options[i] == label
                                                ? const Icon(Icons.check)
                                                : null,
                                            onTap: () =>
                                                Navigator.pop(context, i)),
                                  ])),
                                ])),
                      )));
          if (selected != null && context.mounted) onSelected(selected);
        },
      );
}
