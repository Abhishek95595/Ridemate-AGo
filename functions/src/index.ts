import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Sends push notification to all valid FCM device tokens for a given user UID.
 * Automatically cleans up stale/invalid tokens from Firestore.
 */
async function sendMulticastNotification(
  recipientUid: string,
  title: string,
  body: string,
  dataPayload: Record<string, string> = {}
): Promise<void> {
  if (!recipientUid) return;

  try {
    const tokensSet = new Set<string>();

    // 1. Read fcmTokens subcollection
    const tokensSnapshot = await db
      .collection("users")
      .doc(recipientUid)
      .collection("fcmTokens")
      .get();

    for (const doc of tokensSnapshot.docs) {
      const t = doc.data().token;
      if (typeof t === "string" && t.trim().length > 0) {
        tokensSet.add(t.trim());
      }
    }

    // 2. Fallback to direct fcmToken field on user document
    const userDoc = await db.collection("users").doc(recipientUid).get();
    if (userDoc.exists) {
      const directToken = userDoc.data()?.fcmToken;
      if (typeof directToken === "string" && directToken.trim().length > 0) {
        tokensSet.add(directToken.trim());
      }
    }

    const tokens = Array.from(tokensSet);
    if (tokens.length === 0) return;

    await messaging.sendEachForMulticast({
      tokens: tokens,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...dataPayload,
        title: title,
        body: body,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "ago_ride_updates",
          sound: "default",
        },
      },
    });
  } catch (error) {
    console.error(`Failed to send notification to ${recipientUid}:`, error);
  }
}

/**
 * Trigger: Passenger books a ride -> Notify Driver
 */
export const onBookingCreated = functions.firestore
  .document("bookings/{bookingId}")
  .onCreate(async (snapshot, context) => {
    const booking = snapshot.data();
    if (!booking) return;

    const driverId = booking.driverId;
    const passengerName = booking.passengerName || "A passenger";
    const bookingId = context.params.bookingId;
    const rideId = booking.rideId || "";

    if (!driverId) return;

    await sendMulticastNotification(
      driverId,
      "New Ride Request 🚗",
      `${passengerName} requested to book your ride.`,
      {
        type: "booking_request",
        bookingId: bookingId,
        rideId: rideId,
      }
    );
  });

/**
 * Trigger: Booking status updates (accepted, rejected, cancelled)
 */
export const onBookingUpdated = functions.firestore
  .document("bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (!beforeData || !afterData) return;

    const oldStatus = beforeData.status;
    const newStatus = afterData.status;

    if (oldStatus === newStatus) return;

    const bookingId = context.params.bookingId;
    const rideId = afterData.rideId || "";
    const driverId = afterData.driverId;
    const passengerId = afterData.passengerId;

    if (newStatus === "accepted") {
      await sendMulticastNotification(
        passengerId,
        "Booking Accepted ✅",
        "Your ride request has been accepted.",
        {
          type: "booking_update",
          bookingId: bookingId,
          rideId: rideId,
          status: "accepted",
        }
      );
    } else if (newStatus === "rejected") {
      await sendMulticastNotification(
        passengerId,
        "Booking Declined",
        "Your ride request was declined.",
        {
          type: "booking_update",
          bookingId: bookingId,
          rideId: rideId,
          status: "rejected",
        }
      );
    } else if (newStatus === "cancelled") {
      const cancelledBy = afterData.cancelledBy || "";
      let recipientId = passengerId;
      if (cancelledBy === passengerId) {
        recipientId = driverId;
      }

      await sendMulticastNotification(
        recipientId,
        "Booking Cancelled ⚠️",
        "Your booking has been cancelled.",
        {
          type: "booking_update",
          bookingId: bookingId,
          rideId: rideId,
          status: "cancelled",
        }
      );
    }
  });

/**
 * Trigger: New chat message -> Notify opposite participant
 */
export const onChatMessageCreated = functions.firestore
  .document("chats/{bookingId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    if (!message) return;

    const bookingId = context.params.bookingId;
    const senderId = message.senderId;
    const senderName = message.senderName || "New Message";
    const textPreview = (message.text || "").substring(0, 100);

    if (!senderId || !bookingId) return;

    const bookingSnap = await db.collection("bookings").doc(bookingId).get();
    if (!bookingSnap.exists) return;

    const booking = bookingSnap.data();
    if (!booking) return;

    const recipientId =
      senderId === booking.passengerId ? booking.driverId : booking.passengerId;

    if (!recipientId) return;

    await sendMulticastNotification(
      recipientId,
      senderName,
      textPreview || "Sent a message",
      {
        type: "chat_message",
        bookingId: bookingId,
        senderId: senderId,
        senderName: senderName,
      }
    );
  });

/**
 * Trigger: Ride status update (started, completed, cancelled)
 */
export const onRideUpdated = functions.firestore
  .document("rides/{rideId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (!beforeData || !afterData) return;

    const oldStatus = beforeData.status;
    const newStatus = afterData.status;

    if (oldStatus === newStatus) return;

    const rideId = context.params.rideId;

    const bookingsSnap = await db
      .collection("bookings")
      .where("rideId", "==", rideId)
      .get();

    if (bookingsSnap.empty) return;

    for (const bookingDoc of bookingsSnap.docs) {
      const booking = bookingDoc.data();
      const passengerId = booking.passengerId;
      const bookingId = bookingDoc.id;

      if (!passengerId) continue;

      if (newStatus === "started") {
        await sendMulticastNotification(
          passengerId,
          "Ride Started 🚘",
          "Your ride has started.",
          {
            type: "ride_update",
            rideId: rideId,
            bookingId: bookingId,
            status: "started",
          }
        );
      } else if (newStatus === "completed") {
        await sendMulticastNotification(
          passengerId,
          "Ride Completed ✅",
          "Thanks for travelling with AGo.",
          {
            type: "ride_update",
            rideId: rideId,
            bookingId: bookingId,
            status: "completed",
          }
        );
      } else if (newStatus === "cancelled") {
        await sendMulticastNotification(
          passengerId,
          "Ride Cancelled ⚠️",
          "Your ride has been cancelled by the driver.",
          {
            type: "ride_update",
            rideId: rideId,
            bookingId: bookingId,
            status: "cancelled",
          }
        );
      }
    }
  });
