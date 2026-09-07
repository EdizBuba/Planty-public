import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {defineBoolean} from "firebase-functions/params";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {notificationMinute, parisMinute, runWhenEnabled} from "./schedule";

// The public archive must not read data or send messages by default.
const enableNotifications = defineBoolean("ENABLE_WATERING_NOTIFICATIONS", {default: false});

export const checkManualWatering = onSchedule(
  {schedule: "every minute", timeZone: "Europe/Paris", maxInstances: 1, retryCount: 0},
  async () => runWhenEnabled(enableNotifications.value(), async () => {
    if (getApps().length === 0) initializeApp();
    const db = getFirestore();
    const currentMinute = parisMinute(new Date());
    const usersSnapshot = await db.collection("users").get();

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const fcmToken: unknown = userData.fcmToken;
      if (typeof fcmToken !== "string" || fcmToken.length === 0) continue;

      const plantsSnapshot = await db.collection("plants")
        .where("userId", "==", userDoc.id)
        .where("wateringMode", "==", "manuel")
        .get();

      for (const plantDoc of plantsSnapshot.docs) {
        const plantData = plantDoc.data();
        if (notificationMinute(plantData.manualWateringTime, userData.notificationDelay) !== currentMinute) continue;

        try {
          await getMessaging().send({
            notification: {
              title: "Arrosage nécessaire",
              body: "Un arrosage manuel est bientôt prévu. Consultez Planty.",
            },
            token: fcmToken,
          });
          logger.info("Watering reminder sent.");
        } catch {
          // Never log tokens, document payloads, user IDs or raw SDK errors.
          logger.warn("Watering reminder could not be sent.");
        }
      }
    }
  }),
);
