import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/rental.dart';
import '../utils/app_exception.dart';
import 'contract_pdf.dart';

// Sender account, given at run time so no password lives in the code:
//   flutter run --dart-define=MAIL_USER=you@gmail.com --dart-define=MAIL_PASS=<gmail app password>
// shortcut: the login ships inside the app binary; for a real release move
// sending to a small server and call that instead.
const _mailUser = String.fromEnvironment('MAIL_USER');
const _mailPass = String.fromEnvironment('MAIL_PASS');

/// Sends the contract PDF to [to] without any user action. Needs internet.
/// Throws [AppException] with a readable message when it cannot send.
Future<void> emailContract(RentalView v, String to) async {
  if (_mailUser.isEmpty || _mailPass.isEmpty) {
    throw const AppException(
        'E-mail non configuré : lancez l\'app avec MAIL_USER et MAIL_PASS.');
  }
  final file = File('${(await getTemporaryDirectory()).path}/${contractFileName(v)}');
  await file.writeAsBytes(await buildContractPdf(v));
  final message = Message()
    ..from = Address(_mailUser, 'AutoRent')
    ..recipients.add(to)
    ..subject = contractEmailSubject(v)
    ..text = contractEmailBody(v)
    ..attachments = [FileAttachment(file)];
  try {
    await send(message, gmail(_mailUser, _mailPass));
  } on MailerException {
    throw const AppException(
        'Envoi impossible : vérifiez la connexion et le compte e-mail.');
  } on SocketException {
    throw const AppException('Envoi impossible : pas de connexion internet.');
  } finally {
    if (await file.exists()) await file.delete();
  }
}
