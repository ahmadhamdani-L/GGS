package push

// FCM Push Notification helper for GGS Werewolf.
// Uses the FCM v1 HTTP API with OAuth2 Service Account authentication.
//
// Setup:
//   1. Download service account JSON from Firebase Console → Project Settings → Service accounts
//   2. Set GOOGLE_APPLICATION_CREDENTIALS env var to the path of the JSON file
//      OR place it at ./firebase-service-account.json (auto-detected)
//   3. FCM_PROJECT_ID is read from the service account JSON automatically

import (
	"bytes"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/logger"
	"crypto"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
)

// ─── FCM v1 API Types ────────────────────────────────────────

const fcmV1URLTemplate = "https://fcm.googleapis.com/v1/projects/%s/messages:send"
const googleTokenURL = "https://oauth2.googleapis.com/token"

type fcmV1Request struct {
	Message fcmV1Message `json:"message"`
}

type fcmV1Message struct {
	Token        string                 `json:"token"`
	Notification *fcmV1Notification     `json:"notification,omitempty"`
	Data         map[string]string      `json:"data,omitempty"`
	Android      *fcmAndroidConfig      `json:"android,omitempty"`
	APNS         *fcmAPNSConfig         `json:"apns,omitempty"`
}

type fcmV1Notification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type fcmAndroidConfig struct {
	Priority string `json:"priority"` // "high" or "normal"
}

type fcmAPNSConfig struct {
	Payload *fcmAPNSPayload `json:"payload,omitempty"`
}

type fcmAPNSPayload struct {
	APS *fcmAPS `json:"aps,omitempty"`
}

type fcmAPS struct {
	Sound string `json:"sound,omitempty"`
	Badge int    `json:"badge,omitempty"`
}

// ─── Service Account + Token Cache ───────────────────────────

type serviceAccount struct {
	ProjectID    string `json:"project_id"`
	ClientEmail  string `json:"client_email"`
	PrivateKey   string `json:"private_key"`
	PrivateKeyID string `json:"private_key_id"`
}

var (
	cachedSA       *serviceAccount
	cachedToken    string
	tokenExpiry    time.Time
	tokenMu        sync.Mutex
	fcmInitialized bool
)

func loadServiceAccount() *serviceAccount {
	if cachedSA != nil {
		return cachedSA
	}

	// Try env var first
	path := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	if path == "" {
		// Auto-detect common locations
		candidates := []string{
			"firebase-service-account.json",
			"./firebase-service-account.json",
			"../firebase-service-account.json",
		}
		for _, c := range candidates {
			if _, err := os.Stat(c); err == nil {
				path = c
				break
			}
		}
	}

	if path == "" {
		return nil
	}

	data, err := os.ReadFile(path)
	if err != nil {
		logger.Warn(logger.CatAPI, "Failed to read service account", map[string]interface{}{"err": err.Error()})
		return nil
	}

	var sa serviceAccount
	if err := json.Unmarshal(data, &sa); err != nil {
		logger.Warn(logger.CatAPI, "Failed to parse service account JSON", map[string]interface{}{"err": err.Error()})
		return nil
	}

	cachedSA = &sa
	if !fcmInitialized {
		fcmInitialized = true
		logger.Info(logger.CatAPI, "FCM v1 initialized", map[string]interface{}{
			"project": sa.ProjectID,
			"email":   sa.ClientEmail,
		})
	}
	return cachedSA
}

// getAccessToken returns a valid OAuth2 access token, refreshing if expired.
func getAccessToken() (string, error) {
	tokenMu.Lock()
	defer tokenMu.Unlock()

	// Return cached token if still valid (with 60s buffer)
	if cachedToken != "" && time.Now().Before(tokenExpiry.Add(-60*time.Second)) {
		return cachedToken, nil
	}

	sa := loadServiceAccount()
	if sa == nil {
		return "", fmt.Errorf("no service account configured")
	}

	// Create JWT
	now := time.Now()
	jwt, err := createJWT(sa, now)
	if err != nil {
		return "", fmt.Errorf("create JWT: %w", err)
	}

	// Exchange JWT for access token
	resp, err := http.PostForm(googleTokenURL, url.Values{
		"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"},
		"assertion":  {jwt},
	})
	if err != nil {
		return "", fmt.Errorf("token exchange: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return "", fmt.Errorf("token exchange failed (%d): %s", resp.StatusCode, string(body))
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return "", fmt.Errorf("parse token response: %w", err)
	}

	cachedToken = tokenResp.AccessToken
	tokenExpiry = now.Add(time.Duration(tokenResp.ExpiresIn) * time.Second)
	return cachedToken, nil
}

