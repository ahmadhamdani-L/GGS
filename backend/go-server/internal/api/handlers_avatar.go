package api

import (
	"bytes"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/logger"
	"golang.org/x/crypto/bcrypt"
)

const (
	maxAvatarFileSize  = 2 << 20  // 2 MB
	avatarOutputSize   = 200      // 200×200 px
	avatarUploadDir    = "./uploads/avatars"
	avatarURLPrefix    = "/avatars/"
)

var allowedMIMETypes = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
}

// HandleAvatarUpload handles POST /api/avatar/upload (multipart/form-data, field: "avatar")
func (s *Server) HandleAvatarUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}

	userID := r.Context().Value(ContextKeyUserID).(string)

	// Limit entire request body to prevent DoS
	r.Body = http.MaxBytesReader(w, r.Body, maxAvatarFileSize+1024)

	// Parse multipart (max 2MB in memory)
	if err := r.ParseMultipartForm(maxAvatarFileSize); err != nil {
		errorResponse(w, 400, "file terlalu besar (maks 2MB) atau format tidak valid")
		return
	}

	file, header, err := r.FormFile("avatar")
	if err != nil {
		errorResponse(w, 400, "field 'avatar' tidak ditemukan")
		return
	}
	defer file.Close()

	// Validate file size
	if header.Size > maxAvatarFileSize {
		errorResponse(w, 400, fmt.Sprintf("file terlalu besar: %d bytes (maks 2MB)", header.Size))
		return
	}

	// Read entire file into buffer for dual MIME + image decode
	data, err := io.ReadAll(io.LimitReader(file, maxAvatarFileSize+1))
	if err != nil {
		errorResponse(w, 500, "gagal membaca file")
		return
	}

	// Validate MIME type from actual bytes (not just Content-Type header)
	detectedMIME := http.DetectContentType(data)
	// Normalise: http.DetectContentType returns "image/jpeg", "image/png", "image/gif", "image/webp"
	ext, allowed := allowedMIMETypes[detectedMIME]
	if !allowed {
		errorResponse(w, 400, "format tidak didukung — gunakan JPEG, PNG, atau WebP")
		return
	}

	// Decode image
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		errorResponse(w, 400, "file bukan gambar yang valid")
		return
	}

	// Validate minimum dimensions (at least 50×50 to avoid tiny images)
	bounds := img.Bounds()
	if bounds.Dx() < 50 || bounds.Dy() < 50 {
		errorResponse(w, 400, "gambar terlalu kecil (minimal 50×50 pixel)")
		return
	}

	// Resize + crop to 200×200 center-crop
	resized := centerCropResize(img, avatarOutputSize, avatarOutputSize)

	// Encode as JPEG (normalize all formats → JPEG for consistency & smaller size)
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, resized, &jpeg.Options{Quality: 85}); err != nil {
		errorResponse(w, 500, "gagal memproses gambar")
		return
	}
	_ = ext // we always save as .jpg after encoding

	// Generate unique filename: {userID_short}_{random}.jpg
	randomBytes := make([]byte, 8)
	rand.Read(randomBytes)
	filename := fmt.Sprintf("%s_%s.jpg", userID[:8], hex.EncodeToString(randomBytes))

	// Ensure upload directory exists
	if err := os.MkdirAll(avatarUploadDir, 0755); err != nil {
		errorResponse(w, 500, "gagal membuat direktori upload")
		return
	}

	// Write file
	destPath := filepath.Join(avatarUploadDir, filename)
	if err := os.WriteFile(destPath, buf.Bytes(), 0644); err != nil {
		errorResponse(w, 500, "gagal menyimpan file")
		return
	}

	// Build public URL
	publicURL := avatarURLPrefix + filename

	// Remove old avatar file if user had one
	go cleanupOldAvatar(userID, publicURL)

	// Save to DB: update profiles.avatar_url + record upload history
	if err := saveAvatarURL(userID, publicURL, filename, buf.Len(), "image/jpeg"); err != nil {
		// Non-fatal: log but still return success (file was saved)
		logger.Warn(logger.CatAPI, "Failed to save avatar URL to DB", map[string]interface{}{
			"userId": userID, "err": err.Error(),
		})
	}

	logger.Info(logger.CatAPI, "Avatar uploaded", map[string]interface{}{
		"userId":   userID,
		"filename": filename,
		"size":     buf.Len(),
	})

	jsonResponse(w, 200, map[string]interface{}{
		"avatarUrl": publicURL,
		"filename":  filename,
		"width":     avatarOutputSize,
		"height":    avatarOutputSize,
	})
}

