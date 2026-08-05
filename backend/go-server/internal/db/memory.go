package db

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/bcrypt"
)

// MemStore is an in-memory fallback when PostgreSQL is unavailable
type MemStore struct {
	users       map[string]*User
	emails      map[string]string
	profiles    map[string]*Profile
	chibiConfigs map[string]map[string]interface{}
	stats       map[string]*PlayerStats
	history     map[string][]MatchHistoryEntry
	diamonds    map[string]int64
	mu          sync.RWMutex
}

var Mem *MemStore

func InitMemoryStore() {
	Mem = &MemStore{
		users:        make(map[string]*User),
		emails:       make(map[string]string),
		profiles:     make(map[string]*Profile),
		chibiConfigs: make(map[string]map[string]interface{}),
		stats:        make(map[string]*PlayerStats),
		history:      make(map[string][]MatchHistoryEntry),
		diamonds:     make(map[string]int64),
	}
}

func newID() string {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return fmt.Sprintf("%016x", time.Now().UnixNano())
	}
	return hex.EncodeToString(b)
}

func (m *MemStore) CreateUser(email, password, displayName string) (*User, *Profile, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.emails[email]; exists {
		return nil, nil, errors.New("email already registered")
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	id := newID()
	user := &User{ID: id, Email: &email, PasswordHash: string(hash), IsGuest: false, CreatedAt: time.Now()}
	profile := &Profile{UserID: id, DisplayName: displayName, AvatarID: 1, Coins: 100, Level: 1}

	m.users[id] = user
	m.emails[email] = id
	m.profiles[id] = profile
	m.stats[id] = &PlayerStats{UserID: id, Rating: 1000, RankTier: "bronze"}
	return user, profile, nil
}

func (m *MemStore) CreateGuest(displayName string) (*User, *Profile, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	id := newID()
	if displayName == "" {
		displayName = "Tamu_" + id[:6]
	}
	user := &User{ID: id, IsGuest: true, CreatedAt: time.Now()}
	profile := &Profile{UserID: id, DisplayName: displayName, AvatarID: 1, Coins: 50, Level: 1}

	m.users[id] = user
	m.profiles[id] = profile
	m.stats[id] = &PlayerStats{UserID: id, Rating: 1000, RankTier: "bronze"}
	return user, profile, nil
}

func (m *MemStore) LoginUser(email, password string) (*User, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	id, ok := m.emails[email]
	if !ok {
		return nil, errors.New("invalid email or password")
	}
	user := m.users[id]
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return nil, errors.New("invalid email or password")
	}
	return user, nil
}

func (m *MemStore) GetUserByID(userID string) (*User, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	user, ok := m.users[userID]
	if !ok {
		return nil, errors.New("user not found")
	}
	return user, nil
}

func (m *MemStore) GetProfile(userID string) (*Profile, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	p, ok := m.profiles[userID]
	if !ok {
		return nil, errors.New("profile not found")
	}
	// Include chibi config
	if chibi, exists := m.chibiConfigs[userID]; exists {
		p.ChibiConfig = chibi
	} else {
		p.ChibiConfig = DefaultChibiConfig()
	}
	return p, nil
}

func (m *MemStore) UpdateProfile(userID, displayName string, avatarID int) (*Profile, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.profiles[userID]
	if !ok {
		return nil, errors.New("profile not found")
	}
	if displayName != "" {
		p.DisplayName = displayName
	}
	if avatarID >= 1 && avatarID <= MaxAvatarID {
		p.AvatarID = avatarID
	}
	// Include chibi config in response
	if chibi, exists := m.chibiConfigs[userID]; exists {
		p.ChibiConfig = chibi
	} else {
		p.ChibiConfig = DefaultChibiConfig()
	}
	return p, nil
}

// UpdateChibiConfig updates the chibi avatar configuration in memory
func (m *MemStore) UpdateChibiConfig(userID string, config map[string]interface{}) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	if _, ok := m.profiles[userID]; !ok {
		return errors.New("profile not found")
	}
	
	// Add version if not present
	if _, ok := config["version"]; !ok {
		config["version"] = 1
	}
	
	m.chibiConfigs[userID] = config
	return nil
}

func (m *MemStore) GetPlayerStats(userID string) (*PlayerStats, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	s, ok := m.stats[userID]
	if !ok {
		return nil, errors.New("stats not found")
	}
	return s, nil
}

