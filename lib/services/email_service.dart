import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static final String _username = 'pakbondapp@gmail.com';
  static final String _password = 'bdlq qukv zazm lajz';
  static final SmtpServer _smtpServer = gmail(_username, _password);

  static Future<bool> sendApprovalEmail({
    required String toEmail,
    required String userName,
  }) async {
    try {
      final message = Message()
        ..from = Address(_username, 'Pakbond Admin')
        ..recipients.add(toEmail)
        ..subject = 'Congratulations! Your Pakbond Account is Approved'
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { padding: 20px; background: #f9f9f9; border: 1px solid #ddd; }
    .button { background: #4CAF50; color: white; padding: 12px 25px; text-decoration: none; border-radius: 5px; display: inline-block; margin-top: 20px; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Account Approved!</h1>
    </div>
    <div class="content">
      <h2>Welcome to Pakbond, $userName!</h2>
      <p>We are pleased to inform you that your account has been <strong style="color: #4CAF50;">approved</strong> by the admin.</p>

      <h3>Next Steps:</h3>
      <ol>
        <li>Open the Pakbond app</li>
        <li>Login with your email and password</li>
        <li>Enter your 4-digit PIN (the one you set during registration)</li>
        <li>Start checking prize bonds!</li>
      </ol>

      <p><strong>Default PIN:</strong> Use the PIN you created during registration</p>

      <center>
        <a href="YOUR_APP_LINK" class="button">Open Pakbond App</a>
      </center>

      <p style="margin-top: 30px;">If you didn't register for Pakbond, please ignore this email.</p>
    </div>
    <div class="footer">
      <p>© 2026 Pakbond - Prize Bond Checking App</p>
      <p>This is an automated message, please do not reply.</p>
    </div>
  </div>
</body>
</html>
''';

      await send(message, _smtpServer);
      print('Approval email sent to: $toEmail');
      return true;
    } catch (e) {
      print('Email error: $e');
      return false;
    }
  }

  static Future<bool> sendRejectionEmail({
    required String toEmail,
    required String userName,
  }) async {
    try {
      final message = Message()
        ..from = Address(_username, 'Pakbond Admin')
        ..recipients.add(toEmail)
        ..subject = 'Your Pakbond Account Status Update'
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #f44336; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { padding: 20px; background: #f9f9f9; border: 1px solid #ddd; }
    .button { background: #2196F3; color: white; padding: 12px 25px; text-decoration: none; border-radius: 5px; display: inline-block; margin-top: 20px; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Account Status Update</h1>
    </div>
    <div class="content">
      <h2>Hello $userName,</h2>
      <p>Your Pakbond account application has been <strong style="color: #f44336;">rejected</strong>.</p>

      <h3>Possible Reasons:</h3>
      <ul>
        <li>Incomplete or incorrect information</li>
        <li>Unable to verify provided details</li>
        <li>Duplicate account detected</li>
      </ul>

      <p>If you believe this is a mistake, please contact our support team:</p>

      <center>
        <a href="mailto:support@pakbond.com" class="button">Contact Support</a>
      </center>

      <p style="margin-top: 30px;">You can register again with correct information.</p>
    </div>
    <div class="footer">
      <p>© 2026 Pakbond - Prize Bond Checking App</p>
      <p>Support: support@pakbond.com</p>
    </div>
  </div>
</body>
</html>
''';

      await send(message, _smtpServer);
      print('Rejection email sent to: $toEmail');
      return true;
    } catch (e) {
      print('Email error: $e');
      return false;
    }
  }

  static Future<bool> sendPinResetEmail({
    required String toEmail,
    required String userName,
  }) async {
    try {
      final message = Message()
        ..from = Address(_username, 'Pakbond Admin')
        ..recipients.add(toEmail)
        ..subject = 'Your Pakbond PIN Has Been Reset'
        ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #FF9800; color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { padding: 20px; background: #f9f9f9; border: 1px solid #ddd; }
    .pin-box { background: #333; color: white; padding: 15px; text-align: center; font-size: 32px; letter-spacing: 10px; border-radius: 10px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>PIN Reset Successful</h1>
    </div>
    <div class="content">
      <h2>Hello $userName,</h2>
      <p>Your Pakbond account PIN has been reset by the administrator.</p>

      <h3>Your new default PIN is:</h3>
      <div class="pin-box">
        <strong>0000</strong>
      </div>

      <p style="color: #f44336;"><strong>Important: Change your PIN after first login.</strong></p>
      <p>Please login with PIN <strong>0000</strong> and immediately change it to a new 4-digit PIN in the app settings.</p>

      <p>If you didn't request this reset, please contact support immediately.</p>
    </div>
    <div class="footer">
      <p>© 2026 Pakbond - Prize Bond Checking App</p>
      <p>This is an automated message, please do not reply.</p>
    </div>
  </div>
</body>
</html>
''';

      await send(message, _smtpServer);
      print('PIN reset email sent to: $toEmail');
      return true;
    } catch (e) {
      print('Email error: $e');
      return false;
    }
  }
}