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