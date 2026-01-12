# CLAUDE.md - CodeTime Server

## Project Overview

This is a Rails 8 backend for the CodeTime VS Code extension. It tracks coding time by logging events and calculating duration using a gap-based algorithm.

## Quick Commands

```bash
# Setup (uses mise for Ruby version management)
eval "$(mise activate bash)"
bundle install
rails db:migrate
rails db:seed

# Run server
rails server

# Run tests
rails test
rails test test/controllers/
rails test test/integration/
```

## Architecture

- **Rails 8** full app (not API-only) with SQLite
- **Authentication**: Bearer token via `Authorization` header
- **API Endpoints**:
  - `POST /v3/users/event-log` - Log coding events
  - `GET /v3/users/self/minutes?minutes=N` - Get coding duration

## Key Files

| File | Purpose |
|------|---------|
| `app/services/time_calculator.rb` | Gap-based time calculation algorithm |
| `app/controllers/v3/users_controller.rb` | API endpoints |
| `app/controllers/concerns/authenticatable.rb` | Bearer token auth |
| `app/models/user.rb` | User with auto-generated token |
| `app/models/event_log.rb` | Event storage with validations |

## Development Guidelines

### Use mise for Ruby
All Ruby/Rails commands should use mise:
```bash
eval "$(mise activate bash)" && rails server
```

### TDD Approach
1. Write tests first (red)
2. Implement to pass tests (green)
3. Refactor while keeping tests green

### Test Time Handling
Always freeze time in tests using `setup`/`teardown`:
```ruby
FROZEN_TIME = Time.utc(2025, 1, 1, 18, 0, 0)
TEST_DAY = Time.utc(2025, 1, 1, 0, 0, 0)

setup do
  travel_to FROZEN_TIME
end

teardown do
  travel_back
end
```

**Never use `Time.current` or `Time.now` directly in tests** - it makes tests flaky.

### Testing Services
Don't test services in isolation with mocks. Test through the API endpoint that uses them:
```ruby
# BAD - testing service directly with mocks
events = [OpenStruct.new(event_time: time)]
calculator = TimeCalculator.new(events)

# GOOD - testing through API
create_event(time: TEST_DAY + 9.hours)
get v3_users_self_minutes_url, params: { minutes: 1440 }, headers: auth_headers
assert_equal 6, response.parsed_body["minutes"]
```

---

## Learnings from Development

### 1. Full Rails App vs API-Only
**Wrong assumption**: Use `rails new --api` for a backend.
**Correction**: Use full Rails app if UI might be needed later. The `--api` flag removes view layer, assets, and other features that are hard to add back.

### 2. Don't Skip Tests
**Wrong assumption**: Use `--skip-test` to reduce boilerplate.
**Correction**: Always include tests. Follow TDD - write comprehensive tests first.

### 3. Parameter Naming: camelCase vs snake_case
**Wrong assumption**: The controller can use snake_case params (`event_time`, `event_type`).
**Correction**: The VS Code extension sends camelCase (`eventTime`, `eventType`). Support both:
```ruby
def param_value(snake_key, camel_key)
  params[snake_key] || params[camel_key]
end

event_time_ms = param_value(:event_time, :eventTime).to_i
```

### 4. Time in Tests Must Be Frozen
**Wrong assumption**: Using `Time.current` in tests is fine.
**Correction**: Tests using real time are flaky. Always freeze to a specific point:
```ruby
# Use a fixed date in the past
FROZEN_TIME = Time.utc(2025, 1, 1, 18, 0, 0)
travel_to FROZEN_TIME
```

### 5. Use setup/teardown for Time Freezing
**Wrong assumption**: Wrap each test in `travel_to` block.
**Correction**: Use `setup`/`teardown` for cleaner code:
```ruby
setup do
  travel_to FROZEN_TIME
end

teardown do
  travel_back
end
```

### 6. Test Through APIs, Not Service Classes Directly
**Wrong assumption**: Test `TimeCalculator` by calling it directly with mock objects.
**Correction**: Since `TimeCalculator` is only called from the controller, test through the API endpoint. This:
- Uses real database records
- Tests the full integration
- Catches parameter handling issues
- Is more realistic

### 7. Plan in Phases for Complex Tasks
**Wrong assumption**: List implementation steps sequentially.
**Correction**: Split into discrete phases that can be delegated to sub-agents:
- Phase 1: Setup & Models
- Phase 2: Core Service
- Phase 3: API Controller
- Phase 4: Integration & Verification

Each phase has clear success criteria and can report back independently.