func (m *MemStore) GetMatchHistory(userID string, limit int) ([]MatchHistoryEntry, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	h := m.history[userID]
	if limit > 0 && len(h) > limit {
		h = h[:limit]
	}
	return h, nil
}

func (m *MemStore) GetLeaderboard(sortBy string, limit int) ([]LeaderboardEntry, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	var entries []LeaderboardEntry
	for _, p := range m.profiles {
		s := m.stats[p.UserID]
		rating := 1000
		if s != nil {
			rating = s.Rating
		}
		entries = append(entries, LeaderboardEntry{
			UserID: p.UserID, DisplayName: p.DisplayName, AvatarID: p.AvatarID,
			Level: p.Level, XP: p.XP, GamesWon: p.GamesWon,
			GamesPlayed: p.GamesPlayed, Rating: rating, RankTier: "bronze",
		})
	}
	if limit > 0 && len(entries) > limit {
		entries = entries[:limit]
	}
	return entries, nil
}

func (m *MemStore) ConvertGuest(userID, email, password string) (*User, *Profile, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	user, exists := m.users[userID]
	if !exists || !user.IsGuest {
		return nil, nil, errors.New("user is not a guest account or not found")
	}

	if _, emailExists := m.emails[email]; emailExists {
		return nil, nil, errors.New("email already registered")
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	user.Email = &email
	user.PasswordHash = string(hash)
	user.IsGuest = false

	m.emails[email] = userID
	profile := m.profiles[userID]

	return user, profile, nil
}

func (m *MemStore) ResetPassword(email, newPassword string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	userID, exists := m.emails[email]
	if !exists {
		return errors.New("email not found")
	}

	user, ok := m.users[userID]
	if !ok {
		return errors.New("email not found")
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	user.PasswordHash = string(hash)
	return nil
}

func (m *MemStore) SearchUsers(query string) []Profile {
	m.mu.RLock()
	defer m.mu.RUnlock()

	q := strings.ToLower(strings.TrimSpace(query))
	if q == "" {
		return []Profile{}
	}

	results := make([]Profile, 0)
	for _, p := range m.profiles {
		name := strings.ToLower(p.DisplayName)
		id := strings.ToLower(p.UserID)
		if strings.Contains(name, q) || strings.Contains(id, q) {
			pCopy := *p
			if pCopy.Charm == 0 {
				pCopy.Charm = 300
			}
			if pCopy.Popularity == 0 {
				pCopy.Popularity = 150
			}
			pCopy.RankTier = CalculateRankTier(pCopy.XP)
			results = append(results, pCopy)
		}
	}
	return results
}

func (m *MemStore) UpdateCharmPopularity(userID string, charmDelta, popDelta int) {
	m.mu.Lock()
	defer m.mu.Unlock()

	p, ok := m.profiles[userID]
	if !ok {
		return
	}
	if p.Charm == 0 {
		p.Charm = 300
	}
	if p.Popularity == 0 {
		p.Popularity = 150
	}
	p.Charm += charmDelta
	p.Popularity += popDelta
	if p.Charm < 0 {
		p.Charm = 0
	}
	if p.Popularity < 0 {
		p.Popularity = 0
	}
}


// ─── Diamond Balance (Memory) ────────────────────────────────

func (m *MemStore) GetDiamondBalance(userID string) *DiamondBalance {
	m.mu.RLock()
	amount, ok := m.diamonds[userID]
	m.mu.RUnlock()

	if !ok {
		// First access: give default 100 diamonds (matches migration default)
		m.mu.Lock()
		m.diamonds[userID] = 100
		m.mu.Unlock()
		return &DiamondBalance{UserID: userID, Amount: 100}
	}
	return &DiamondBalance{UserID: userID, Amount: amount}
}

func (m *MemStore) TopUpDiamonds(userID string, amount int64) int64 {
	m.mu.Lock()
	defer m.mu.Unlock()

	current, ok := m.diamonds[userID]
	if !ok {
		current = 100 // default
	}
	current += amount
	m.diamonds[userID] = current
	return current
}

func (m *MemStore) SpendDiamonds(userID string, amount int64) (int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	current, ok := m.diamonds[userID]
	if !ok {
		current = 100
	}
	if current < amount {
		return current, errors.New("diamond tidak cukup")
	}
	current -= amount
	m.diamonds[userID] = current
	return current, nil
}
