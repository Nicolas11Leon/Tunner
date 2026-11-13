import 'package:flutter/material.dart';
import 'modular_rack_viewmodel.dart';
import '../../instrument/domain/universal_instrument_definition.dart';
import '../../instrument/domain/universal_instrument_taxonomy.dart';

/// Modal de búsqueda y selección de instrumentos con taxonomía universal y filtrado rápido.
class UniversalInstrumentSearchModal extends StatefulWidget {
  final ModularRackViewModel viewModel;

  const UniversalInstrumentSearchModal({super.key, required this.viewModel});

  static void show(BuildContext context, ModularRackViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UniversalInstrumentSearchModal(viewModel: viewModel),
    );
  }

  @override
  State<UniversalInstrumentSearchModal> createState() => _UniversalInstrumentSearchModalState();
}

class _UniversalInstrumentSearchModalState extends State<UniversalInstrumentSearchModal> {
  String _searchQuery = '';
  HornbostelSachsCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    // Filtrar catálogo por texto y categoría
    var results = UniversalInstrumentDefinition.search(_searchQuery);
    if (_selectedCategory != null) {
      results = results.where((i) => i.category == _selectedCategory).toList();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.library_music, color: Color(0xFF38BDF8), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'CATÁLOGO UNIVERSAL DE INSTRUMENTOS',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Busca por nombre, taxonomía Hornbostel-Sachs o identificador universal.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),

          // Campo de búsqueda universal
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar (ej: saxo, guitarra, marimba, congas, C4)...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 10),

          // Filtros de categoría Hornbostel-Sachs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                  selectedColor: const Color(0xFF38BDF8),
                  labelStyle: TextStyle(
                    color: _selectedCategory == null ? Colors.black : Colors.white,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                ...HornbostelSachsCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      label: Text(cat.displayName.split('(').first.trim()),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = isSelected ? null : cat),
                      selectedColor: const Color(0xFF38BDF8),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lista de resultados
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final inst = results[index];
                final isCurrent = viewModel.activeInstrument.universalId == inst.universalId;
                final primaryColor = inst.visualProfile.primaryAccentColor;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isCurrent
                        ? primaryColor.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isCurrent ? primaryColor : Colors.white12,
                        width: isCurrent ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: inst.visualProfile.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                      ),
                      alignment: Alignment.center,
                      child: Text(inst.visualProfile.smuflGlyph, style: const TextStyle(fontSize: 22)),
                    ),
                    title: Text(
                      inst.displayName,
                      style: TextStyle(
                        color: isCurrent ? primaryColor : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          inst.universalId,
                          style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${inst.subfamily.displayName} • ${inst.isTransposing ? "Transposición: ${inst.transpositionSemitones} sem" : "Do Concierto"} • ${inst.acousticRange.minFrequencyHz.toStringAsFixed(1)} - ${inst.acousticRange.maxFrequencyHz.toStringAsFixed(1)} Hz',
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.check_circle, color: primaryColor, size: 22)
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                            onPressed: () {
                              viewModel.selectInstrument(inst);
                              Navigator.pop(context);
                            },
                          ),
                    onTap: () {
                      viewModel.selectInstrument(inst);
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
              },
            ),
          ),
        ],
      ),
    );
  }
}
