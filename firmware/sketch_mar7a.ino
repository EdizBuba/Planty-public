// Copy secrets.h.example to secrets.h; never commit local credentials.
#include "secrets.h"
#include <WiFi.h>
#include <Wire.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/SDHelper.h>

#include "pins.h"
#include <AM2302-Sensor.h>

#define RELAY_PIN 14
#define DHT_PIN 15
#define SOIL_MOISTURE_PIN 36
#define SOIL_THRESHOLD 50
#define ATTINY1_HIGH_ADDR 0x78
#define ATTINY2_LOW_ADDR 0x77
#define THRESHOLD 100

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

AM2302::AM2302_Sensor am2302{ DHT_PIN };

unsigned char low_data[8] = { 0 };
unsigned char high_data[12] = { 0 };

unsigned long sendDataPrevMillis = 0;
bool signupOK = false;

void getHigh12SectionValue() {
  memset(high_data, 0, sizeof(high_data));
  Wire.requestFrom(ATTINY1_HIGH_ADDR, 12);
  while (Wire.available() < 12)
    ;
  for (int i = 0; i < 12; i++) high_data[i] = Wire.read();
}

void getLow8SectionValue() {
  memset(low_data, 0, sizeof(low_data));
  Wire.requestFrom(ATTINY2_LOW_ADDR, 8);
  while (Wire.available() < 8)
    ;
  for (int i = 0; i < 8; i++) low_data[i] = Wire.read();
}

bool shouldResetStatus(String status) {
  return !(status == "attention" || status == "critical" || status == "❌ Arrosage effectué, mais la terre reste sèche." || status == "❌ Conditions non réunies pour arroser...");
}

int readWaterLevel() {
  uint32_t touch_val = 0;
  uint8_t trig_section = 0;
  getLow8SectionValue();
  getHigh12SectionValue();
  for (int i = 0; i < 8; i++)
    if (low_data[i] > THRESHOLD) touch_val |= 1 << i;
  for (int i = 0; i < 12; i++)
    if (high_data[i] > THRESHOLD) touch_val |= (uint32_t)1 << (8 + i);
  while (touch_val & 0x01) {
    trig_section++;
    touch_val >>= 1;
  }
  return trig_section * 5;
}

void setup() {
  Serial.begin(115200);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ Wi-Fi Connected!");
  Wire.begin(23, 22);
  am2302.begin();
  pinMode(RELAY_PIN, OUTPUT);

  config.api_key = API_KEY;
  config.token_status_callback = tokenStatusCallback;

  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("✅ Firebase anonyme OK");
    signupOK = true;
  } else {
    Serial.printf("❌ Erreur Firebase anonyme: %s\n", config.signer.signupError.message.c_str());
  }

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}


