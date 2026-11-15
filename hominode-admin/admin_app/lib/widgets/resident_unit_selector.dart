import 'package:flutter/material.dart';

class ResidentBuildingOption {
  final String id;
  final String name;
  const ResidentBuildingOption({required this.id, required this.name});
}

class ResidentUnitOption {
  final String buildingId;
  final String flatId;
  final String label;
  final String buildingName;
  const ResidentUnitOption({
    required this.buildingId,
    required this.flatId,
    required this.label,
    this.buildingName = '',
  });
}

int compareResidentUnitLabels(String a, String b) {
  final chunks = RegExp(r'\d+|\D+');
  final left = chunks.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final right = chunks.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < left.length && i < right.length; i++) {
    final x = BigInt.tryParse(left[i]);
    final y = BigInt.tryParse(right[i]);
    final order = x != null && y != null
        ? x.compareTo(y)
        : left[i].compareTo(right[i]);
    if (order != 0) return order;
  }
  final order = left.length.compareTo(right.length);
  return order != 0 ? order : a.compareTo(b);
}

/// Both selection paths use the same already-filtered, community-scoped options.
class ResidentUnitSelector extends StatefulWidget {
  final List<ResidentBuildingOption> buildings;
  final List<ResidentUnitOption> units;
  final String? buildingId;
  final ResidentUnitOption? unit;
  final void Function(String?, ResidentUnitOption?) onChanged;
  final bool disabled;
  final bool loading;
  final String? loadError;
  final String? Function()? unitError;
  const ResidentUnitSelector({
    super.key,
    required this.buildings,
    required this.units,
    required this.buildingId,
    required this.unit,
    required this.onChanged,
    this.disabled = false,
    this.loading = false,
    this.loadError,
    this.unitError,
  });

  @override
  State<ResidentUnitSelector> createState() => _ResidentUnitSelectorState();
}

class _ResidentUnitSelectorState extends State<ResidentUnitSelector> {
  final _search = TextEditingController();
  final _suggestionsScroll = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _suggestionsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buildings = [...widget.buildings]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final names = {for (final b in buildings) b.id: b.name};
    final units =
        widget.units.where((u) => names.containsKey(u.buildingId)).toList()
          ..sort((a, b) {
            final buildingOrder = names[a.buildingId]!.toLowerCase().compareTo(
              names[b.buildingId]!.toLowerCase(),
            );
            return buildingOrder != 0
                ? buildingOrder
                : compareResidentUnitLabels(a.label, b.label);
          });
    final buildingId = names.containsKey(widget.buildingId)
        ? widget.buildingId
        : null;
    final filtered = units.where((u) => u.buildingId == buildingId).toList();
    final selected = filtered
        .where((u) => u.flatId == widget.unit?.flatId)
        .firstOrNull;
    final matches = units
        .where((u) => u.label.toLowerCase().contains(_query))
        .toList();
    final enabled =
        !widget.disabled && !widget.loading && widget.loadError == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('resident-building'),
          initialValue: buildingId,
          isExpanded: true,
          menuMaxHeight: 280,
          decoration: InputDecoration(
            labelText: 'Building',
            helperText:
                widget.loadError ??
                (widget.loading
                    ? 'Loading buildings and units…'
                    : buildings.isEmpty
                    ? 'No buildings available'
                    : null),
          ),
          items: buildings
              .map(
                (b) => DropdownMenuItem(
                  value: b.id,
                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: enabled && buildings.isNotEmpty
              ? (id) => widget.onChanged(id, null)
              : null,
          validator: (value) => value == null ? 'Select a building.' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ResidentUnitOption>(
          key: const ValueKey('resident-unit'),
          initialValue: selected,
          isExpanded: true,
          menuMaxHeight: 280,
          decoration: InputDecoration(
            labelText: 'Unit',
            helperText: buildingId == null
                ? 'Select a building first'
                : filtered.isEmpty
                ? 'No eligible units in this building'
                : null,
          ),
          items: filtered
              .map(
                (u) => DropdownMenuItem(
                  value: u,
                  child: Text(u.label, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: enabled && buildingId != null && filtered.isNotEmpty
              ? (unit) => widget.onChanged(buildingId, unit)
              : null,
          validator: (value) =>
              widget.unitError?.call() ??
              (value == null || !filtered.contains(value)
                  ? 'Select an eligible unit.'
                  : null),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('resident-unit-search'),
          controller: _search,
          enabled: enabled && units.isNotEmpty,
          decoration: const InputDecoration(
            labelText: 'Search units across all buildings',
            hintText: 'Enter a unit number or label',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        if (_query.isNotEmpty) ...[
          if (matches.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No matching eligible units'),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Scrollbar(
                controller: _suggestionsScroll,
                child: ListView.builder(
                  key: const ValueKey('resident-unit-suggestions'),
                  controller: _suggestionsScroll,
                  shrinkWrap: true,
                  primary: false,
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final unit = matches[index];
                    return ListTile(
                      key: ValueKey('resident-unit-result-${unit.flatId}'),
                      title: Text('${names[unit.buildingId]} · ${unit.label}'),
                      onTap: enabled
                          ? () {
                              widget.onChanged(unit.buildingId, unit);
                              _search.clear();
                              setState(() => _query = '');
                              FocusScope.of(context).unfocus();
                            }
                          : null,
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }
}
