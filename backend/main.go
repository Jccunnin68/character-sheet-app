package main

import (
	"database/sql"
	"log"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"

	"character-sheet-backend/internal/auth"
	"character-sheet-backend/internal/character"
	"character-sheet-backend/internal/database"
	"character-sheet-backend/internal/middleware"
)

func main() {
	// Get environment variables
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:password@localhost:5432/character_sheets?sslmode=disable"
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "dev-secret-key"
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Connect to database
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatal("Failed to ping database:", err)
	}

	// Initialize database
	if err := database.Initialize(db); err != nil {
		log.Fatal("Failed to initialize database:", err)
	}

	// Initialize services
	authService := auth.NewService(db, jwtSecret)
	characterService := character.NewService(db)

	// Initialize handlers
	authHandler := auth.NewHandler(authService)
	characterHandler := character.NewHandler(characterService)

	// Setup router
	r := gin.Default()

	// CORS middleware
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"http://localhost:3000", "http://frontend:3000"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// API routes
	api := r.Group("/api")
	{
		// Auth routes
		authRoutes := api.Group("/auth")
		{
			authRoutes.POST("/register", authHandler.Register)
			authRoutes.POST("/login", authHandler.Login)
			authRoutes.GET("/me", middleware.AuthMiddleware(jwtSecret), authHandler.GetMe)
		}

		// Character routes (protected)
		characterRoutes := api.Group("/characters")
		characterRoutes.Use(middleware.AuthMiddleware(jwtSecret))
		{
			characterRoutes.GET("", characterHandler.GetCharacters)
			characterRoutes.POST("", characterHandler.CreateCharacter)
			characterRoutes.GET("/:id", characterHandler.GetCharacter)
			characterRoutes.PUT("/:id", characterHandler.UpdateCharacter)
			characterRoutes.DELETE("/:id", characterHandler.DeleteCharacter)
		}
	}

	log.Printf("Server starting on port %s", port)
	log.Fatal(r.Run(":" + port))
} 