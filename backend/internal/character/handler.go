package character

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Handler handles character HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new character handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// GetCharacters retrieves all characters for the authenticated user
func (h *Handler) GetCharacters(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	characters, err := h.service.GetCharactersByUserID(userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, characters)
}

// GetCharacter retrieves a specific character by ID
func (h *Handler) GetCharacter(c *gin.Context) {
	characterID := c.Param("id")
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	character, err := h.service.GetCharacterByID(characterID, userID.(string))
	if err != nil {
		if err.Error() == "character not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": "Character not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, character)
}

// CreateCharacter creates a new character
func (h *Handler) CreateCharacter(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var req CreateCharacterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	character, err := h.service.CreateCharacter(userID.(string), &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, character)
}

// UpdateCharacter updates an existing character
func (h *Handler) UpdateCharacter(c *gin.Context) {
	characterID := c.Param("id")
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	var req UpdateCharacterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	character, err := h.service.UpdateCharacter(characterID, userID.(string), &req)
	if err != nil {
		if err.Error() == "character not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": "Character not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, character)
}

// DeleteCharacter deletes a character
func (h *Handler) DeleteCharacter(c *gin.Context) {
	characterID := c.Param("id")
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	err := h.service.DeleteCharacter(characterID, userID.(string))
	if err != nil {
		if err.Error() == "character not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": "Character not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Character deleted successfully"})
} 