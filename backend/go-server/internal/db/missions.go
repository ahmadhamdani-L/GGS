package db

import (
	"database/sql"
	"fmt"
	"time"
)

// Mission types
const (
	MissionTypeWinGame      = "win_game"
	MissionTypeSurvive      = "survive_rounds"
	MissionTypePlayAsRole   = "play_as_role"
	MissionTypeUseAbility   = "use_ability"
	MissionTypeVoteCorrect  = "vote_correct"
	MissionTypePlayGames    = "play_games"
)

// MissionTemplate defines a mission's requirements
type MissionTemplate struct {
	ID          string `json:"id"`
	Type        string `json:"type"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Target      int    `json:"target"`
	XPReward    int    `json:"xpReward"`
	CoinReward  int    `json:"coinReward"`
	Role        string `json:"role,omitempty"`    // For role-specific missions
	Ability     string `json:"ability,omitempty"` // For ability-specific missions
}

// DailyMission represents a player's daily mission
type DailyMission struct {
	ID          string    `json:"id"`
	UserID      string    `json:"userId"`
	TemplateID  string    `json:"templateId"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Type        string    `json:"type"`
	Target      int       `json:"target"`
	Progress    int       `json:"progress"`
	XPReward    int       `json:"xpReward"`
	CoinReward  int       `json:"coinReward"`
	IsCompleted bool      `json:"isCompleted"`
	IsClaimed   bool      `json:"isClaimed"`
	ExpiresAt   time.Time `json:"expiresAt"`
	CreatedAt   time.Time `json:"createdAt"`
}

// Available mission templates (rotated daily)
var missionTemplates = []MissionTemplate{
	// Easy missions (1-2 games)
	{ID: "m1", Type: MissionTypePlayGames, Title: "Pemain Aktif", Description: "Mainkan 1 game", Target: 1, XPReward: 50, CoinReward: 10},
	{ID: "m2", Type: MissionTypePlayGames, Title: "Semangat!", Description: "Mainkan 2 game", Target: 2, XPReward: 100, CoinReward: 20},
	
	// Win missions
	{ID: "m3", Type: MissionTypeWinGame, Title: "Kemenangan Pertama", Description: "Menangkan 1 game", Target: 1, XPReward: 150, CoinReward: 30},
	{ID: "m4", Type: MissionTypeWinGame, Title: "Pemenang Sejati", Description: "Menangkan 2 game", Target: 2, XPReward: 300, CoinReward: 50},
	
	// Survival missions
	{ID: "m5", Type: MissionTypeSurvive, Title: "Survivor", Description: "Bertahan hingga akhir game 1 kali", Target: 1, XPReward: 100, CoinReward: 25},
	{ID: "m6", Type: MissionTypeSurvive, Title: "Unkillable", Description: "Bertahan hingga akhir game 2 kali", Target: 2, XPReward: 200, CoinReward: 40},
	
	// Role-specific missions
	{ID: "m7", Type: MissionTypePlayAsRole, Title: "Malam Berbahaya", Description: "Main sebagai Werewolf 1 kali", Target: 1, XPReward: 100, CoinReward: 25, Role: "werewolf"},
	{ID: "m8", Type: MissionTypePlayAsRole, Title: "Mata Elang", Description: "Main sebagai Seer 1 kali", Target: 1, XPReward: 100, CoinReward: 25, Role: "seer"},
	{ID: "m9", Type: MissionTypePlayAsRole, Title: "Penyelamat", Description: "Main sebagai Doctor 1 kali", Target: 1, XPReward: 100, CoinReward: 25, Role: "doctor"},
	{ID: "m10", Type: MissionTypePlayAsRole, Title: "Penyihir Licik", Description: "Main sebagai Witch 1 kali", Target: 1, XPReward: 100, CoinReward: 25, Role: "witch"},
	
	// Ability missions
	{ID: "m11", Type: MissionTypeUseAbility, Title: "Penyihir Handal", Description: "Gunakan kemampuan 1 kali", Target: 1, XPReward: 120, CoinReward: 25, Ability: "any"},
	{ID: "m12", Type: MissionTypeUseAbility, Title: "Spiritualist", Description: "Gunakan kemampuan Seer/Guard", Target: 2, XPReward: 200, CoinReward: 40, Ability: "any"},
	{ID: "m13", Type: MissionTypeUseAbility, Title: "Hunter", Description: "Eliminasi 2 pemain sebagai Werewolf", Target: 2, XPReward: 200, CoinReward: 40, Ability: "kill"},
}

