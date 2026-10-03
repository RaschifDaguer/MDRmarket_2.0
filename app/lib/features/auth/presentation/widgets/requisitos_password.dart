import 'package:flutter/material.dart';

/// Reglas de contraseña (las mismas que exige la API): mínimo 8 caracteres,
/// una mayúscula, una minúscula y un número.
class ReglasPassword {
  ReglasPassword._();

  static bool largo(String p) => p.length >= 8;
  static bool mayuscula(String p) => RegExp(r'\p{Lu}', unicode: true).hasMatch(p);
  static bool minuscula(String p) => RegExp(r'\p{Ll}', unicode: true).hasMatch(p);
  static bool numero(String p) => RegExp(r'[0-9]').hasMatch(p);
  static bool cumple(String p) => largo(p) && mayuscula(p) && minuscula(p) && numero(p);
}

/// Lista que se va marcando mientras la persona escribe la contraseña.
class RequisitosPassword extends StatelessWidget {
  const RequisitosPassword({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Requisito('Mínimo 8 caracteres', ReglasPassword.largo(password)),
        _Requisito('Una letra mayúscula', ReglasPassword.mayuscula(password)),
        _Requisito('Una letra minúscula', ReglasPassword.minuscula(password)),
        _Requisito('Un número', ReglasPassword.numero(password)),
      ],
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito(this.texto, this.cumplido);

  final String texto;
  final bool cumplido;

  @override
  Widget build(BuildContext context) {
    final color = cumplido ? Colors.green.shade700 : Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(cumplido ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: color),
          const SizedBox(width: 8),
          Text(texto, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
