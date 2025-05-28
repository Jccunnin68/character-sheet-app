# Database Setup

PostgreSQL database schema and initialization files for the character sheet application.

## Structure

```
database/
├── init/
│   └── 01-init.sql     # Database initialization script
└── README.md           # This file
```

## Database Schema

### Tables

#### users
Stores user account information.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY | Unique user identifier |
| name | VARCHAR(255) | NOT NULL | User's display name |
| email | VARCHAR(255) | UNIQUE, NOT NULL | User's email address |
| password_hash | VARCHAR(255) | NOT NULL | Hashed password |
| created_at | TIMESTAMP | DEFAULT NOW() | Account creation time |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update time |

#### characters
Stores character sheet information.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PRIMARY KEY | Unique character identifier |
| user_id | UUID | FOREIGN KEY, NOT NULL | Reference to users table |
| name | VARCHAR(255) | NOT NULL | Character name |
| race | VARCHAR(100) | NOT NULL | Character race |
| class | VARCHAR(100) | NOT NULL | Character class |
| level | INTEGER | NOT NULL, DEFAULT 1 | Character level (1-20) |
| background | VARCHAR(100) | NOT NULL | Character background |
| strength | INTEGER | NOT NULL, DEFAULT 10 | Strength ability score |
| dexterity | INTEGER | NOT NULL, DEFAULT 10 | Dexterity ability score |
| constitution | INTEGER | NOT NULL, DEFAULT 10 | Constitution ability score |
| intelligence | INTEGER | NOT NULL, DEFAULT 10 | Intelligence ability score |
| wisdom | INTEGER | NOT NULL, DEFAULT 10 | Wisdom ability score |
| charisma | INTEGER | NOT NULL, DEFAULT 10 | Charisma ability score |
| max_hp | INTEGER | NULLABLE | Maximum hit points |
| current_hp | INTEGER | NULLABLE | Current hit points |
| armor_class | INTEGER | NULLABLE | Armor class |
| notes | TEXT | NULLABLE | Additional character notes |
| created_at | TIMESTAMP | DEFAULT NOW() | Character creation time |
| updated_at | TIMESTAMP | DEFAULT NOW() | Last update time |

### Indexes

- `idx_characters_user_id` - Index on characters.user_id for efficient user queries
- `idx_users_email` - Index on users.email for efficient login queries

## Local Development

The database is automatically initialized when using Docker Compose. The initialization script in `init/01-init.sql` will:

1. Create the required extensions (uuid-ossp)
2. Create the users and characters tables
3. Set up indexes for performance
4. Configure appropriate constraints and relationships

## Production Deployment

For production deployment to AWS RDS:

1. Use the SQL scripts in the `init/` directory to set up the database schema
2. Configure appropriate security groups and access controls
3. Set up automated backups and monitoring
4. Consider read replicas for high availability

## Environment Variables

The application expects the following database connection format:

```
DATABASE_URL=postgres://username:password@hostname:port/database_name?sslmode=require
```

For local development:
```
DATABASE_URL=postgres://postgres:password@localhost:5432/character_sheets?sslmode=disable
``` 