// HandleAvatarDelete handles DELETE /api/avatar — removes user's uploaded avatar
func (s *Server) HandleAvatarDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != "DELETE" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	userID := r.Context().Value(ContextKeyUserID).(string)

	// Get current avatar URL
	var avatarURL sql.NullString
	if db.DB != nil {
		db.DB.QueryRow(`SELECT avatar_url FROM profiles WHERE user_id=$1`, userID).Scan(&avatarURL)
	}

	if avatarURL.Valid && avatarURL.String != "" {
		// Delete file from disk
		filename := strings.TrimPrefix(avatarURL.String, avatarURLPrefix)
		path := filepath.Join(avatarUploadDir, filepath.Base(filename))
		os.Remove(path)

		// Clear from DB
		if db.DB != nil {
			db.DB.Exec(`UPDATE profiles SET avatar_url = NULL WHERE user_id=$1`, userID)
			db.DB.Exec(`UPDATE avatar_uploads SET is_active=false WHERE user_id=$1`, userID)
		}
	}

	jsonResponse(w, 200, map[string]interface{}{"message": "Avatar dihapus"})
}

// ServeAvatarFile serves uploaded avatar images with cache headers.
// Task #3: GET /avatars/:filename
func ServeAvatarFile(uploadDir string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Extract filename from path — prevent path traversal
		raw := strings.TrimPrefix(r.URL.Path, "/avatars/")
		filename := filepath.Base(raw) // filepath.Base strips any "../" attempts

		// Only allow .jpg files (we always normalize to JPEG on upload)
		if !strings.HasSuffix(filename, ".jpg") {
			http.NotFound(w, r)
			return
		}

		fullPath := filepath.Join(uploadDir, filename)

		// Security: ensure resolved path is still inside uploadDir
		absDir, _ := filepath.Abs(uploadDir)
		absPath, _ := filepath.Abs(fullPath)
		if !strings.HasPrefix(absPath, absDir+string(filepath.Separator)) {
			http.Error(w, "Forbidden", http.StatusForbidden)
			return
		}

		// Check file exists
		info, err := os.Stat(fullPath)
		if err != nil || info.IsDir() {
			http.NotFound(w, r)
			return
		}

		// Cache headers: avatars are immutable once uploaded (filename includes random suffix)
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
		w.Header().Set("Content-Type", "image/jpeg")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		// ETag based on filename (deterministic)
		w.Header().Set("ETag", fmt.Sprintf(`"%s"`, filename))

		// 304 Not Modified support
		if r.Header.Get("If-None-Match") == fmt.Sprintf(`"%s"`, filename) {
			w.WriteHeader(http.StatusNotModified)
			return
		}

		http.ServeFile(w, r, fullPath)
	}
}

// ─── Image Processing ─────────────────────────────────────────

// centerCropResize crops the image to a square (center crop) then resizes to targetW×targetH.
// Uses only stdlib image packages — no external dependencies.
func centerCropResize(src image.Image, targetW, targetH int) image.Image {
	srcBounds := src.Bounds()
	srcW := srcBounds.Dx()
	srcH := srcBounds.Dy()

	// Step 1: Center-crop to square
	var cropRect image.Rectangle
	if srcW > srcH {
		offset := (srcW - srcH) / 2
		cropRect = image.Rect(srcBounds.Min.X+offset, srcBounds.Min.Y,
			srcBounds.Min.X+offset+srcH, srcBounds.Min.Y+srcH)
	} else {
		offset := (srcH - srcW) / 2
		cropRect = image.Rect(srcBounds.Min.X, srcBounds.Min.Y+offset,
			srcBounds.Min.X+srcW, srcBounds.Min.Y+offset+srcW)
	}

	// Crop: draw crop region into a new RGBA image
	cropped := image.NewRGBA(image.Rect(0, 0, cropRect.Dx(), cropRect.Dy()))
	draw.Draw(cropped, cropped.Bounds(), src, cropRect.Min, draw.Src)

	// Step 2: Nearest-neighbor resize to target size (fast, good enough for 200×200)
	dst := image.NewRGBA(image.Rect(0, 0, targetW, targetH))
	cropW := cropped.Bounds().Dx()
	cropH := cropped.Bounds().Dy()

	for y := 0; y < targetH; y++ {
		for x := 0; x < targetW; x++ {
			srcX := x * cropW / targetW
			srcY := y * cropH / targetH
			c := cropped.RGBAAt(srcX, srcY)
			dst.SetRGBA(x, y, color.RGBA{R: c.R, G: c.G, B: c.B, A: c.A})
		}
	}
	return dst
}

// ─── DB helpers ───────────────────────────────────────────────

func saveAvatarURL(userID, avatarURL, filename string, fileSize int, mimeType string) error {
	if db.DB == nil {
		return nil
	}
	// Deactivate previous uploads
	db.DB.Exec(`UPDATE avatar_uploads SET is_active=false WHERE user_id=$1`, userID)

	// Insert new upload record
	db.DB.Exec(`
		INSERT INTO avatar_uploads (user_id, filename, file_size, mime_type)
		VALUES ($1, $2, $3, $4)
	`, userID, filename, fileSize, mimeType)

	// Update profile
	_, err := db.DB.Exec(`UPDATE profiles SET avatar_url=$2, updated_at=now() WHERE user_id=$1`, userID, avatarURL)
	return err
}