// createJWT creates a signed JWT for Google OAuth2
func createJWT(sa *serviceAccount, now time.Time) (string, error) {
	header := map[string]string{
		"alg": "RS256",
		"typ": "JWT",
		"kid": sa.PrivateKeyID,
	}
	claims := map[string]interface{}{
		"iss":   sa.ClientEmail,
		"sub":   sa.ClientEmail,
		"aud":   googleTokenURL,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
		"scope": "https://www.googleapis.com/auth/firebase.messaging",
	}

	headerJSON, _ := json.Marshal(header)
	claimsJSON, _ := json.Marshal(claims)

	headerB64 := base64.RawURLEncoding.EncodeToString(headerJSON)
	claimsB64 := base64.RawURLEncoding.EncodeToString(claimsJSON)
	signingInput := headerB64 + "." + claimsB64

	// Parse RSA private key
	block, _ := pem.Decode([]byte(sa.PrivateKey))
	if block == nil {
		return "", fmt.Errorf("failed to decode PEM block")
	}

	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return "", fmt.Errorf("parse private key: %w", err)
	}

	rsaKey, ok := key.(*rsa.PrivateKey)
	if !ok {
		return "", fmt.Errorf("key is not RSA")
	}

	// Sign
	hashed := sha256.Sum256([]byte(signingInput))
	signature, err := rsa.SignPKCS1v15(rand.Reader, rsaKey, crypto.SHA256, hashed[:])
	if err != nil {
		return "", fmt.Errorf("sign JWT: %w", err)
	}

	sigB64 := base64.RawURLEncoding.EncodeToString(signature)
	return signingInput + "." + sigB64, nil
}

// ─── Public API ──────────────────────────────────────────────

// SendPushNotification sends a push notification to a specific user via FCM v1 API.
func SendPushNotification(userID, title, body string, data map[string]interface{}) {
	sa := loadServiceAccount()
	if sa == nil {
		return // FCM not configured
	}

	token, err := db.GetFCMToken(userID)
	if err != nil || token == "" {
		return // User has no token registered
	}

	accessToken, err := getAccessToken()
	if err != nil {
		logger.Warn(logger.CatAPI, "FCM get access token failed", map[string]interface{}{
			"userId": userID, "err": err.Error(),
		})
		return
	}

	// Convert data map to string map (FCM v1 requires string values)
	strData := make(map[string]string, len(data))
	for k, v := range data {
		strData[k] = fmt.Sprintf("%v", v)
	}

	msg := fcmV1Request{
		Message: fcmV1Message{
			Token: token,
			Notification: &fcmV1Notification{
				Title: title,
				Body:  body,
			},
			Data: strData,
			Android: &fcmAndroidConfig{Priority: "high"},
			APNS: &fcmAPNSConfig{
				Payload: &fcmAPNSPayload{
					APS: &fcmAPS{Sound: "default"},
				},
			},
		},
	}

	payloadBytes, _ := json.Marshal(msg)
	fcmURL := fmt.Sprintf(fcmV1URLTemplate, sa.ProjectID)

	req, err := http.NewRequest("POST", fcmURL, bytes.NewReader(payloadBytes))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+accessToken)

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
		respBody, _ := io.ReadAll(resp.Body)
		errMsg := string(respBody)
		// If token is invalid/expired, remove it from DB
		if resp.StatusCode == 404 || strings.Contains(errMsg, "NOT_FOUND") || strings.Contains(errMsg, "UNREGISTERED") {
			db.DeleteFCMToken(userID)
			logger.Info(logger.CatAPI, "Removed invalid FCM token", map[string]interface{}{"userId": userID})
		} else {
			logger.Warn(logger.CatAPI, "FCM non-200 response", map[string]interface{}{
				"userId": userID, "status": resp.StatusCode, "body": errMsg[:min(len(errMsg), 200)],
			})
		}
	}
}

func min(a, b int) int {
	if a < b { return a }
	return b
}

// ─── Convenience Functions ───────────────────────────────────

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

// SendFriendRequestPushNotification notifies a user of a friend request.
func SendFriendRequestPushNotification(receiverID, senderName string) {
	SendPushNotification(receiverID, "Permintaan Pertemanan 👋",
		fmt.Sprintf("%s ingin berteman denganmu!", senderName),
		map[string]interface{}{
			"type":       "friend_request",
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

// SendLevelUpPushNotification notifies a user of leveling up.
func SendLevelUpPushNotification(userID string, newLevel int) {
	SendPushNotification(userID, "Level Up! ⭐",
		fmt.Sprintf("Selamat! Kamu naik ke Level %d!", newLevel),
		map[string]interface{}{"type": "level_up", "level": newLevel})
}
