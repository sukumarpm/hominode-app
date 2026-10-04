#!/usr/bin/env node

const admin = require("firebase-admin");
const { normalizeIanaTimeZone } = require("../src/tenant_management");

if (!admin.apps.length) {
    admin.initializeApp();
}

async function main() {
    const db = admin.firestore();
    const snapshot = await db.collection("communities").get();

    let invalidCount = 0;

    for (const doc of snapshot.docs) {
        const data = doc.data() || {};
        const name = typeof data.name === "string" ? data.name.trim() : "";
        const rawTimeZone = data.timeZone;

        if (typeof rawTimeZone !== "string" || !rawTimeZone.trim()) {
            invalidCount += 1;
            console.log(`[MISSING] ${doc.id} | ${name || "(no-name)"}`);
            continue;
        }

        try {
            const canonical = normalizeIanaTimeZone(rawTimeZone);
            console.log(`[VALID] ${doc.id} | ${name || "(no-name)"} | ${canonical}`);
        } catch {
            invalidCount += 1;
            console.log(`[INVALID] ${doc.id} | ${name || "(no-name)"} | ${String(rawTimeZone)}`);
        }
    }

    if (invalidCount > 0) {
        console.error(`Time zone audit failed: ${invalidCount} community record(s) missing or invalid.`);
        process.exitCode = 1;
        return;
    }

    console.log("Time zone audit passed: all community records have valid IANA time zones.");
}

main().catch((error) => {
    console.error("Time zone audit failed with runtime error:", error);
    process.exitCode = 1;
});
