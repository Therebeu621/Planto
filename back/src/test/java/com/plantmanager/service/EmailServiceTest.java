package com.plantmanager.service;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for EmailService.
 * Quarkus mock mailer is auto-configured in test mode,
 * so emails are captured instead of actually sent.
 */
@QuarkusTest
public class EmailServiceTest {

    @Inject
    EmailService emailService;

    @Inject
    io.quarkus.mailer.MockMailbox mailbox;

    @Test
    void testSendPasswordResetEmail_shouldSendEmail() {
        mailbox.clear();

        emailService.sendPasswordResetEmail("test-reset@example.com", "123456");

        var messages = mailbox.getMailMessagesSentTo("test-reset@example.com");
        assertEquals(1, messages.size());
        var msg = messages.get(0);
        assertTrue(msg.getSubject().contains("Reinitialisation"));
        assertTrue(msg.getHtml().contains("123456"));
    }

    @Test
    void testSendEmailVerificationCode_shouldSendEmail() {
        mailbox.clear();

        emailService.sendEmailVerificationCode("test-verify@example.com", "654321");

        var messages = mailbox.getMailMessagesSentTo("test-verify@example.com");
        assertEquals(1, messages.size());
        var msg = messages.get(0);
        assertTrue(msg.getSubject().contains("Verification"));
        assertTrue(msg.getHtml().contains("654321"));
    }

    @Test
    void testSendPasswordResetEmail_htmlContainsStructure() {
        mailbox.clear();

        emailService.sendPasswordResetEmail("structure@example.com", "999999");

        var messages = mailbox.getMailMessagesSentTo("structure@example.com");
        assertEquals(1, messages.size());
        String html = messages.get(0).getHtml();
        assertTrue(html.contains("PLANTO"));
        assertTrue(html.contains("30 minutes"));
        assertTrue(html.contains("999999"));
    }

    @Test
    void testSendEmailVerificationCode_htmlContainsStructure() {
        mailbox.clear();

        emailService.sendEmailVerificationCode("verify-structure@example.com", "111111");

        var messages = mailbox.getMailMessagesSentTo("verify-structure@example.com");
        assertEquals(1, messages.size());
        String html = messages.get(0).getHtml();
        assertTrue(html.contains("PLANTO"));
        assertTrue(html.contains("Bienvenue"));
        assertTrue(html.contains("15 minutes"));
        assertTrue(html.contains("111111"));
    }
}
