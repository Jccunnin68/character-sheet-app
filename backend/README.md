# Character Sheet Backend

Go-based backend API for the character sheet management application.

## Features

- RESTful API for character management
- JWT-based authentication
- PostgreSQL database integration
- User registration and login
- Character CRUD operations
- CORS support for frontend integration

## Technology Stack

- Go 1.21
- Gin web framework
- PostgreSQL with `lib/pq` driver
- JWT for authentication
- bcrypt for password hashing
- UUID for unique identifiers

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register a new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/me` - Get current user info (requires auth)

### Characters
- `GET /api/characters` - Get all characters for user (requires auth)
- `POST /api/characters` - Create new character (requires auth)
- `GET /api/characters/:id` - Get specific character (requires auth)
- `PUT /api/characters/:id` - Update character (requires auth)
- `DELETE /api/characters/:id` - Delete character (requires auth)

## Getting Started

### Prerequisites

- Go 1.21 or higher
- PostgreSQL database

### Installation

1. Install dependencies:
```bash
go mod download
```

2. Set environment variables:
```bash
export DATABASE_URL="postgres://user:password@localhost:5432/character_sheets?sslmode=disable"
export JWT_SECRET="your-secret-key"
export PORT="8080"
```

3. Run the application:
```bash
go run main.go
```

For development with hot reloading:
```bash
air
```

## Environment Variables

- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - Secret key for JWT tokens
- `PORT` - Server port (default: 8080)

## Docker

Build and run with Docker:

```bash
docker build -t character-sheet-backend .
docker run -p 8080:8080 character-sheet-backend
```

## Database Schema

The application automatically creates the following tables:

### users
- `id` (UUID, primary key)
- `name` (VARCHAR)
- `email` (VARCHAR, unique)
- `password_hash` (VARCHAR)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

### characters
- `id` (UUID, primary key)
- `user_id` (UUID, foreign key)
- `name` (VARCHAR)
- `race` (VARCHAR)
- `class` (VARCHAR)
- `level` (INTEGER)
- `background` (VARCHAR)
- `strength` (INTEGER)
- `dexterity` (INTEGER)
- `constitution` (INTEGER)
- `intelligence` (INTEGER)
- `wisdom` (INTEGER)
- `charisma` (INTEGER)
- `max_hp` (INTEGER, nullable)
- `current_hp` (INTEGER, nullable)
- `armor_class` (INTEGER, nullable)
- `notes` (TEXT, nullable)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP) 