import os
import re

path = r'C:\Users\bhleo\Desktop\Personal Projects\New folder\nevero_app\lib\presentation\screens\ventas_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

def replacer(match):
    return """  Widget _buildTiendaTab() {
    if (_productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text(
              'No hay productos registrados para venta.\\nAgrega productos en el Inventario primero.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
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
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: imageWidget,
                      ),
                    ),
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

text = re.sub(r'  Widget _buildTiendaTab\(\) \{.*?\n        _buildBottomCartSummary\(\),\n      \],\n    \);\n  \}', replacer, text, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
