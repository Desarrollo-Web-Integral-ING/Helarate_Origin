import os
import re

path = r'C:\Users\bhleo\Desktop\Personal Projects\New folder\nevero_app\lib\presentation\screens\ventas_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# Fix imports
if 'import \'dart:io\';' in text:
    text = text.replace('import \'dart:io\';', 'import \'dart:io\' as io;\nimport \'package:flutter/foundation.dart\';')

def replacer(match):
    return """
  Widget _buildProductosTab() {
    if (_productos.isEmpty) {
      return const Center(
        child: Text('No hay productos a la venta.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _productos.length,
            itemBuilder: (context, index) {
              final p = _productos[index];
              final cantidad = _getCantidad(p);
              final nombreCompleto = '${p.nombre}${p.sabor != null && p.sabor!.isNotEmpty ? " - " + p.sabor! : ""}';
              final bool hasImage = p.imagenPath != null && p.imagenPath!.isNotEmpty;
              final isUrl = hasImage && p.imagenPath!.startsWith('http');

              Widget imageWidget = _buildPlaceholder();
              if (hasImage) {
                if (isUrl) {
                  imageWidget = Image.network(p.imagenPath!, fit: BoxFit.cover, errorBuilder: (c,e,s) => _buildPlaceholder());
                } else if (!kIsWeb) {
                  imageWidget = Image.file(io.File(p.imagenPath!), fit: BoxFit.cover, errorBuilder: (c,e,s) => _buildPlaceholder());
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: cantidad > 0 ? AppTheme.primary.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: cantidad > 0 ? 1 : 0,
                    ),
                  ],
                  border: Border.all(
                    color: cantidad > 0 ? AppTheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    // Imagen a la izquierda
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: imageWidget,
                      ),
                    ),
                    
                    // Contenido en el centro y controles a la derecha
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombreCompleto,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _fmt.format(p.precioVenta),
                                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Controles de cantidad
                            if (cantidad > 0)
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, color: AppTheme.primary, size: 20),
                                      onPressed: () => _updateCart(p, -1),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    ),
                                    Text(
                                      cantidad.toStringAsFixed(0),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: AppTheme.primary, size: 20),
                                      onPressed: () => _updateCart(p, 1),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                onPressed: () => _updateCart(p, 1),
                                child: const Text('Agregar'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _buildBottomCartSummary(),
      ],
    );
  }"""

text = re.sub(r'Widget _buildProductosTab\(\) \{.*?\n  Widget _buildPlaceholder\(\)', replacer, text, flags=re.DOTALL)

# Because we removed _buildPlaceholder in the regex match, we need to add it back
text = text.replace('  Widget _buildBottomCartSummary() {', '''  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(Icons.image, color: Colors.grey.shade300, size: 40),
      ),
    );
  }

  Widget _buildBottomCartSummary() {''')

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)