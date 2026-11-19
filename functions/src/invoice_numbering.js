'use strict';

const {createHash} = require('node:crypto');

// Invoice numbers belong to the issuing community, not the Hominode payment
// provider. A dedicated immutable community code must be assigned centrally.
// Calling code stores the resulting number on the bill at issuance and must
// never regenerate it when opening a PDF or recording a payment.
function invoiceNumber({communityCode, year, sequence}) {
  if (typeof communityCode !== 'string' || !/^[A-Z][A-Z0-9-]{1,19}$/.test(communityCode)) {
    throw new Error('Invalid registered community invoice code.');
  }
  if (!Number.isSafeInteger(year) || year < 2000 || year > 2100) {
    throw new Error('Invalid invoice year.');
  }
  if (!Number.isSafeInteger(sequence) || sequence < 1 || sequence > 999999) {
    throw new Error('Invalid invoice sequence.');
  }
  return `HN-${communityCode}-${year}-${String(sequence).padStart(6, '0')}`;
}

function invoiceCounterId(communityId, year) {
  if (typeof communityId !== 'string' || !communityId.trim() || communityId !== communityId.trim()) {
    throw new Error('Invalid community ID.');
  }
  if (!Number.isSafeInteger(year) || year < 2000 || year > 2100) {
    throw new Error('Invalid invoice year.');
  }
  return createHash('sha256').update(JSON.stringify([communityId, year])).digest('hex');
}

// Execute inside the *same Firestore transaction* that creates the issued bill.
// All caller transaction reads must complete before writing the counter or bill.
// The caller must verify that communityCode is a trusted, unique, immutable
// registered identifier, not a guess derived from a display name.
// This helper intentionally does not mutate or renumber existing invoices.
async function reserveInvoiceNumber({db, transaction, communityId, communityCode, year}) {
  const counterRef = db.collection('invoiceCounters').doc(invoiceCounterId(communityId, year));
  const snap = await transaction.get(counterRef);
  const previous = snap.exists ? snap.data() : null;
  if (previous && (previous.communityId !== communityId || previous.year !== year ||
      previous.communityCode !== communityCode)) {
    throw new Error('Invoice counter scope does not match registered community.');
  }
  const previousSequence = previous ? previous.lastSequence : 0;
  if (!Number.isSafeInteger(previousSequence) || previousSequence < 0 || previousSequence >= 999999) {
    throw new Error('Invoice sequence exhausted or invalid.');
  }
  const sequence = previousSequence + 1;
  const number = invoiceNumber({communityCode, year, sequence});
  // The caller commits this counter update with bill issuance after ALL reads.
  return {number, sequence, counterRef,
    counterData: {communityId, communityCode, year, lastSequence: sequence}};
}

module.exports = {invoiceNumber, invoiceCounterId, reserveInvoiceNumber};
