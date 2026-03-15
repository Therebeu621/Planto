package com.plantmanager.service;

import io.quarkus.mailer.Mail;
import io.quarkus.mailer.Mailer;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.jboss.logging.Logger;

@ApplicationScoped
public class EmailService {

    private static final Logger LOG = Logger.getLogger(EmailService.class);

    @Inject
    Mailer mailer;

    public void sendPasswordResetEmail(String to, String resetCode) {
        String subject = "Planto - Reinitialisation de votre mot de passe";
        String body = """
                <html>
                <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                    <div style="background-color: #4CAF50; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;">
                        <h1 style="color: white; margin: 0;">PLANTO</h1>
                    </div>
                    <div style="padding: 30px; background-color: #f9f9f9; border-radius: 0 0 8px 8px;">
                        <h2>Reinitialisation du mot de passe</h2>
                        <p>Vous avez demande la reinitialisation de votre mot de passe.</p>
                        <p>Voici votre code de reinitialisation :</p>
                        <div style="text-align: center; margin: 30px 0;">
                            <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; background-color: #e8f5e9; padding: 15px 30px; border-radius: 8px; color: #2E7D32;">%s</span>
                        </div>
                        <p>Ce code expire dans <strong>30 minutes</strong>.</p>
                        <p style="color: #666;">Si vous n'avez pas demande cette reinitialisation, ignorez cet email.</p>
                    </div>
                </body>
                </html>
                """.formatted(resetCode);

        try {
            mailer.send(Mail.withHtml(to, subject, body));
            LOG.infof("Password reset email sent to %s", to);
        } catch (Exception e) {
            LOG.errorf("Failed to send password reset email to %s: %s", to, e.getMessage());
        }
    }

    public void sendEmailVerificationCode(String to, String code) {
        String subject = "Planto - Verification de votre adresse email";
        String body = """
                <html>
                <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
                    <div style="background-color: #4CAF50; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;">
                        <h1 style="color: white; margin: 0;">PLANTO</h1>
                    </div>
                    <div style="padding: 30px; background-color: #f9f9f9; border-radius: 0 0 8px 8px;">
                        <h2>Bienvenue sur Planto !</h2>
                        <p>Veuillez verifier votre adresse email en entrant le code suivant dans l'application :</p>
                        <div style="text-align: center; margin: 30px 0;">
                            <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; background-color: #e8f5e9; padding: 15px 30px; border-radius: 8px; color: #2E7D32;">%s</span>
                        </div>
                        <p>Ce code expire dans <strong>15 minutes</strong>.</p>
                    </div>
                </body>
                </html>
                """.formatted(code);

        try {
            mailer.send(Mail.withHtml(to, subject, body));
            LOG.infof("Verification email sent to %s", to);
        } catch (Exception e) {
            LOG.errorf("Failed to send verification email to %s: %s", to, e.getMessage());
        }
    }
}
