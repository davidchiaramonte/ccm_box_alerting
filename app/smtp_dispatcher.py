import os
import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# SMTP Server configurations (Injected strictly from environment - 100% abstracted from code)
SMTP_SERVER = os.environ.get('SMTP_SERVER')
SMTP_PORT   = int(os.environ.get('SMTP_PORT', '587'))
SMTP_USER   = os.environ.get('SMTP_USER') # All hardcoded domain fallbacks completely scrubbed

# ============================================================================
# ISOLATED EMAIL SERVICE DISPATCHER (SMTP PROXY COMPONENT)
# ============================================================================
# [DESIGN NOTE]: This file isolates all direct communication with the email server.
# If you decide to swap Gmail SMTP for a Third-Party SDK (e.g. SendGrid or Mailgun) later,
# you ONLY need to re-write this specific file. The rest of the codebase remains 100% untouched!
# ============================================================================
def send_email_via_smtp(to_emails: list, subject: str, html_content: str, smtp_password: str) -> bool:
    if not smtp_password:
        logging.error("SMTP App Password is empty or unresolved from Secret Manager SDK.")
        return False

    if not SMTP_SERVER or not SMTP_USER:
        logging.error("SMTP server configuration environment variables are missing from container context (SMTP_SERVER / SMTP_USER).")
        return False

    # Extract raw email addresses strings for smtplib compatibility
    recipients = []
    for item in to_emails:
        if isinstance(item, dict) and "email" in item:
            recipients.append(item["email"])
        elif isinstance(item, str):
            recipients.append(item)

    if not recipients:
        logging.error("No valid email recipients found in headers.")
        return False

    # Assemble MIME multipart alternative structure
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From']    = f"GCP FinOps Alerting System <{SMTP_USER}>"
    msg['To']      = ", ".join(recipients)

    # Attach the HTML body text block
    msg.attach(MIMEText(html_content, 'html'))

    try:
        logging.info(f"Initiating secure SMTP connection to server {SMTP_SERVER}:{SMTP_PORT} as user {SMTP_USER}...")
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls() # Upgrade connection to a secure, encrypted TLS channel
        server.login(SMTP_USER, smtp_password)
        
        logging.info(f"Dispatching cost anomaly email alert via secure SMTP relay to: {recipients}...")
        server.sendmail(SMTP_USER, recipients, msg.as_string())
        server.quit() # Terminate session cleanly
        logging.info("Email alert successfully dispatched via isolated secure SMTP relay proxy!")
        return True
    except Exception as e:
        logging.error(f"Isolated SMTP relay server proxy failed to send email: {e}", exc_info=True)
        return False
