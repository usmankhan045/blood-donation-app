const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// ═══════════════════════════════════════════════════════════════
// 🔔 PROCESS NOTIFICATION QUEUE (TRIGGERS ON NEW DOCUMENTS)
// ═══════════════════════════════════════════════════════════════

exports.processNotificationQueue = functions.firestore
  .document('notification_queue/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notification = snap.data();
      const notificationId = context.params.notificationId;

      console.log(`🔔 Processing notification ${notificationId}`);

      // Extract data
      const { token, notification: notif, data, android, apns, priority } = notification;

      if (!token) {
        console.error('❌ No token provided');
        await snap.ref.update({ processed: true, error: 'No token provided' });
        return null;
      }

      // Build FCM message using FCM V1 API format
      const message = {
        token: token,
        notification: {
          title: notif.title,
          body: notif.body,
        },
        data: data || {},
        android: android || {
          priority: priority === 'high' ? 'high' : 'normal',
          notification: {
            sound: 'default',
            channelId: 'high_importance_channel',
          },
        },
        apns: apns || {
          payload: {
            aps: {
              alert: {
                title: notif.title,
                body: notif.body,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // Send notification using FCM V1 API
      const response = await admin.messaging().send(message);

      console.log(`✅ Notification sent successfully: ${response}`);

      // Mark as processed
      await snap.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        response: response,
      });

      return null;

    } catch (error) {
      console.error('❌ Error processing notification:', error);

      // Mark as failed
      await snap.ref.update({
        processed: true,
        error: error.message,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return null;
    }
  });

// ═══════════════════════════════════════════════════════════════
// 🚀 AUTO-NOTIFY ON BLOOD REQUEST CREATION
// ═══════════════════════════════════════════════════════════════

exports.notifyOnRequestCreated = functions.firestore
  .document('blood_requests/{requestId}')
  .onCreate(async (snap, context) => {
    try {
      const request = snap.data();
      const requestId = context.params.requestId;

      console.log(`🚀 New blood request created: ${requestId}`);
      console.log(`   Blood Type: ${request.bloodType}`);
      console.log(`   Urgency: ${request.urgency}`);

      // Get potential donors
      const potentialDonors = request.potentialDonors || [];

      if (potentialDonors.length === 0) {
        console.log('⚠️  No potential donors for this request');
        return null;
      }

      console.log(`📢 Notifying ${potentialDonors.length} potential donors`);

      // Fetch FCM tokens for donors (batch of 10 due to Firestore limit)
      const batchSize = 10;
      let notificationCount = 0;

      for (let i = 0; i < potentialDonors.length; i += batchSize) {
        const batch = potentialDonors.slice(i, i + batchSize);

        const donorDocs = await admin.firestore()
          .collection('users')
          .where(admin.firestore.FieldPath.documentId(), 'in', batch)
          .get();

        // Queue notifications for each donor
        const notificationPromises = donorDocs.docs.map(async (doc) => {
          const donorData = doc.data();
          if (!donorData.fcmToken) {
            console.log(`⚠️  Donor ${doc.id} has no FCM token`);
            return;
          }

          // Create notification in queue
          await admin.firestore().collection('notification_queue').add({
            token: donorData.fcmToken,
            notification: {
              title: request.urgency === 'emergency'
                ? `🚨 EMERGENCY: ${request.bloodType} Blood Needed!`
                : `🩸 Blood Request: ${request.bloodType} Needed`,
              body: `${request.bloodType} blood needed - ${request.units} unit(s) required. Tap to respond.`,
            },
            data: {
              type: 'blood_request',
              requestId: requestId,
              bloodType: request.bloodType,
              urgency: request.urgency,
              units: request.units.toString(),
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            processed: false,
            priority: request.urgency === 'emergency' ? 'high' : 'normal',
          });

          notificationCount++;
        });

        await Promise.all(notificationPromises);
      }

      console.log(`✅ Queued ${notificationCount} notifications for donors`);
      return null;

    } catch (error) {
      console.error('❌ Error notifying donors:', error);
      return null;
    }
  });

// ═══════════════════════════════════════════════════════════════
// ⏰ AUTO-EXPIRE OLD REQUESTS (RUNS EVERY 5 MINUTES)
// ═══════════════════════════════════════════════════════════════

exports.autoExpireRequests = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    try {
      console.log('⏰ Running auto-expire check...');

      const now = admin.firestore.Timestamp.now();

      // Find expired requests
      const expiredRequests = await admin.firestore()
        .collection('blood_requests')
        .where('status', 'in', ['pending', 'active'])
        .where('expiresAt', '<=', now)
        .get();

      if (expiredRequests.empty) {
        console.log('✅ No requests to expire');
        return null;
      }

      console.log(`⏰ Expiring ${expiredRequests.size} requests`);

      // Batch update
      const batch = admin.firestore().batch();

      expiredRequests.docs.forEach(doc => {
        batch.update(doc.ref, {
          status: 'expired',
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
          potentialDonors: [],
        });
      });

      await batch.commit();
      console.log(`✅ Expired ${expiredRequests.size} requests`);

      return null;

    } catch (error) {
      console.error('❌ Error in auto-expire:', error);
      return null;
    }
  });

// ═══════════════════════════════════════════════════════════════
// 🧹 CLEAN UP OLD NOTIFICATION QUEUE (RUNS DAILY)
// ═══════════════════════════════════════════════════════════════

exports.cleanupNotificationQueue = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    try {
      console.log('🧹 Cleaning up old notifications...');

      const oneDayAgo = new Date();
      oneDayAgo.setDate(oneDayAgo.getDate() - 1);

      const oldNotifications = await admin.firestore()
        .collection('notification_queue')
        .where('processed', '==', true)
        .where('createdAt', '<', admin.firestore.Timestamp.fromDate(oneDayAgo))
        .get();

      if (oldNotifications.empty) {
        console.log('✅ No old notifications to clean');
        return null;
      }

      // Delete in batches
      const batch = admin.firestore().batch();
      oldNotifications.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`✅ Cleaned ${oldNotifications.size} old notifications`);

      return null;

    } catch (error) {
      console.error('❌ Error cleaning notifications:', error);
      return null;
    }
  });

