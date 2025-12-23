const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

function escapeHtml(value) {
  const str = String(value ?? '');
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatDate(value) {
  if (!value) return 'N/A';
  const date = value?.toDate ? value.toDate() : value;
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) return 'N/A';
  return date.toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
  });
}

function getTransport() {
  // Recommended: set these with `firebase functions:config:set smtp.host="..." smtp.port="587" smtp.user="..." smtp.pass="..." smtp.from="..."`
  const config = functions.config();
  const smtp = config.smtp || {};

  if (!smtp.host || !smtp.port || !smtp.user || !smtp.pass) {
    throw new Error(
      'Missing SMTP config. Set firebase functions config: smtp.host, smtp.port, smtp.user, smtp.pass (and optionally smtp.from).'
    );
  }

  return nodemailer.createTransport({
    host: smtp.host,
    port: Number(smtp.port),
    secure: Number(smtp.port) === 465,
    auth: {
      user: smtp.user,
      pass: smtp.pass,
    },
  });
}

exports.sendBookingConfirmationEmail = functions.firestore
  .document('bookings/{bookingId}')
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : null;
    if (!after) return null;

    // Only email for completed + paid bookings.
    if (after.status !== 'completed') return null;
    if (after.isPaid !== true) return null;

    // Idempotency: never send twice.
    if (after.emailSent === true) return null;

    // If another function invocation is already sending, skip.
    const sendState = String(after.emailSendState || '');
    if (sendState === 'sending' || sendState === 'sent') return null;

    const bookingId = context.params.bookingId;
    const docRef = admin.firestore().collection('bookings').doc(bookingId);

    // Claim the send (transaction prevents duplicates).
    const claimed = await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(docRef);
      if (!snap.exists) return false;
      const data = snap.data() || {};

      if (data.emailSent === true) return false;
      const currentState = String(data.emailSendState || '');
      if (currentState === 'sending' || currentState === 'sent') return false;

      tx.update(docRef, {
        emailSendState: 'sending',
        emailSendAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return true;
    });

    if (!claimed) return null;

    try {
      const transport = getTransport();
      const config = functions.config();
      const smtp = config.smtp || {};

      // Email recipient: prefer stored booking email, else fetch from Auth.
      let toEmail = after.userEmail;
      if (!toEmail && after.userId) {
        const userRecord = await admin.auth().getUser(after.userId);
        toEmail = userRecord.email;
      }
      if (!toEmail) {
        throw new Error('No recipient email found (userEmail missing and auth user has no email).');
      }

      const userName = after.userName || 'Customer';
      const carName = after.carName || 'your car';
      const bookingDateText = formatDate(after.bookingDate || after.createdAt);
      const startDateText = formatDate(after.startDate);
      const endDateText = formatDate(after.endDate);
      const pickupLocation = after.pickupLocation || 'N/A';
      const dropoffLocation = after.dropoffLocation || 'N/A';
      const totalPrice =
        typeof after.totalPrice === 'number' ? after.totalPrice : Number(after.totalPrice || 0);
      const totalText = Number.isFinite(totalPrice) ? `₹${totalPrice.toFixed(2)}` : 'N/A';
      const paymentId = after.paymentId || 'N/A';

      const subject = `Booking Confirmed: ${carName}`;
      const text =
        `Hi ${userName},\n\n` +
        `Your payment was successful and your booking is confirmed.\n\n` +
        `Booking ID: ${bookingId}\n` +
        `Payment ID: ${paymentId}\n` +
        `Car: ${carName}\n` +
        `Booking Date: ${bookingDateText}\n` +
        `Rental Period: ${startDateText} to ${endDateText}\n` +
        `Pickup: ${pickupLocation}\n` +
        `Drop-off: ${dropoffLocation}\n` +
        `Total Paid: ${totalText}\n\n` +
        `Thank you for choosing our Car Rental App.\n`;

      const html = `
        <div style="font-family: Arial, sans-serif; line-height: 1.5;">
          <h2>Payment Successful — Booking Confirmed</h2>
          <p>Hi <b>${escapeHtml(userName)}</b>,</p>
          <p>Your payment was successful and your booking is confirmed.</p>
          <ul>
            <li><b>Booking ID:</b> ${escapeHtml(bookingId)}</li>
            <li><b>Payment ID:</b> ${escapeHtml(paymentId)}</li>
            <li><b>Car:</b> ${escapeHtml(carName)}</li>
            <li><b>Booking Date:</b> ${escapeHtml(bookingDateText)}</li>
            <li><b>Rental Period:</b> ${escapeHtml(startDateText)} to ${escapeHtml(endDateText)}</li>
            <li><b>Pickup:</b> ${escapeHtml(pickupLocation)}</li>
            <li><b>Drop-off:</b> ${escapeHtml(dropoffLocation)}</li>
            <li><b>Total Paid:</b> ${escapeHtml(totalText)}</li>
          </ul>
          <p>Thank you for choosing our Car Rental App.</p>
        </div>
      `;

      const info = await transport.sendMail({
        from: smtp.from || smtp.user,
        to: toEmail,
        subject,
        text,
        html,
      });

      await docRef.update({
        emailSent: true,
        emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
        emailSendState: 'sent',
        emailMessageId: info.messageId || null,
      });

      return null;
    } catch (err) {
      await docRef.update({
        emailSendState: 'error',
        emailSendError: String(err && err.message ? err.message : err),
      });
      console.error('Email send failed:', err);
      return null;
    }
  });
