package ws

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"math/big"
	"strings"
	"time"
)

// generateID creates a cryptographically random hex ID.
// rand.Read never actually errors in Go's crypto/rand, but we check for correctness.
func generateID() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		// Extremely unlikely; fall back to time-based ID
		return fmt.Sprintf("%016x%016x", time.Now().UnixNano(), time.Now().UnixNano()+1)
	}
	return hex.EncodeToString(b)
}

// generateRoomCode creates a 6-character room code
func generateRoomCode() string {
	const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var sb strings.Builder
	for i := 0; i < 6; i++ {
		n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(chars))))
		sb.WriteByte(chars[n.Int64()])
	}
	return sb.String()
}
