const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Note: No parameters needed here! It auto-connects to your project.
admin.initializeApp({
    databaseURL: "https://payconfirmapp-default-rtdb.asia-southeast1.firebasedatabase.app"
});

const db = admin.database();

exports.swiftAlert = onRequest(async (req, res) => {
    // 1. Check if the method is POST
    if (req.method !== "POST") {
        return res.status(405).send("Method Not Allowed");
    }

    try {
        // 2. Grab data (Firebase auto-parses JSON for you!)
        const { userId, smsText } = req.body;

        if (!userId || !smsText) {
            return res.status(400).json({ message: "Missing Data" });
        }

        // 3. AI / Logic Processing (Same logic as before)
        const transactionData = parseBankSms(smsText);

        if (!transactionData.isBankMessage) {
            return res.status(200).json({ message: "Not a bank SMS, ignored." });
        }

        // 4. Update Firebase Realtime Database
        const timestamp = new Date().toISOString();

        await db.ref(`shops/${userId}/transactions`).push({
            amount: transactionData.amount,
            type: transactionData.type,
            originalText: smsText,
            timestamp: timestamp,
            read: false
        });

        // 5. Send Success Response
        return res.status(200).json({ message: "Success", data: transactionData });

    } catch (error) {
        logger.error("Error processing transaction", error);
        return res.status(500).json({ error: error.message });
    }
});

// --- Scheduled Cleanup (Runs every day at midnight) ---
// Requires: firebase-functions/v2/scheduler
const { onSchedule } = require("firebase-functions/v2/scheduler");

exports.cleanupOldTransactions = onSchedule("every day 00:00", async (event) => {
    const now = new Date();
    // Calculate cutoff time (24 hours ago)
    const cutoffTime = new Date(now.getTime() - (24 * 60 * 60 * 1000));

    logger.log("Starting cleanup of transactions older than:", cutoffTime.toISOString());

    try {
        const shopsRef = db.ref("shops");
        const snapshot = await shopsRef.once("value");

        if (!snapshot.exists()) {
            logger.log("No shops found.");
            return;
        }

        const updates = {};
        let deleteCount = 0;

        snapshot.forEach((shopSnap) => {
            const shopId = shopSnap.key;
            const transactions = shopSnap.val().transactions;

            if (transactions) {
                Object.keys(transactions).forEach((txnId) => {
                    const txn = transactions[txnId];
                    if (txn.timestamp) {
                        const txnDate = new Date(txn.timestamp);
                        if (txnDate < cutoffTime) {
                            // Mark for deletion
                            updates[`shops/${shopId}/transactions/${txnId}`] = null;
                            deleteCount++;
                        }
                    }
                });
            }
        });

        if (deleteCount > 0) {
            await db.ref().update(updates);
            logger.log(`Deleted ${deleteCount} old transactions.`);
        } else {
            logger.log("No old transactions found to delete.");
        }

    } catch (error) {
        logger.error("Error cleaning up transactions", error);
    }
});

// --- HELPER FUNCTION (Same as before) ---
function parseBankSms(text) {
    const cleanText = text.toLowerCase();

    let type = 'UNKNOWN';
    if (cleanText.includes("credited") || cleanText.includes("received") || cleanText.includes("deposit")) {
        type = 'CREDIT';
    } else if (cleanText.includes("debited") || cleanText.includes("paid") || cleanText.includes("transfer")) {
        type = 'DEBIT';
    }

    const amountRegex = /(?:lkr|rs\.?|amount)\s?[:\-]?\s?([\d,]+\.?\d{0,2})/i;
    const match = text.match(amountRegex);

    let amount = "0.00";
    if (match && match[1]) {
        amount = match[1];
    }

    const isBankMessage = (amount !== "0.00" && type !== 'UNKNOWN');

    return { isBankMessage, type, amount };
}