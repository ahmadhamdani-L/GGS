package api

import (
	"crypto/sha512"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/ggs/werewolf-server/internal/db"
	"github.com/ggs/werewolf-server/internal/logger"
)

// ─── Midtrans Payment Integration ─────────────────────────────
//
// Flow:
// 1. Client calls POST /api/payment/create-order { "packageId": "diamond_100" }
// 2. Server creates a Snap token via Midtrans Snap API → returns snap_url + order_id
// 3. Client opens the snap_url in webview / browser
// 4. User pays via any Midtrans method (GoPay, OVO, VA, Credit Card, etc.)
// 5. Midtrans calls POST /api/payment/webhook (server-to-server notification)
// 6. Server validates signature → credits diamonds → sends push notification
//
// Setup:
//   - Set MIDTRANS_SERVER_KEY and MIDTRANS_CLIENT_KEY in .env
//   - Set MIDTRANS_ENV=sandbox (or "production")

// Diamond packages available for purchase
var diamondPackages = map[string]struct {
	Diamonds int
	Price    int // in IDR (Rupiah)
	Name     string
}{
	"diamond_50":   {Diamonds: 50, Price: 9900, Name: "50 Diamond"},
	"diamond_100":  {Diamonds: 100, Price: 18000, Name: "100 Diamond"},
	"diamond_300":  {Diamonds: 300, Price: 49000, Name: "300 Diamond"},
	"diamond_500":  {Diamonds: 500, Price: 79000, Name: "500 Diamond (+bonus)"},
	"diamond_1000": {Diamonds: 1000, Price: 149000, Name: "1000 Diamond (+bonus)"},
	"diamond_3000": {Diamonds: 3000, Price: 399000, Name: "3000 Diamond (+bonus)"},
	"diamond_5000": {Diamonds: 5000, Price: 649000, Name: "5000 Diamond (+bonus)"},
}

// HandleCreateOrder creates a Midtrans Snap transaction and returns the payment URL.
// POST /api/payment/create-order — body: { "packageId": "diamond_100" }
func (s *Server) HandleCreateOrder(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	userID := r.Context().Value(ContextKeyUserID).(string)

	var req struct {
		PackageID string `json:"packageId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.PackageID == "" {
		errorResponse(w, 400, "packageId required")
		return
	}

	pkg, ok := diamondPackages[req.PackageID]
	if !ok {
		errorResponse(w, 400, "paket tidak ditemukan")
		return
	}

	serverKey := os.Getenv("MIDTRANS_SERVER_KEY")
	if serverKey == "" {
		errorResponse(w, 503, "payment service not configured")
		return
	}

	// Generate unique order ID
	orderID := fmt.Sprintf("GGS-%s-%d", userID[:8], time.Now().UnixMilli())

	// Create Snap transaction via Midtrans API
	midtransEnv := os.Getenv("MIDTRANS_ENV")
	snapURL := "https://app.midtrans.com/snap/v1/transactions"
	if midtransEnv == "sandbox" || midtransEnv == "" {
		snapURL = "https://app.sandbox.midtrans.com/snap/v1/transactions"
	}

	snapPayload := map[string]interface{}{
		"transaction_details": map[string]interface{}{
			"order_id":     orderID,
			"gross_amount": pkg.Price,
		},
		"item_details": []map[string]interface{}{
			{"id": req.PackageID, "name": pkg.Name, "price": pkg.Price, "quantity": 1},
		},
		"customer_details": map[string]interface{}{
			"customer_id": userID,
		},
		"custom_field1": userID,     // user ID for webhook
		"custom_field2": req.PackageID, // package ID for webhook
	}

	payloadBytes, _ := json.Marshal(snapPayload)
	httpReq, _ := http.NewRequest("POST", snapURL, strings.NewReader(string(payloadBytes)))
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Accept", "application/json")
	httpReq.SetBasicAuth(serverKey, "")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		logger.Warn(logger.CatAPI, "Midtrans API error", map[string]interface{}{"err": err.Error()})
		errorResponse(w, 502, "payment gateway error")
		return
	}
	defer resp.Body.Close()

	var snapResp struct {
		Token       string `json:"token"`
		RedirectURL string `json:"redirect_url"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&snapResp); err != nil || snapResp.Token == "" {
		errorResponse(w, 502, "invalid response from payment gateway")
		return
	}

	// Save pending order to DB
	if db.DB != nil {
		db.DB.Exec(`
			INSERT INTO payment_orders (order_id, user_id, package_id, amount, status, created_at)
			VALUES ($1, $2, $3, $4, 'pending', now())
		`, orderID, userID, req.PackageID, pkg.Price)
	}

	logger.Info(logger.CatAPI, "Payment order created", map[string]interface{}{
		"orderId": orderID, "userId": userID, "package": req.PackageID, "amount": pkg.Price,
	})

	jsonResponse(w, 200, map[string]interface{}{
		"orderId":     orderID,
		"snapToken":   snapResp.Token,
		"redirectUrl": snapResp.RedirectURL,
		"package":     pkg.Name,
		"diamonds":    pkg.Diamonds,
		"price":       pkg.Price,
	})
}