// Available weekly mission templates (rotated weekly)
var weeklyMissionTemplates = []MissionTemplate{
	{ID: "w_1", Type: MissionTypePlayGames, Title: "Pemain Setia", Description: "Mainkan 15 game", Target: 15, XPReward: 1000, CoinReward: 200},
	{ID: "w_2", Type: MissionTypeWinGame, Title: "Sang Penakluk", Description: "Menangkan 7 game", Target: 7, XPReward: 1500, CoinReward: 300},
	{ID: "w_3", Type: MissionTypeSurvive, Title: "Penyintas Sejati", Description: "Bertahan hidup 20 ronde", Target: 20, XPReward: 1200, CoinReward: 250},
	{ID: "w_4", Type: MissionTypeVoteCorrect, Title: "Detektif Handal", Description: "Voting benar 10 kali", Target: 10, XPReward: 1000, CoinReward: 200},
}

func getNextMonday() time.Time {
	now := time.Now()
	daysUntilMonday := (8 - int(now.Weekday())) % 7
	if daysUntilMonday == 0 {
		daysUntilMonday = 7 // Next week's Monday
	}
	return now.AddDate(0, 0, daysUntilMonday).Truncate(24 * time.Hour)
}

// GetDailyMissions returns active daily missions for a user
func GetDailyMissions(userID string) ([]DailyMission, error) {
	if DB == nil {
		if Mem != nil {
			return Mem.GetDailyMissions(userID)
		}
		return nil, fmt.Errorf("no database connection")
	}

	// Check if user has missions for today
	today := time.Now().Truncate(24 * time.Hour)
	tomorrow := today.Add(24 * time.Hour)

	rows, err := DB.Query(`
		SELECT id, user_id, template_id, title, description, type, target, progress, 
		       xp_reward, coin_reward, is_completed, is_claimed, expires_at, created_at
		FROM daily_missions 
		WHERE user_id = $1 AND expires_at > $2
		ORDER BY created_at ASC
	`, userID, time.Now())
	if err != nil {
		return nil, fmt.Errorf("query missions: %w", err)
	}
	defer rows.Close()

	var missions []DailyMission
	for rows.Next() {
		var m DailyMission
		if err := rows.Scan(&m.ID, &m.UserID, &m.TemplateID, &m.Title, &m.Description,
			&m.Type, &m.Target, &m.Progress, &m.XPReward, &m.CoinReward,
			&m.IsCompleted, &m.IsClaimed, &m.ExpiresAt, &m.CreatedAt); err != nil {
			continue
		}
		missions = append(missions, m)
	}

	var daily, weekly []DailyMission
	for _, m := range missions {
		if len(m.TemplateID) > 2 && m.TemplateID[:2] == "w_" {
			weekly = append(weekly, m)
		} else {
			daily = append(daily, m)
		}
	}

	// If no daily missions or less than 3, generate new ones
	if len(daily) < 3 {
		newDaily, err := generateDailyMissions(userID, tomorrow, 3-len(daily))
		if err == nil {
			daily = append(daily, newDaily...)
			missions = append(missions, newDaily...)
		}
	}

	// If no weekly missions or less than 2, generate new ones
	if len(weekly) < 2 {
		newWeekly, err := generateWeeklyMissions(userID, getNextMonday(), 2-len(weekly))
		if err == nil {
			weekly = append(weekly, newWeekly...)
			missions = append(missions, newWeekly...)
		}
	}

	return missions, nil
}