func cleanupOldAvatar(userID, newURL string) {
	if db.DB == nil {
		return
	}
	var oldURL sql.NullString
	db.DB.QueryRow(`SELECT avatar_url FROM profiles WHERE user_id=$1`, userID).Scan(&oldURL)
	if !oldURL.Valid || oldURL.String == "" || oldURL.String == newURL {
		return
	}
	oldFilename := strings.TrimPrefix(oldURL.String, avatarURLPrefix)
	oldPath := filepath.Join(avatarUploadDir, filepath.Base(oldFilename))

	// Only delete if file is in our upload dir (safety check)
	absDir, _ := filepath.Abs(avatarUploadDir)
	absPath, _ := filepath.Abs(oldPath)
	if strings.HasPrefix(absPath, absDir+string(filepath.Separator)) {
		os.Remove(oldPath)
	}
}

// GetAvatarURL returns the user's custom avatar URL, or empty string if using preset
func GetAvatarURL(userID string) string {
	if db.DB == nil {
		return ""
	}
	var url sql.NullString
	db.DB.QueryRow(`SELECT avatar_url FROM profiles WHERE user_id=$1`, userID).Scan(&url)
	if url.Valid {
		return url.String
	}
	return ""
}

// ─── Rate limit for uploads (max 5 uploads per hour per user) ─

var avatarUploadLimiter = struct {
	mu      sync.Mutex
	buckets map[string]*uploadBucket
}{buckets: make(map[string]*uploadBucket)}

type uploadBucket struct {
	count    int
	resetAt  time.Time
}

func checkAvatarUploadLimit(userID string) bool {
	avatarUploadLimiter.mu.Lock()
	defer avatarUploadLimiter.mu.Unlock()

	now := time.Now()
	b, ok := avatarUploadLimiter.buckets[userID]
	if !ok || now.After(b.resetAt) {
		avatarUploadLimiter.buckets[userID] = &uploadBucket{count: 1, resetAt: now.Add(time.Hour)}
		return true
	}
	if b.count >= 5 {
		return false
	}
	b.count++
	return true
}

// CheckAvatarUploadLimit is the exported version for use in main.go
func CheckAvatarUploadLimit(userID string) bool {
	return checkAvatarUploadLimit(userID)
}

// HandleFCMToken registers or updates the user's FCM push notification token.
// POST /api/fcm/token — body: { "token": "...", "platform": "android|ios" }
func (s *Server) HandleFCMToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	userID := r.Context().Value(ContextKeyUserID).(string)

	var req struct {
		Token    string `json:"token"`
		Platform string `json:"platform"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		errorResponse(w, 400, "token required")
		return
	}
	if req.Platform == "" {
		req.Platform = "android"
	}
	if err := db.SaveFCMToken(userID, req.Token, req.Platform); err != nil {
		errorResponse(w, 500, "failed to save token")
		return
	}
	jsonResponse(w, 200, map[string]string{"status": "ok"})
}

// HandleDeleteAccount permanently deletes the user's account and all data.
// DELETE /api/account — requires password confirmation in body.
func (s *Server) HandleDeleteAccount(w http.ResponseWriter, r *http.Request) {
	if r.Method != "DELETE" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	userID := r.Context().Value(ContextKeyUserID).(string)

	var req struct {
		Password string `json:"password"` // Required for non-guest accounts
		Confirm  bool   `json:"confirm"`  // Must be true
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || !req.Confirm {
		errorResponse(w, 400, "confirm: true required")
		return
	}

	// Verify password for non-guest accounts
	if db.DB != nil {
		var isGuest bool
		var hash string
		db.DB.QueryRow(`SELECT is_guest, COALESCE(password_hash,'') FROM users WHERE id=$1`,
			userID).Scan(&isGuest, &hash)
		if !isGuest && hash != "" {
			if req.Password == "" {
				errorResponse(w, 400, "password required for non-guest accounts")
				return
			}
			// Verify password (import already available from handlers.go)
			if err := verifyPassword(hash, req.Password); err != nil {
				errorResponse(w, 401, "password salah")
				return
			}
		}
	}

	// Delete the uploaded avatar file from disk
	go cleanupOldAvatar(userID, "")

	// Delete account from DB (CASCADE removes all related data)
	if err := db.DeleteAccount(userID); err != nil {
		errorResponse(w, 500, "gagal menghapus akun")
		return
	}

	// Disconnect WS if online
	if s.Hub != nil {
		s.Hub.SendToUser(userID, "account_deleted", map[string]interface{}{
			"message": "Akun berhasil dihapus",
		})
	}

	// Revoke tokens
	db.DeleteFCMToken(userID)

	logger.Info(logger.CatAPI, "Account deleted", map[string]interface{}{"userId": userID})
	jsonResponse(w, 200, map[string]string{"message": "Akun berhasil dihapus permanen"})
}

func verifyPassword(hash, password string) error {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
}
