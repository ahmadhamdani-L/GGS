package api

// FCM Push Notification helper for GGS Werewolf.
// Uses the FCM v1 HTTP API (no third-party library — pure stdlib).
//
// Setup:
//   1. Create a Firebase project at console.firebase.google.com
//   2. Download the service account JSON key
//   3. Set FCM_SERVER_KEY env var to the FCM legacy server key
//      OR set GOOGLE_APPLICATION_CREDENTIALS to path of service account JSON
//   4. Set FCM_PROJECT_ID env var to your Firebase project ID
//
// For simplicity, this implementation uses the FCM Legacy HTTP API
// (FCM_SERVER_KEY). Migrate to v1 API + OAuth2 when needed.

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/logger"
)

const fcmLegacyURL = "https://fcm.googleapis.com/fcm/send"

type fcmPayload struct {
	To           string                 `json:"to"`
	Notification *fcmNotification       `json:"notification,omitempty"`
	Data         map[string]interface{} `json:"data,omitempty"`
	Priority     string                 `json:"priority"`
}

type fcmNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
	Sound string `json:"sound,omitempty"`
	Badge string `json:"badge,omitempty"`
	Icon  string `json:"icon,omitempty"`
}

// SendPushNotification sends a push notification to a specific user.
// If the user has no FCM token registered, it is a no-op.
func SendPushNotification(userID, title, body string, data map[string]interface{}) {
	serverKey := os.Getenv("FCM_SERVER_KEY")
	if serverKey == "" {
		return // FCM not configured
	}

	token, err := db.GetFCMToken(userID)
	if err != nil || token == "" {
		return // User has no token registered
	}

	payload := fcmPayload{
		To:       token,
		Priority: "high",
		Notification: &fcmNotification{
			Title: title,
			Body:  body,
			Sound: "default",
			Icon:  "notification_icon",
		},
		Data: data,
	}
	payloadBytes, _ := json.Marshal(payload)

	req, err := http.NewRequest("POST", fcmLegacyURL, bytes.NewReader(payloadBytes))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "key="+serverKey)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		logger.Warn(logger.CatAPI, "FCM send failed", map[string]interface{}{
			"userId": userID, "err": err.Error(),
		})
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		logger.Warn(logger.CatAPI, "FCM non-200 response", map[string]interface{}{
			"userId": userID, "status": resp.StatusCode,
		})
	}
}

// SendGiftPushNotification notifies receiver about a gift/curse.
func SendGiftPushNotification(receiverID, senderName, giftName, giftEmoji string, isCurse bool) {
	title := fmt.Sprintf("%s %s", giftEmoji, giftName)
	var body string
	if isCurse {
		body = fmt.Sprintf("%s melempar %s ke kamu!", senderName, giftName)
	} else {
		body = fmt.Sprintf("%s mengirim %s untukmu!", senderName, giftName)
	}
	SendPushNotification(receiverID, title, body, map[string]interface{}{
		"type":       "gift_received",
		"senderName": senderName,
		"giftName":   giftName,
		"giftEmoji":  giftEmoji,
	})
}

// SendGameInvitePushNotification notifies a user of a game invite.
func SendGameInvitePushNotification(receiverID, senderName, roomCode string) {
	SendPushNotification(receiverID, "Undangan Game 🐺",
		fmt.Sprintf("%s mengundangmu bergabung ke game!", senderName),
		map[string]interface{}{
			"type":       "game_invite",
			"roomCode":   roomCode,
			"senderName": senderName,
		})
}

// SendMissionResetPushNotification notifies a user that daily missions have reset.
func SendMissionResetPushNotification(userID string) {
	SendPushNotification(userID, "Misi Harian Baru! 🎯",
		"Misi harianmu sudah direset. Selesaikan untuk mendapat XP dan Koin!",
		map[string]interface{}{"type": "missions_reset"})
}

// SendAchievementPushNotification notifies a user of an achievement unlock.
func SendAchievementPushNotification(userID, achievementName string) {
	SendPushNotification(userID, "Achievement Unlocked! 🏆",
		fmt.Sprintf("Kamu membuka: %s", achievementName),
		map[string]interface{}{"type": "achievement_unlocked", "achievement": achievementName})
}