// generateWeeklyMissions creates new weekly missions for a user
func generateWeeklyMissions(userID string, expiresAt time.Time, count int) ([]DailyMission, error) {
	if count <= 0 {
		return nil, nil
	}

	// Use week of year as seed
	_, weekOfYear := time.Now().ISOWeek()
	startIdx := weekOfYear % len(weeklyMissionTemplates)

	var missions []DailyMission
	usedTemplates := make(map[string]bool)

	for i := 0; i < count && i < len(weeklyMissionTemplates); i++ {
		idx := (startIdx + i) % len(weeklyMissionTemplates)
		template := weeklyMissionTemplates[idx]
		
		if usedTemplates[template.ID] {
			for j := 1; j < len(weeklyMissionTemplates); j++ {
				altIdx := (idx + j) % len(weeklyMissionTemplates)
				if !usedTemplates[weeklyMissionTemplates[altIdx].ID] {
					template = weeklyMissionTemplates[altIdx]
					break
				}
			}
		}
		usedTemplates[template.ID] = true

		mission := DailyMission{
			ID:          fmt.Sprintf("wm_%s_%d_%d", userID[:8], weekOfYear, i),
			UserID:      userID,
			TemplateID:  template.ID,
			Title:       template.Title,
			Description: template.Description,
			Type:        template.Type,
			Target:      template.Target,
			Progress:    0,
			XPReward:    template.XPReward,
			CoinReward:  template.CoinReward,
			IsCompleted: false,
			IsClaimed:   false,
			ExpiresAt:   expiresAt,
			CreatedAt:   time.Now(),
		}

		if DB != nil {
			_, err := DB.Exec(`
				INSERT INTO daily_missions (id, user_id, template_id, title, description, type, target, progress, xp_reward, coin_reward, is_completed, is_claimed, expires_at, created_at)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
			`, mission.ID, mission.UserID, mission.TemplateID, mission.Title, mission.Description,
				mission.Type, mission.Target, mission.Progress, mission.XPReward, mission.CoinReward,
				mission.IsCompleted, mission.IsClaimed, mission.ExpiresAt, mission.CreatedAt)
			if err != nil {
				continue
			}
		}
		missions = append(missions, mission)
	}
	return missions, nil
}

// generateDailyMissions creates new daily missions for a user
func generateDailyMissions(userID string, expiresAt time.Time, count int) ([]DailyMission, error) {
	if count <= 0 {
		return nil, nil
	}

	// Pick random missions from templates
	// Use day of year as seed for consistent daily rotation
	dayOfYear := time.Now().YearDay()
	startIdx := dayOfYear % len(missionTemplates)

	var missions []DailyMission
	usedTemplates := make(map[string]bool)

	for i := 0; i < count && i < len(missionTemplates); i++ {
		idx := (startIdx + i*3) % len(missionTemplates)
		template := missionTemplates[idx]
		
		// Skip if already used this template
		if usedTemplates[template.ID] {
			// Try next template
			for j := 1; j < len(missionTemplates); j++ {
				altIdx := (idx + j) % len(missionTemplates)
				if !usedTemplates[missionTemplates[altIdx].ID] {
					template = missionTemplates[altIdx]
					break
				}
			}
		}
		usedTemplates[template.ID] = true

		mission := DailyMission{
			ID:          fmt.Sprintf("dm_%s_%d_%d", userID[:8], dayOfYear, i),
			UserID:      userID,
			TemplateID:  template.ID,
			Title:       template.Title,
			Description: template.Description,
			Type:        template.Type,
			Target:      template.Target,
			Progress:    0,
			XPReward:    template.XPReward,
			CoinReward:  template.CoinReward,
			IsCompleted: false,
			IsClaimed:   false,
			ExpiresAt:   expiresAt,
			CreatedAt:   time.Now(),
		}

		// Insert into database
		if DB != nil {
			_, err := DB.Exec(`
				INSERT INTO daily_missions (id, user_id, template_id, title, description, type, target, progress, xp_reward, coin_reward, is_completed, is_claimed, expires_at, created_at)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
				ON CONFLICT (id) DO NOTHING
			`, mission.ID, mission.UserID, mission.TemplateID, mission.Title, mission.Description,
				mission.Type, mission.Target, mission.Progress, mission.XPReward, mission.CoinReward,
				mission.IsCompleted, mission.IsClaimed, mission.ExpiresAt, mission.CreatedAt)
			if err != nil {
				continue
			}
		}

		missions = append(missions, mission)
	}

	return missions, nil
}

