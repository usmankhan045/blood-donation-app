const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();

exports.notifyDonorsOnRequest = functions.firestore
  .document("blood_requests/{requestId}")
  .onCreate(async (snap, ctx) => {
    const data = snap.data();
    const bloodType = data.bloodType || "Unknown";
    const city = data.city || "Unknown";

    try {
      const response = await fetch("https://onesignal.com/api/v1/notifications", {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          // ⚠️ Replace with your real REST API key
          "Authorization": "Basic os_v2_app_wngxyd4znfguxbwsuemr33iesxxa4sp2anle7smvgxmuonyug3tqyknz55xgrjai7izmgj4xv4onnbla5wj2xzagxbql3evasu3vsdq"
        },
        body: JSON.stringify({
          app_id: "b34d7c0f-9969-4d4b-86d2-a1191ded0495",
          headings: { en: "Blood Request Alert" },
          contents: { en: `Urgent ${bloodType} needed in ${city}` },
          filters: [
            { field: "tag", key: "city", relation: "=", value: city },
            { operator: "AND" },
            { field: "tag", key: "bloodType", relation: "=", value: bloodType }
          ],
          data: {
            requestId: ctx.params.requestId,
            bloodType,
            city,
          },
        }),
      });

      console.log("OneSignal response:", await response.json());
    } catch (err) {
      console.error("Error sending OneSignal notification:", err);
    }
  });
