            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 500;
                final logoWidget = Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _logoBase64 != null && _logoBase64!.isNotEmpty
                        ? Image.memory(
                            base64Decode(_logoBase64!.contains(',') ? _logoBase64!.split(',').last : _logoBase64!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(BusinessIconHelper.getIcon(_selectedIcon), color: brandColor, size: 30),
                          )
                        : Icon(BusinessIconHelper.getIcon(_selectedIcon), color: brandColor, size: 30),
                  ),
                );
                final infoWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _logoBase64 != null ? 'Logotipo propio activo' : 'Sin logo cargado (usando ícono)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _logoBase64 != null
                          ? 'Este logo se mostrará en el sidebar, encabezados y tickets.'
                          : 'Sube el archivo PNG, JPG o WebP de tu empresa.',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                );
                final actionsWidget = Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: Text(_logoBase64 != null ? 'Cambiar' : 'Subir Logo'),
                      onPressed: _seleccionarLogo,
                    ),
                    if (_logoBase64 != null) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Quitar', style: TextStyle(fontSize: 12)),
                        onPressed: _eliminarLogo,
                      ),
                    ],
                  ],
                );
                if (isSmall) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          logoWidget,
                          const SizedBox(width: 14),
                          Expanded(child: infoWidget),
                        ],
                      ),
                      const SizedBox(height: 14),
                      actionsWidget,
                    ],
                  );
                }
                return Row(
                  children: [
                    logoWidget,
                    const SizedBox(width: 16),
                    Expanded(child: infoWidget),
                    const SizedBox(width: 12),
                    actionsWidget,
                  ],
                );
              },
            )
          const SizedBox(height: 20),

          const Text(
            'O elige un ícono representativo de giro comercial:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width < 500 ? 3 : 6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: BusinessIconHelper.icons.length,
            itemBuilder: (context, idx) {
              final entry = BusinessIconHelper.icons.entries.elementAt(idx);
              final isSelected = _selectedIcon == entry.key && _logoBase64 == null;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIcon = entry.key;
                    _logoBase64 = null; // Si elige un ícono rápido, reemplaza el logo
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected ? brandColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? brandColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      entry.value,
                      color: isSelected ? brandColor : context.textMuted,
                      size: 26,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorPaletteCard(Color brandColor) {
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.palette_rounded, color: brandColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Color de Marca del Sistema', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Personaliza los botones, resaltados y barras de navegación', style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _coloresDisponibles.map((c) {
              final isSelected = _colorPrimario.toUpperCase() == (c['hex'] as String).toUpperCase();
              final color = c['color'] as Color;

              return GestureDetector(
                onTap: () => setState(() => _colorPrimario = c['hex'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? color : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyDetailsCard(Color brandColor) {
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.business_rounded, color: brandColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datos de tu Negocio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Información visible para ventas, clientes y tickets', style: TextStyle(fontSize: 12, color: context.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nombreCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nombre Comercial',
              prefixIcon: Icon(Icons.storefront_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _monedaCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Símbolo Moneda (\$ o MXN)',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextFormField(
                  controller: _telefonoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de Contacto',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _direccionCtrl,
            decoration: const InputDecoration(
              labelText: 'Dirección o Sucursal',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _mensajeCtrl,
            decoration: const InputDecoration(
              labelText: 'Mensaje de agradecimiento en recibos',
              prefixIcon: Icon(Icons.receipt_long_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

