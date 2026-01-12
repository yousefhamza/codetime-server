# CodeTime Server

A Rails 8 backend for the CodeTime VS Code extension. Tracks coding time by logging events and calculating duration using a gap-based algorithm.



## Integration
Replace original server from https://api.codetime.dev to local host
<img width="926" height="437" alt="Screenshot 2026-01-12 at 6 14 52 PM" src="https://github.com/user-attachments/assets/e8c2b6b9-5e23-4e9a-9e0b-3858eaf9914b" />

Add your token via VSCode commands like this (steps to generate the token below)
<img width="931" height="169" alt="Screenshot 2026-01-12 at 6 15 02 PM" src="https://github.com/user-attachments/assets/6a473626-d0db-4abf-a705-6a28c5bda54a" />


## Requirements

- Ruby 3.3.10 (managed via mise)
- SQLite3

## Setup

```bash
# Install dependencies
bundle install

# Create and migrate database
rails db:migrate

# Seed development user
rails db:seed
```

## Running the Server

```bash
rails server
```

The API will be available at `http://localhost:3000`.

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v3/users/event-log` | POST | Log a coding event |
| `/v3/users/self/minutes?minutes=N` | GET | Get coding duration for last N minutes |

### Authentication

All endpoints require Bearer token authentication:

```
Authorization: Bearer <token>
```

### Example Requests

**Log an event:**
```bash
curl -X POST http://localhost:3000/v3/users/event-log \
  -H "Authorization: Bearer dev-token-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "project": "my-project",
    "language": "ruby",
    "relativeFile": "app/models/user.rb",
    "absoluteFile": "/path/to/user.rb",
    "editor": "Visual Studio Code",
    "platform": "darwin",
    "platformArch": "arm64",
    "eventTime": 1736700000000,
    "eventType": "fileSaved",
    "operationType": "write"
  }'
```

**Query coding time:**
```bash
curl "http://localhost:3000/v3/users/self/minutes?minutes=1440" \
  -H "Authorization: Bearer dev-token-12345"
```

## Code Structure

```
app/
├── controllers/
│   ├── application_controller.rb    # Base controller with CSRF config
│   ├── concerns/
│   │   └── authenticatable.rb       # Bearer token authentication
│   └── v3/
│       └── users_controller.rb      # API endpoints (event_log, minutes)
├── models/
│   ├── user.rb                      # User with token auth, has_many event_logs
│   └── event_log.rb                 # Event storage with validations
└── services/
    └── time_calculator.rb           # Gap-based time calculation algorithm

config/
└── routes.rb                        # API routes under /v3 namespace

db/
├── migrate/
│   ├── *_create_users.rb            # Users table with unique email/token
│   └── *_create_event_logs.rb       # Event logs with composite index
├── schema.rb                        # Current database schema
└── seeds.rb                         # Development seed data
```

### Key Components

**User Model (`app/models/user.rb`)**
- Validates presence and uniqueness of email and token
- Auto-generates token on create if blank
- Has many event_logs (dependent: destroy)

**EventLog Model (`app/models/event_log.rb`)**
- Belongs to user
- Validates event_time and event_type presence
- Validates event_type is one of: `activateFileChanged`, `editorChanged`, `fileAddedLine`, `fileCreated`, `fileEdited`, `fileRemoved`, `fileSaved`, `changeEditorSelection`, `changeEditorVisibleRanges`
- Validates operation_type is `read` or `write` (optional)

**TimeCalculator Service (`app/services/time_calculator.rb`)**
- Implements gap-based time calculation
- Constants:
  - `IDLE_TIMEOUT_MS`: 300,000 (5 minutes)
  - `SINGLE_EVENT_CREDIT_MS`: 60,000 (1 minute)
  - `LAST_EVENT_CREDIT_MS`: 30,000 (30 seconds)
- Algorithm: Sum gaps between consecutive events if gap <= idle timeout, add last event credit

## Tests Structure

```
test/
├── test_helper.rb                   # Test configuration
├── fixtures/
│   ├── users.yml                    # User fixtures
│   └── event_logs.yml               # EventLog fixtures
├── models/
│   ├── user_test.rb                 # User model tests (14 tests)
│   └── event_log_test.rb            # EventLog model tests (25 tests)
├── services/
│   └── time_calculator_test.rb      # Time calculation tests (16 tests)
├── controllers/
│   └── v3/
│       └── users_controller_test.rb # API endpoint tests (18 tests)
└── integration/
    └── api_workflow_test.rb         # End-to-end workflow tests (6 tests)
```

### Running Tests

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/user_test.rb

# Run specific test directory
rails test test/models/
rails test test/services/
rails test test/controllers/
rails test test/integration/
```

**Total: 79 tests, 433 assertions**

## Seeding

The seed file creates a development user:

```bash
rails db:seed
```

This creates:
- Email: `dev@example.com`
- Token: `dev-token-12345`
- Name: `Developer`

To reset and re-seed:
```bash
rails db:reset  # Drops, creates, migrates, and seeds
```

## Generating Tokens

### Via Rails Console

```bash
rails console
```

**Create a new user with auto-generated token:**
```ruby
user = User.create!(email: 'user@example.com', name: 'New User')
puts user.token  # Auto-generated 64-character hex token
```

**Create a user with a custom token:**
```ruby
User.create!(
  email: 'user@example.com',
  name: 'New User',
  token: 'my-custom-token-here'
)
```

**Generate a new token for existing user:**
```ruby
user = User.find_by(email: 'user@example.com')
user.update!(token: SecureRandom.hex(32))
puts user.token
```

**List all users and tokens:**
```ruby
User.all.each { |u| puts "#{u.email}: #{u.token}" }
```

### Token Format

Auto-generated tokens are 64-character hexadecimal strings created using `SecureRandom.hex(32)`.

## VS Code Extension Configuration

To use with the CodeTime VS Code extension:

1. Open VS Code Settings
2. Search for "codetime"
3. Set `Server Entrypoint` to `http://localhost:3000`
4. When prompted, enter your token (e.g., `dev-token-12345`)

## Time Calculation Algorithm

The server uses a gap-based algorithm to calculate coding time:

1. Filter events within the requested time range
2. Sort events by timestamp
3. For each gap between consecutive events:
   - If gap <= 5 minutes: count as active time
   - If gap > 5 minutes: user was idle, skip
4. Add 30-second credit for the last event
5. Return total in minutes (floored)

**Example:**
Events at 09:00, 09:01:30, 09:03, 09:15, 09:16, 09:17:30

| Gap | Duration | Counts? |
|-----|----------|---------|
| 09:00 → 09:01:30 | 1.5 min | Yes |
| 09:01:30 → 09:03 | 1.5 min | Yes |
| 09:03 → 09:15 | 12 min | No (idle) |
| 09:15 → 09:16 | 1 min | Yes |
| 09:16 → 09:17:30 | 1.5 min | Yes |

Total: 5.5 min + 0.5 min credit = **6 minutes**
