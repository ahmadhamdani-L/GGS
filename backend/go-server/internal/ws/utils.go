package ws

import (
	"crypto/rand"
	"encoding/hex"
	"math/big"
	"strings"
)

// generateID creates a random hex ID
func generateID() string {
	b := make([]byte, 16)
	rand.Read(b)
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