// ═══════════════════════════════════════════════════════════════
// 🔔 NOTIFY RECIPIENT ON REQUEST ACCEPTANCE
// ═══════════════════════════════════════════════════════════════

exports.notifyRecipientOnAcceptance = functions.firestore
  .document('blood_requests/{requestId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();

      // Check if status changed to 'accepted'
      if (before.status !== 'accepted' && after.status === 'accepted') {
        console.log(`✅ Request ${context.params.requestId} was accepted`);

        // Get recipient's FCM token
        const recipientDoc = await admin.firestore()
          .collection('users')
          .doc(after.requesterId)
          .get();

        const recipientData = recipientDoc.data();
        if (!recipientData || !recipientData.fcmToken) {
          console.log('⚠️  Recipient has no FCM token');
          return null;
        }

        // Queue notification for recipient
        await admin.firestore().collection('notification_queue').add({
          token: recipientData.fcmToken,
          notification: {
            title: '✅ Request Accepted!',
            body: `Your ${after.bloodType} blood request has been accepted by ${after.acceptedByName || 'a donor'}`,
          },
          data: {
            type: 'request_accepted',
            requestId: context.params.requestId,
            acceptedBy: after.acceptedBy,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          processed: false,
          priority: 'high',
        });

        console.log('✅ Acceptance notification queued for recipient');
      }

      return null;

    } catch (error) {
      console.error('❌ Error notifying recipient:', error);
      return null;
    }
  });

// ═══════════════════════════════════════════════════════════════
// 🧪 TEST FUNCTION (FOR DEBUGGING)
// ═══════════════════════════════════════════════════════════════

exports.testNotification = functions.https.onCall(async (data, context) => {
  try {
    // Ensure user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userId = context.auth.uid;
    console.log(`🧪 Testing notification for user: ${userId}`);

    // Get user's FCM token
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (!userData || !userData.fcmToken) {
      throw new functions.https.HttpsError('not-found', 'No FCM token found for user');
    }

    // Send test notification
    await admin.firestore().collection('notification_queue').add({
      token: userData.fcmToken,
      notification: {
        title: '🧪 Test Notification',
        body: 'Your FCM notifications are working perfectly!',
      },
      data: {
        type: 'test',
        userId: userId,
        timestamp: new Date().toISOString(),
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
      priority: 'normal',
    });

    console.log('✅ Test notification queued');
    return { success: true, message: 'Test notification sent' };

  } catch (error) {
    console.error('❌ Error in test notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});