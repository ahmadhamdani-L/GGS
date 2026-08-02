package db

import (
	"errors"
	"time"
)

type Guild struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Tag         string    `json:"tag"`
	Description string    `json:"description"`
	LeaderID    string    `json:"leaderId"`
	AvatarURL   string    `json:"avatarUrl,omitempty"`
	Level       int       `json:"level"`
	XP          int64     `json:"xp"`
	MaxMembers  int       `json:"maxMembers"`
	IsPublic    bool      `json:"isPublic"`
	MemberCount int       `json:"memberCount"`
	CreatedAt   time.Time `json:"createdAt"`
}

type GuildMember struct {
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
	Role        string `json:"role"`
	Level       int    `json:"level"`
	JoinedAt    string `json:"joinedAt"`
}

func CreateGuild(leaderID, name, tag, description string) (*Guild, error) {
	if DB == nil { return nil, errors.New("db unavailable") }
	if len(tag) < 2 || len(tag) > 6 { return nil, errors.New("tag harus 2-6 karakter") }

	// Check if user already in a guild
	var existing int
	DB.QueryRow(`SELECT COUNT(*) FROM guild_members WHERE user_id=$1`, leaderID).Scan(&existing)
	if existing > 0 { return nil, errors.New("kamu sudah punya guild") }

	g := &Guild{}
	err := DB.QueryRow(`
		INSERT INTO guilds (name, tag, description, leader_id)
		VALUES ($1, $2, $3, $4)
		RETURNING id, name, tag, description, leader_id, level, xp, max_members, is_public, created_at
	`, name, tag, description, leaderID).Scan(
		&g.ID, &g.Name, &g.Tag, &g.Description, &g.LeaderID,
		&g.Level, &g.XP, &g.MaxMembers, &g.IsPublic, &g.CreatedAt)
	if err != nil { return nil, errors.New("nama atau tag guild sudah dipakai") }

	// Add leader as member
	DB.Exec(`INSERT INTO guild_members (guild_id, user_id, role) VALUES ($1, $2, 'leader')`, g.ID, leaderID)
	DB.Exec(`UPDATE profiles SET guild_id=$2 WHERE user_id=$1`, leaderID, g.ID)
	g.MemberCount = 1
	return g, nil
}

func GetGuild(guildID string) (*Guild, error) {
	if DB == nil { return nil, nil }
	g := &Guild{}
	err := DB.QueryRow(`
		SELECT g.id, g.name, g.tag, g.description, g.leader_id, COALESCE(g.avatar_url,''),
		       g.level, g.xp, g.max_members, g.is_public, g.created_at,
		       (SELECT COUNT(*) FROM guild_members WHERE guild_id=g.id)
		FROM guilds g WHERE g.id=$1
	`, guildID).Scan(&g.ID, &g.Name, &g.Tag, &g.Description, &g.LeaderID, &g.AvatarURL,
		&g.Level, &g.XP, &g.MaxMembers, &g.IsPublic, &g.CreatedAt, &g.MemberCount)
	if err != nil { return nil, err }
	return g, nil
}

func GetGuildMembers(guildID string) ([]GuildMember, error) {
	if DB == nil { return nil, nil }
	rows, err := DB.Query(`
		SELECT gm.user_id, p.display_name, gm.role, p.level, TO_CHAR(gm.joined_at,'YYYY-MM-DD')
		FROM guild_members gm
		JOIN profiles p ON p.user_id = gm.user_id
		WHERE gm.guild_id=$1
		ORDER BY gm.role ASC, gm.joined_at ASC
	`, guildID)
	if err != nil { return nil, err }
	defer rows.Close()
	var members []GuildMember
	for rows.Next() {
		var m GuildMember
		rows.Scan(&m.UserID, &m.DisplayName, &m.Role, &m.Level, &m.JoinedAt)
		members = append(members, m)
	}
	return members, nil
}

func JoinGuild(userID, guildID string) error {
	if DB == nil { return nil }
	var existing int
	DB.QueryRow(`SELECT COUNT(*) FROM guild_members WHERE user_id=$1`, userID).Scan(&existing)
	if existing > 0 { return errors.New("kamu sudah punya guild") }

	var memberCount, maxMembers int
	DB.QueryRow(`SELECT (SELECT COUNT(*) FROM guild_members WHERE guild_id=$1), max_members FROM guilds WHERE id=$1`, guildID).Scan(&memberCount, &maxMembers)
	if memberCount >= maxMembers { return errors.New("guild sudah penuh") }

	_, err := DB.Exec(`INSERT INTO guild_members (guild_id, user_id, role) VALUES ($1, $2, 'member')`, guildID, userID)
	if err != nil { return errors.New("gagal bergabung") }
	DB.Exec(`UPDATE profiles SET guild_id=$2 WHERE user_id=$1`, userID, guildID)
	return nil
}

func LeaveGuild(userID string) error {
	if DB == nil { return nil }
	DB.Exec(`DELETE FROM guild_members WHERE user_id=$1`, userID)
	DB.Exec(`UPDATE profiles SET guild_id=NULL WHERE user_id=$1`, userID)
	return nil
}

func SearchGuilds(query string, limit int) ([]Guild, error) {
	if DB == nil { return nil, nil }
	rows, err := DB.Query(`
		SELECT g.id, g.name, g.tag, g.description, g.leader_id, COALESCE(g.avatar_url,''),
		       g.level, g.xp, g.max_members, g.is_public, g.created_at,
		       (SELECT COUNT(*) FROM guild_members WHERE guild_id=g.id)
		FROM guilds g
		WHERE g.is_public=true AND (LOWER(g.name) LIKE LOWER($1) OR LOWER(g.tag) LIKE LOWER($1))
		ORDER BY g.level DESC LIMIT $2
	`, "%"+query+"%", limit)
	if err != nil { return nil, err }
	defer rows.Close()
	var guilds []Guild
	for rows.Next() {
		var g Guild
		rows.Scan(&g.ID, &g.Name, &g.Tag, &g.Description, &g.LeaderID, &g.AvatarURL,
			&g.Level, &g.XP, &g.MaxMembers, &g.IsPublic, &g.CreatedAt, &g.MemberCount)
		guilds = append(guilds, g)
	}
	return guilds, nil
}

func GetGuildChat(guildID string, limit int) ([]map[string]interface{}, error) {
	if DB == nil { return nil, nil }
	rows, err := DB.Query(`
		SELECT id, sender_id, sender_name, content, created_at
		FROM guild_chat WHERE guild_id=$1 ORDER BY created_at DESC LIMIT $2
	`, guildID, limit)
	if err != nil { return nil, err }
	defer rows.Close()
	var msgs []map[string]interface{}
	for rows.Next() {
		var id, senderID, senderName, content string
		var createdAt time.Time
		rows.Scan(&id, &senderID, &senderName, &content, &createdAt)
		msgs = append(msgs, map[string]interface{}{
			"id": id, "senderId": senderID, "senderName": senderName,
			"content": content, "createdAt": createdAt,
		})
	}
	return msgs, nil
}

func SendGuildChat(guildID, senderID, senderName, content string) error {
	if DB == nil { return nil }
	_, err := DB.Exec(`
		INSERT INTO guild_chat (guild_id, sender_id, sender_name, content) VALUES ($1,$2,$3,$4)
	`, guildID, senderID, senderName, content)
	return err
}