// HandlePaymentWebhook processes Midtrans payment notification (server-to-server).
// POST /api/payment/webhook — called by Midtrans, NOT by the client.
func (s *Server) HandlePaymentWebhook(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 1<<16)

	var notif struct {
		OrderID           string `json:"order_id"`
		TransactionStatus string `json:"transaction_status"`
		StatusCode        string `json:"status_code"`
		GrossAmount       string `json:"gross_amount"`
		SignatureKey       string `json:"signature_key"`
		PaymentType       string `json:"payment_type"`
		CustomField1      string `json:"custom_field1"` // user_id
		CustomField2      string `json:"custom_field2"` // package_id
	}
	if err := json.NewDecoder(r.Body).Decode(&notif); err != nil {
		http.Error(w, "bad request", 400)
		return
	}

	// Validate signature to prevent spoofed notifications
	serverKey := os.Getenv("MIDTRANS_SERVER_KEY")
	if serverKey == "" {
		http.Error(w, "payment not configured", 503)
		return
	}

	// Midtrans signature = SHA512(order_id + status_code + gross_amount + server_key)
	signInput := notif.OrderID + notif.StatusCode + notif.GrossAmount + serverKey
	h := sha512.Sum512([]byte(signInput))
	expectedSig := hex.EncodeToString(h[:])
	if notif.SignatureKey != expectedSig {
		logger.Warn(logger.CatAPI, "Payment webhook: invalid signature", map[string]interface{}{
			"orderId": notif.OrderID,
		})
		http.Error(w, "invalid signature", 403)
		return
	}

	logger.Info(logger.CatAPI, "Payment webhook received", map[string]interface{}{
		"orderId": notif.OrderID, "status": notif.TransactionStatus,
		"userId": notif.CustomField1, "package": notif.CustomField2,
	})

	// Process based on transaction status
	switch notif.TransactionStatus {
	case "capture", "settlement":
		// Payment successful — credit diamonds
		userID := notif.CustomField1
		packageID := notif.CustomField2
		pkg, ok := diamondPackages[packageID]
		if !ok || userID == "" {
			logger.Warn(logger.CatAPI, "Payment webhook: unknown package or user", nil)
			w.WriteHeader(200) // ACK to Midtrans regardless
			return
		}

		// Credit diamonds (idempotent — orderID as refID prevents double-credit)
		newBalance, err := db.TopUpDiamonds(userID, int64(pkg.Diamonds), notif.OrderID, "purchase_"+packageID)
		if err != nil {
			if strings.Contains(err.Error(), "already processed") {
				w.WriteHeader(200) // Already credited — ACK
				return
			}
			logger.Warn(logger.CatAPI, "Payment webhook: credit failed", map[string]interface{}{
				"err": err.Error(), "orderId": notif.OrderID,
			})
			w.WriteHeader(200) // ACK anyway — we'll retry via reconciliation
			return
		}

		// Update order status
		if db.DB != nil {
			db.DB.Exec(`UPDATE payment_orders SET status='paid', paid_at=now() WHERE order_id=$1`, notif.OrderID)
		}

		// Notify user (push + WS)
		go SendPushNotification(userID, "💎 Diamond Diterima!",
			fmt.Sprintf("Kamu mendapat %d Diamond! Saldo: %d", pkg.Diamonds, newBalance),
			map[string]interface{}{"type": "diamond_topup", "diamonds": pkg.Diamonds, "balance": newBalance})

		if s.Hub != nil {
			s.Hub.SendToUser(userID, "diamond_credited", map[string]interface{}{
				"diamonds":   pkg.Diamonds,
				"newBalance": newBalance,
				"orderId":    notif.OrderID,
			})
		}

		logger.Info(logger.CatAPI, "Diamonds credited", map[string]interface{}{
			"userId": userID, "diamonds": pkg.Diamonds, "newBalance": newBalance,
		})

	case "deny", "cancel", "expire":
		// Payment failed — update order status
		if db.DB != nil {
			db.DB.Exec(`UPDATE payment_orders SET status=$2 WHERE order_id=$1`,
				notif.OrderID, notif.TransactionStatus)
		}

	case "pending":
		// Payment pending (e.g. VA transfer) — no action needed
		if db.DB != nil {
			db.DB.Exec(`UPDATE payment_orders SET status='pending_payment' WHERE order_id=$1`, notif.OrderID)
		}
	}

	w.WriteHeader(200) // Always ACK to Midtrans
}

// HandleGetPackages returns available diamond purchase packages.
// GET /api/payment/packages
func (s *Server) HandleGetPackages(w http.ResponseWriter, r *http.Request) {
	if r.Method != "GET" {
		errorResponse(w, 405, "method not allowed")
		return
	}
	type pkgResp struct {
		ID       string `json:"id"`
		Name     string `json:"name"`
		Diamonds int    `json:"diamonds"`
		Price    int    `json:"price"`
	}
	var packages []pkgResp
	for id, p := range diamondPackages {
		packages = append(packages, pkgResp{ID: id, Name: p.Name, Diamonds: p.Diamonds, Price: p.Price})
	}
	jsonResponse(w, 200, map[string]interface{}{"packages": packages})
}
