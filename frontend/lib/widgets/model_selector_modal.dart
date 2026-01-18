import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ModelSelectorModal extends StatefulWidget {
  final Function(String) onModelSelected;

  const ModelSelectorModal({super.key, required this.onModelSelected});

  @override
  State<ModelSelectorModal> createState() => _ModelSelectorModalState();
}

class _ModelSelectorModalState extends State<ModelSelectorModal> {
  String _searchQuery = "";
  final List<Map<String, String>> _models = [
    {'id': 'krypton', 'name': 'Krypton', 'description': 'High-performance default assistant'},
    {'id': 'chatGpt', 'name': 'ChatGPT', 'description': 'Advanced reasoning and general knowledge'},
    {'id': 'gemini', 'name': 'Gemini 3 Flash Preview', 'description': 'Multimodal understanding and generation'},
    {'id': 'groq', 'name': 'Groq', 'description': 'Ultra-low latency fast inference'},
    {'id': 'krypton_agent', 'name': 'Krypton Agent', 'description': 'Autonomous task execution with tools'},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredModels = _models.filter((model) {
      final query = _searchQuery.toLowerCase();
      return model['name']!.toLowerCase().contains(query) ||
             model['description']!.toLowerCase().contains(query);
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2D2D2D)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.psychology, color: Color(0xFFA3A3A3), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Select Model',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFF5F5F5),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFA3A3A3),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF2D2D2D)),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0x80262626),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: GoogleFonts.inter(color: const Color(0xFFF5F5F5), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search models...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFA3A3A3), size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
            ),

            // List
            Expanded(
              child: filteredModels.isEmpty
                  ? Center(
                      child: Text(
                        'No models found.',
                        style: GoogleFonts.inter(color: const Color(0xFFA3A3A3), fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: filteredModels.length,
                      itemBuilder: (context, index) {
                        final model = filteredModels[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: InkWell(
                            onTap: () {
                              widget.onModelSelected(model['id']!);
                              Navigator.of(context).pop();
                            },
                            hoverColor: const Color(0xFF2D2D2D),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      model['description']!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFF5F5F5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D2D2D),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF404040)),
                                    ),
                                    child: Text(
                                      model['name']!,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFF5F5F5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

extension ListFilter<E> on List<E> {
  List<E> filter(bool Function(E) test) => where(test).toList();
}
