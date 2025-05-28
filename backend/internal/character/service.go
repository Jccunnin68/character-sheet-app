package character

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// Service handles character operations
type Service struct {
	db *sql.DB
}

// NewService creates a new character service
func NewService(db *sql.DB) *Service {
	return &Service{db: db}
}

// GetCharactersByUserID retrieves all characters for a user
func (s *Service) GetCharactersByUserID(userID string) ([]*Character, error) {
	query := `
		SELECT id, user_id, name, race, class, level, background,
		       strength, dexterity, constitution, intelligence, wisdom, charisma,
		       max_hp, current_hp, armor_class, notes, created_at, updated_at
		FROM characters
		WHERE user_id = $1
		ORDER BY created_at DESC
	`

	rows, err := s.db.Query(query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query characters: %w", err)
	}
	defer rows.Close()

	var characters []*Character
	for rows.Next() {
		char := &Character{}
		err := rows.Scan(
			&char.ID, &char.UserID, &char.Name, &char.Race, &char.Class,
			&char.Level, &char.Background, &char.Strength, &char.Dexterity,
			&char.Constitution, &char.Intelligence, &char.Wisdom, &char.Charisma,
			&char.MaxHP, &char.CurrentHP, &char.ArmorClass, &char.Notes,
			&char.CreatedAt, &char.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan character: %w", err)
		}
		characters = append(characters, char)
	}

	return characters, nil
}

// GetCharacterByID retrieves a character by ID and user ID
func (s *Service) GetCharacterByID(characterID, userID string) (*Character, error) {
	char := &Character{}
	query := `
		SELECT id, user_id, name, race, class, level, background,
		       strength, dexterity, constitution, intelligence, wisdom, charisma,
		       max_hp, current_hp, armor_class, notes, created_at, updated_at
		FROM characters
		WHERE id = $1 AND user_id = $2
	`

	err := s.db.QueryRow(query, characterID, userID).Scan(
		&char.ID, &char.UserID, &char.Name, &char.Race, &char.Class,
		&char.Level, &char.Background, &char.Strength, &char.Dexterity,
		&char.Constitution, &char.Intelligence, &char.Wisdom, &char.Charisma,
		&char.MaxHP, &char.CurrentHP, &char.ArmorClass, &char.Notes,
		&char.CreatedAt, &char.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("character not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get character: %w", err)
	}

	return char, nil
}

// CreateCharacter creates a new character
func (s *Service) CreateCharacter(userID string, req *CreateCharacterRequest) (*Character, error) {
	character := &Character{
		ID:           uuid.New(),
		UserID:       uuid.MustParse(userID),
		Name:         req.Name,
		Race:         req.Race,
		Class:        req.Class,
		Level:        req.Level,
		Background:   req.Background,
		Strength:     req.Strength,
		Dexterity:    req.Dexterity,
		Constitution: req.Constitution,
		Intelligence: req.Intelligence,
		Wisdom:       req.Wisdom,
		Charisma:     req.Charisma,
		MaxHP:        req.MaxHP,
		CurrentHP:    req.CurrentHP,
		ArmorClass:   req.ArmorClass,
		Notes:        req.Notes,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	query := `
		INSERT INTO characters (
			id, user_id, name, race, class, level, background,
			strength, dexterity, constitution, intelligence, wisdom, charisma,
			max_hp, current_hp, armor_class, notes, created_at, updated_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19
		)
	`

	_, err := s.db.Exec(query,
		character.ID, character.UserID, character.Name, character.Race, character.Class,
		character.Level, character.Background, character.Strength, character.Dexterity,
		character.Constitution, character.Intelligence, character.Wisdom, character.Charisma,
		character.MaxHP, character.CurrentHP, character.ArmorClass, character.Notes,
		character.CreatedAt, character.UpdatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to create character: %w", err)
	}

	return character, nil
}

// UpdateCharacter updates an existing character
func (s *Service) UpdateCharacter(characterID, userID string, req *UpdateCharacterRequest) (*Character, error) {
	// First, get the existing character to ensure it belongs to the user
	existing, err := s.GetCharacterByID(characterID, userID)
	if err != nil {
		return nil, err
	}

	// Update fields if provided
	if req.Name != nil {
		existing.Name = *req.Name
	}
	if req.Race != nil {
		existing.Race = *req.Race
	}
	if req.Class != nil {
		existing.Class = *req.Class
	}
	if req.Level != nil {
		existing.Level = *req.Level
	}
	if req.Background != nil {
		existing.Background = *req.Background
	}
	if req.Strength != nil {
		existing.Strength = *req.Strength
	}
	if req.Dexterity != nil {
		existing.Dexterity = *req.Dexterity
	}
	if req.Constitution != nil {
		existing.Constitution = *req.Constitution
	}
	if req.Intelligence != nil {
		existing.Intelligence = *req.Intelligence
	}
	if req.Wisdom != nil {
		existing.Wisdom = *req.Wisdom
	}
	if req.Charisma != nil {
		existing.Charisma = *req.Charisma
	}
	if req.MaxHP != nil {
		existing.MaxHP = req.MaxHP
	}
	if req.CurrentHP != nil {
		existing.CurrentHP = req.CurrentHP
	}
	if req.ArmorClass != nil {
		existing.ArmorClass = req.ArmorClass
	}
	if req.Notes != nil {
		existing.Notes = req.Notes
	}

	existing.UpdatedAt = time.Now()

	query := `
		UPDATE characters SET
			name = $3, race = $4, class = $5, level = $6, background = $7,
			strength = $8, dexterity = $9, constitution = $10, intelligence = $11,
			wisdom = $12, charisma = $13, max_hp = $14, current_hp = $15,
			armor_class = $16, notes = $17, updated_at = $18
		WHERE id = $1 AND user_id = $2
	`

	_, err = s.db.Exec(query,
		characterID, userID, existing.Name, existing.Race, existing.Class,
		existing.Level, existing.Background, existing.Strength, existing.Dexterity,
		existing.Constitution, existing.Intelligence, existing.Wisdom, existing.Charisma,
		existing.MaxHP, existing.CurrentHP, existing.ArmorClass, existing.Notes,
		existing.UpdatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to update character: %w", err)
	}

	return existing, nil
}

// DeleteCharacter deletes a character
func (s *Service) DeleteCharacter(characterID, userID string) error {
	result, err := s.db.Exec("DELETE FROM characters WHERE id = $1 AND user_id = $2", characterID, userID)
	if err != nil {
		return fmt.Errorf("failed to delete character: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("character not found")
	}

	return nil
} 