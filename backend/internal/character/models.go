package character

import (
	"time"

	"github.com/google/uuid"
)

// Character represents a D&D character
type Character struct {
	ID           uuid.UUID  `json:"id" db:"id"`
	UserID       uuid.UUID  `json:"user_id" db:"user_id"`
	Name         string     `json:"name" db:"name"`
	Race         string     `json:"race" db:"race"`
	Class        string     `json:"class" db:"class"`
	Level        int        `json:"level" db:"level"`
	Background   string     `json:"background" db:"background"`
	
	// Ability scores
	Strength     int        `json:"strength" db:"strength"`
	Dexterity    int        `json:"dexterity" db:"dexterity"`
	Constitution int        `json:"constitution" db:"constitution"`
	Intelligence int        `json:"intelligence" db:"intelligence"`
	Wisdom       int        `json:"wisdom" db:"wisdom"`
	Charisma     int        `json:"charisma" db:"charisma"`
	
	// Combat stats
	MaxHP        *int       `json:"max_hp" db:"max_hp"`
	CurrentHP    *int       `json:"current_hp" db:"current_hp"`
	ArmorClass   *int       `json:"armor_class" db:"armor_class"`
	
	// Additional fields
	Notes        *string    `json:"notes" db:"notes"`
	
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at" db:"updated_at"`
}

// CreateCharacterRequest represents a character creation request
type CreateCharacterRequest struct {
	Name         string `json:"name" binding:"required"`
	Race         string `json:"race" binding:"required"`
	Class        string `json:"class" binding:"required"`
	Level        int    `json:"level" binding:"required,min=1,max=20"`
	Background   string `json:"background" binding:"required"`
	Strength     int    `json:"strength" binding:"required,min=1,max=20"`
	Dexterity    int    `json:"dexterity" binding:"required,min=1,max=20"`
	Constitution int    `json:"constitution" binding:"required,min=1,max=20"`
	Intelligence int    `json:"intelligence" binding:"required,min=1,max=20"`
	Wisdom       int    `json:"wisdom" binding:"required,min=1,max=20"`
	Charisma     int    `json:"charisma" binding:"required,min=1,max=20"`
	MaxHP        *int   `json:"max_hp"`
	CurrentHP    *int   `json:"current_hp"`
	ArmorClass   *int   `json:"armor_class"`
	Notes        *string `json:"notes"`
}

// UpdateCharacterRequest represents a character update request
type UpdateCharacterRequest struct {
	Name         *string `json:"name"`
	Race         *string `json:"race"`
	Class        *string `json:"class"`
	Level        *int    `json:"level"`
	Background   *string `json:"background"`
	Strength     *int    `json:"strength"`
	Dexterity    *int    `json:"dexterity"`
	Constitution *int    `json:"constitution"`
	Intelligence *int    `json:"intelligence"`
	Wisdom       *int    `json:"wisdom"`
	Charisma     *int    `json:"charisma"`
	MaxHP        *int    `json:"max_hp"`
	CurrentHP    *int    `json:"current_hp"`
	ArmorClass   *int    `json:"armor_class"`
	Notes        *string `json:"notes"`
} 