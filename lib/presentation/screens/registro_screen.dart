import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;
      final client = Supabase.instance.client;

      // 1. Validar si el superadmin ya le creó un perfil pendiente con este correo
      final profileCheck = await client.from('profiles').select().eq('email', email).maybeSingle();
      if (profileCheck == null) {
        AppToast.showError(context, 'Este correo no está registrado. Pídele al administrador que cree tu empresa.');
        setState(() => _isLoading = false);
        return;
      }

      // 2. Registrar en Supabase Auth
      final authRes = await client.auth.signUp(email: email, password: password);
      final user = authRes.user;
      
      if (user != null) {
        // 3. Vincular el perfil pendiente con el nuevo ID real
        await client.from('profiles').update({'id': user.id}).eq('email', email);
        
        AppToast.showSuccess(context, 'Cuenta activada correctamente.');
        if (mounted) Navigator.pop(context); // Regresa al login
      } else {
        AppToast.showError(context, 'No se pudo crear la cuenta en Auth.');
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Activar Cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Activa tu acceso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Ingresa el correo con el que te registraron y elige tu contraseña.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email)),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          labelText: 'Elige tu Contraseña', 
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          )
                        ),
                        validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : const Text('Activar Cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
