import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/rental.dart';
import '../utils/formatters.dart';
import '../utils/ui_helpers.dart';
import 'contract_pdf.dart';

/// WhatsApp gives apps no way to send a file silently, so this is two taps:
/// open the customer's chat with a ready message, then attach the PDF.
Future<void> offerWhatsAppContract(
    BuildContext context, RentalView v, String phone) {
  final name = v.clientName.split(' ').first;
  final message = 'Bonjour $name, voici votre contrat de location n° ${v.rental.id} : '
      '${v.vehicleLabel}, du ${formatDate(v.rental.startDate)} au '
      '${formatDate(v.rental.endDate)}, total ${formatMoney(v.rental.totalPrice)}. '
      'Le contrat PDF est joint.';

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Envoyer le contrat sur WhatsApp'),
      content: const Text(
          '1. Ouvrez la discussion avec le client.\n'
          '2. Revenez ici et joignez le PDF.'),
      actions: [
        TextButton(
          onPressed: () async {
            final ok = await launchUrl(_chatUri(phone, message),
                mode: LaunchMode.externalApplication);
            if (!ok && ctx.mounted) {
              showSnack(ctx, 'WhatsApp est introuvable sur ce téléphone',
                  kind: SnackKind.error);
            }
          },
          child: const Text('1. Ouvrir WhatsApp'),
        ),
        TextButton(
          onPressed: () => shareContractPdf(v),
          child: const Text('2. Joindre le PDF'),
        ),
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Terminer')),
      ],
    ),
  );
}

// shortcut: 8-digit numbers are assumed Tunisian (+216), other formats must
// already include the country code; add a country picker if clients are foreign.
Uri _chatUri(String phone, String message) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 8) digits = '216$digits';
  return Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
}