// UpdateMissionProgress updates mission progress based on game actions
func UpdateMissionProgress(userID string, missionType string, increment int, role string, ability string) error {
	if DB == nil {
		if Mem != nil {
			return Mem.UpdateMissionProgress(userID, missionType, increment, role, ability)
		}
		return nil
	}

	// Build query based on mission type
	query := `
		UPDATE daily_missions 
		SET progress = LEAST(progress + $1, target),
		    is_completed = (progress + $1 >= target)
		WHERE user_id = $2 
		  AND type = $3 
		  AND is_claimed = false 
		  AND expires_at > NOW()
	`
	args := []interface{}{increment, userID, missionType}

	// For role-specific missions, also check role matches
	// This is simplified - in production you'd join with a mission_metadata table
	_, err := DB.Exec(query, args...)
	return err
}

// ClaimMissionReward claims rewards for a completed mission
func ClaimMissionReward(userID, missionID string) (*DailyMission, error) {
	if DB == nil {
		if Mem != nil {
			return Mem.ClaimMissionReward(userID, missionID)
		}
		return nil, fmt.Errorf("no database connection")
	}

	// Get mission
	var m DailyMission
	err := DB.QueryRow(`
		SELECT id, user_id, template_id, title, description, type, target, progress, 
		       xp_reward, coin_reward, is_completed, is_claimed, expires_at, created_at
		FROM daily_missions 
		WHERE id = $1 AND user_id = $2
	`, missionID, userID).Scan(&m.ID, &m.UserID, &m.TemplateID, &m.Title, &m.Description,
		&m.Type, &m.Target, &m.Progress, &m.XPReward, &m.CoinReward,
		&m.IsCompleted, &m.IsClaimed, &m.ExpiresAt, &m.CreatedAt)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("mission not found")
		}
		return nil, err
	}

	// Validate mission can be claimed
	if !m.IsCompleted {
		return nil, fmt.Errorf("mission not completed")
	}
	if m.IsClaimed {
		return nil, fmt.Errorf("mission already claimed")
	}
	if time.Now().After(m.ExpiresAt) {
		return nil, fmt.Errorf("mission expired")
	}

	// Mark as claimed
	_, err = DB.Exec(`
		UPDATE daily_missions SET is_claimed = true WHERE id = $1
	`, missionID)
	if err != nil {
		return nil, err
	}

	// Award XP and coins
	_, err = DB.Exec(`
		UPDATE profiles 
		SET xp = xp + $1, coins = coins + $2, updated_at = NOW()
		WHERE user_id = $3
	`, m.XPReward, m.CoinReward, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to award rewards: %w", err)
	}

	// Check for level up
	CheckAndApplyLevelUp(userID)

	m.IsClaimed = true
	return &m, nil
}

// Memory implementation
func (m *MemStore) GetDailyMissions(userID string) ([]DailyMission, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// Generate default missions for memory DB
	today := time.Now().Truncate(24 * time.Hour)
	tomorrow := today.Add(24 * time.Hour)
	dayOfYear := time.Now().YearDay()

	missions := make([]DailyMission, 0, 3)
	for i := 0; i < 3 && i < len(missionTemplates); i++ {
		idx := (dayOfYear + i*3) % len(missionTemplates)
		template := missionTemplates[idx]
		missions = append(missions, DailyMission{
			ID:          fmt.Sprintf("dm_%s_%d_%d", userID[:8], dayOfYear, i),
			UserID:      userID,
			TemplateID:  template.ID,
			Title:       template.Title,
			Description: template.Description,
			Type:        template.Type,
			Target:      template.Target,
			Progress:    0,
			XPReward:    template.XPReward,
			CoinReward:  template.CoinReward,
			IsCompleted: false,
			IsClaimed:   false,
			ExpiresAt:   tomorrow,
			CreatedAt:   time.Now(),
		})
	}

	return missions, nil
}

func (m *MemStore) UpdateMissionProgress(userID string, missionType string, increment int, role string, ability string) error {
	// Memory DB doesn't persist mission progress
	return nil
}

func (m *MemStore) ClaimMissionReward(userID, missionID string) (*DailyMission, error) {
	// Memory DB returns a mock claimed mission
	return &DailyMission{
		ID:          missionID,
		UserID:      userID,
		IsClaimed:   true,
		IsCompleted: true,
	}, nil
}
