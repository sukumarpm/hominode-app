const { RegistrationError } = require("./register_resident");

function normalizedString(value) {
    return typeof value === "string" ? value.trim() : "";
}

async function requireAuthorizedAdmin(db, auth, communityId) {
    const uid = normalizedString(auth?.uid);

    if (!uid) {
        throw new RegistrationError(
            "unauthenticated",
            "Authentication is required.",
        );
    }

    const adminSnapshot = await db.collection("admins").doc(uid).get();

    if (!adminSnapshot.exists) {
        throw new RegistrationError(
            "permission-denied",
            "Administrator access is required.",
        );
    }

    const admin = adminSnapshot.data();

    if (admin?.uid !== uid || admin?.isActive !== true) {
        throw new RegistrationError(
            "permission-denied",
            "An active administrator account is required.",
        );
    }

    if (admin?.role === "superAdmin") {
        return { uid, admin };
    }

    if (
        admin?.role !== "admin" ||
        !Array.isArray(admin?.authorizedCommunityIds) ||
        !admin.authorizedCommunityIds.includes(communityId)
    ) {
        throw new RegistrationError(
            "permission-denied",
            "You are not authorized for this community.",
        );
    }

    return { uid, admin };
}

async function verifyPaymentProofCore({ db, auth, data }) {
    const paymentId = normalizedString(data?.paymentId);

    if (!paymentId) {
        throw new RegistrationError(
            "invalid-argument",
            "Payment ID is required.",
        );
    }

    const paymentRef = db.collection("payments").doc(paymentId);

    const paymentSnapshot = await paymentRef.get();

    if (!paymentSnapshot.exists) {
        throw new RegistrationError(
            "not-found",
            "Payment submission was not found.",
        );
    }

    const payment = paymentSnapshot.data();

    const communityId = normalizedString(payment?.communityId);
    const billId = normalizedString(payment?.billId);

    if (!communityId || !billId) {
        throw new RegistrationError(
            "failed-precondition",
            "Payment submission is incomplete.",
        );
    }

    const { uid: adminUid } = await requireAuthorizedAdmin(
        db,
        auth,
        communityId,
    );

    const billRef = db.collection("bills").doc(billId);

    await db.runTransaction(async (transaction) => {
        const [freshPaymentSnapshot, billSnapshot] =
            await Promise.all([
                transaction.get(paymentRef),
                transaction.get(billRef),
            ]);

        if (!freshPaymentSnapshot.exists) {
            throw new RegistrationError(
                "not-found",
                "Payment submission was not found.",
            );
        }

        if (!billSnapshot.exists) {
            throw new RegistrationError(
                "not-found",
                "Bill was not found.",
            );
        }

        const freshPayment = freshPaymentSnapshot.data();
        const bill = billSnapshot.data();

        if (freshPayment?.status !== "pending") {
            throw new RegistrationError(
                "failed-precondition",
                "Only pending payment submissions can be verified.",
            );
        }

        if (bill?.status !== "pending") {
            throw new RegistrationError(
                "failed-precondition",
                "This bill is no longer pending.",
            );
        }

        if (
            freshPayment?.billId !== billId ||
            freshPayment?.communityId !== bill?.communityId ||
            freshPayment?.flatId !== bill?.flatId
        ) {
            throw new RegistrationError(
                "failed-precondition",
                "Payment and bill scope do not match.",
            );
        }

        if (
            Number(freshPayment?.amount) !== Number(bill?.amount)
        ) {
            throw new RegistrationError(
                "failed-precondition",
                "Payment amount does not match the bill amount.",
            );
        }

        const now = new Date();

        transaction.update(paymentRef, {
            status: "completed",
            reviewedAt: now,
            reviewedBy: adminUid,
            updatedAt: now,
        });

        transaction.update(billRef, {
            status: "paid",
            paymentMethod: "external",
            paymentReference:
                normalizedString(freshPayment?.transactionId) || null,
            paymentId,
            paidAt: now,
            updatedAt: now,
        });
    });

    return {
        success: true,
        paymentId,
        billId,
    };
}

async function rejectPaymentProofCore({ db, auth, data }) {
    const paymentId = normalizedString(data?.paymentId);
    const rejectionReason = normalizedString(data?.rejectionReason);

    if (!paymentId) {
        throw new RegistrationError(
            "invalid-argument",
            "Payment ID is required.",
        );
    }

    if (!rejectionReason) {
        throw new RegistrationError(
            "invalid-argument",
            "A rejection reason is required.",
        );
    }

    const paymentRef = db.collection("payments").doc(paymentId);

    const paymentSnapshot = await paymentRef.get();

    if (!paymentSnapshot.exists) {
        throw new RegistrationError(
            "not-found",
            "Payment submission was not found.",
        );
    }

    const payment = paymentSnapshot.data();

    const communityId = normalizedString(payment?.communityId);

    if (!communityId) {
        throw new RegistrationError(
            "failed-precondition",
            "Payment submission has no community.",
        );
    }

    const { uid: adminUid } = await requireAuthorizedAdmin(
        db,
        auth,
        communityId,
    );

    await db.runTransaction(async (transaction) => {
        const freshSnapshot = await transaction.get(paymentRef);

        if (!freshSnapshot.exists) {
            throw new RegistrationError(
                "not-found",
                "Payment submission was not found.",
            );
        }

        const freshPayment = freshSnapshot.data();

        if (freshPayment?.status !== "pending") {
            throw new RegistrationError(
                "failed-precondition",
                "Only pending payment submissions can be rejected.",
            );
        }

        const now = new Date();

        transaction.update(paymentRef, {
            status: "failed",
            rejectionReason,
            reviewedAt: now,
            reviewedBy: adminUid,
            updatedAt: now,
        });
    });

    return {
        success: true,
        paymentId,
    };
}

module.exports = {
    verifyPaymentProofCore,
    rejectPaymentProofCore,
};