void addWateringHistory(String mode, String plantId, bool success, String userId) {
  FirebaseJson history;
  history.set("fields/mode/stringValue", mode);
  history.set("fields/plantId/stringValue", plantId);
  history.set("fields/success/booleanValue", success);
  
  // Get current timestamp in ISO 8601 format
  time_t now;
  time(&now);
  struct tm* tm_info = gmtime(&now);
  char isoTimestamp[30];
  strftime(isoTimestamp, sizeof(isoTimestamp), "%Y-%m-%dT%H:%M:%SZ", tm_info);

  history.set("fields/timestamp/timestampValue", String(isoTimestamp));
  history.set("fields/userId/stringValue", userId);

  String docId = "watering_" + String((uint32_t)esp_random()); // avoid overwrite
  String path = "watering/" + docId;

  if (Firebase.Firestore.createDocument(&fbdo, PROJECT_ID, "", path.c_str(), history.raw())) {
    Serial.println("📝 Historique d’arrosage enregistré !");
  } else {
    Serial.print("⚠️ Échec ajout historique : ");
    Serial.println(fbdo.errorReason());
  }
}

 
void loop() {
  static int i = 0;
  // Plant document is configured locally.
  String plantId = PLANT_DOCUMENT_ID;
  String plantPath = "plants/" + plantId;

  if (Firebase.ready() && signupOK && (millis() - sendDataPrevMillis > 30000 || sendDataPrevMillis == 0)) {
    sendDataPrevMillis = millis();
    Serial.println("\n🔍 Tentative de lecture du document: " + plantPath);

    if (!Firebase.Firestore.getDocument(&fbdo, PROJECT_ID, "", plantPath.c_str())) {
      Serial.println("❌ Erreur lors de la lecture de la plante:");
      Serial.println(fbdo.errorReason());
      return;
    }

    Serial.println("📄 Réponse brute Firestore:");
    Serial.println(fbdo.payload());

    FirebaseJson plantData;
    plantData.setJsonData(fbdo.payload());

    String wateringMode = "", status = "", name = "";
    String alertStatus = "";
    int humidityThreshold = 0, temperatureThreshold = 0;

    FirebaseJsonData jsonData;
    String jsonDump;
    plantData.toString(jsonDump, true);
    Serial.println("📦 JSON complet:\n" + jsonDump);

    if (plantData.get(jsonData, "fields/name/stringValue")) name = jsonData.stringValue;
    if (plantData.get(jsonData, "fields/wateringMode/stringValue")) wateringMode = jsonData.stringValue;
    if (plantData.get(jsonData, "fields/humidityThreshold/integerValue")) humidityThreshold = jsonData.intValue;
    if (plantData.get(jsonData, "fields/temperatureThreshold/integerValue")) temperatureThreshold = jsonData.intValue;

    // 👉 Extract userId
    String userId = "";
    if (plantData.get(jsonData, "fields/userId/stringValue")) {
      userId = jsonData.stringValue;
    }

    Serial.println("\n🔄 Résumé plante: " + name);
    Serial.println("Mode: " + wateringMode);
    Serial.println("Seuil d'humidité: " + String(humidityThreshold) + "%");
    Serial.println("Seuil de température: " + String(temperatureThreshold) + "°C");

    int soilMoisture = analogRead(SOIL_MOISTURE_PIN);
    int waterLevel = readWaterLevel();
    int statusSensor = am2302.read();
    float temperature = (statusSensor == AM2302::AM2302_READ_OK) ? am2302.get_Temperature() : -999;
    float humidity = (statusSensor == AM2302::AM2302_READ_OK) ? am2302.get_Humidity() : -999;

    Serial.println("Humidité sol brute: " + String(soilMoisture));
    Serial.println("Humidité ambiante: " + String(humidity) + "%");
    Serial.println("Température: " + String(temperature) + "°C");
    Serial.println("Niveau eau: " + String(waterLevel) + "%");

    // 🔸 Priorité au statut critique/attention
    if (waterLevel < 25 || soilMoisture > 1500) {
      alertStatus = "critical";
    } else if (soilMoisture > 1000) {
      alertStatus = "attention";
    } else {
      status = "";  // Normal condition, no warning
    }

    if (wateringMode == "automatique") {
      Serial.println("🟦 Mode d'arrosage : AUTOMATIQUE");

      if (waterLevel >= 45 && humidity < humidityThreshold && temperature >= temperatureThreshold) {
        Serial.println("✅ Conditions réunies. Arrosage en cours...");
        digitalWrite(RELAY_PIN, HIGH);
        delay(5000);  // pump ON for 2 minutes
        digitalWrite(RELAY_PIN, LOW);

        delay(2000);
        int newSoilMoisture = analogRead(SOIL_MOISTURE_PIN);
        status = (newSoilMoisture > 600) ? "" : "❌ Arrosage effectué, mais la terre reste sèche.";

        addWateringHistory("automatique", plantId, status == "Arrosage effectué avec succès.", userId);

      } else {
        status = "critical";
      }
      delay(3000);
    } else if (wateringMode == "manuel") {
      Serial.println("🟨 Mode d'arrosage : MANUEL");

      String currentStatus;
      if (plantData.get(jsonData, "fields/status/stringValue")) {
        currentStatus = jsonData.stringValue;
      } else {
        Serial.println("⚠️ Champ 'status' manquant pour la plante");
        currentStatus = "";
      }

      if (currentStatus == "waiting" && waterLevel >= 45) {
        
        int newSoilMoisture = analogRead(SOIL_MOISTURE_PIN);
        status = (newSoilMoisture > 600) ? "" : "attention";

        Serial.println("✅ Mode manuel : conditions réunies. Arrosage en cours...");
        digitalWrite(RELAY_PIN, HIGH);
        delay(30000);
        digitalWrite(RELAY_PIN, LOW);

        if (status != "critical") {
          addWateringHistory("manuel", plantId, status == "", userId);
        }

      } else if (alertStatus == "") {
        status = "N/A";
      }



      if (status == "" && alertStatus != "") {
        status = alertStatus;  // use critical/attention if no watering issue
      }

      FirebaseJson update;
      update.set("fields/status/stringValue", status);
      if (Firebase.Firestore.patchDocument(&fbdo, PROJECT_ID, "", plantPath.c_str(), update.raw(), "status")) {
        Serial.println("✅ [MANUEL] Statut mis à jour : " + (status == "" ? "(réinitialisé)" : status));
      } else {
        Serial.println("❌ Erreur mise à jour statut : " + fbdo.errorReason());
      }

    } else {
      Serial.println("⏸️ Mode manuel actif mais en attente de statut 'waiting' ou niveau d'eau insuffisant.");
    }

    // 🔁 Mise à jour du statut si nécessaire
    FirebaseJson update;
    update.set("fields/status/stringValue", status);
    if (Firebase.Firestore.patchDocument(&fbdo, PROJECT_ID, "", plantPath.c_str(), update.raw(), "status")) {
      Serial.println("✅ Statut mis à jour : " + (status == "" ? "(réinitialisé)" : status));
    } else {
      Serial.println("❌ Erreur mise à jour statut : " + fbdo.errorReason());
    }

    FirebaseJson content;
    content.set("fields/temperature/doubleValue", temperature);
    content.set("fields/humidity/doubleValue", humidity);
    content.set("fields/soilMoisture/integerValue", soilMoisture);
    content.set("fields/waterLevel/integerValue", waterLevel);

    String documentPath = "sensorData/reading_" + String(i);
    bool success = Firebase.Firestore.createDocument(&fbdo, PROJECT_ID, "", documentPath.c_str(), content.raw());

    if (success) {
      Serial.println("✅ Relevés capteurs enregistrés !");
    } else {
      Serial.print("⚠️ Création échouée : ");
      Serial.println(fbdo.errorReason());
      if (fbdo.errorReason().indexOf("Document already exists") >= 0) {
        if (Firebase.Firestore.patchDocument(&fbdo, PROJECT_ID, "", documentPath.c_str(), content.raw(), "temperature,humidity,soilMoisture,waterLevel")) {
          Serial.println("🔄 Relevés capteurs mis à jour !");
        } else {
          Serial.print("❌ Erreur mise à jour : ");
          Serial.println(fbdo.errorReason());
        }
      }
    }

    i++;
  }
}
