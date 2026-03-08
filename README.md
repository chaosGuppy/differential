# Differential

## Prerequisites

- **Python 3.12+**
- **[uv](https://docs.astral.sh/uv/)** — Python package manager
- **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** — required by Supabase CLI
- **[Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started#installing-the-supabase-cli)** — manages the local Postgres instance
- **Anthropic API key** with credits on it

### Installing Supabase CLI

```bash
# macOS (Homebrew)
brew install supabase/tap/supabase

# npm
npm install -g supabase

# Or see https://supabase.com/docs/guides/local-development/cli/getting-started
```

## Setup

```bash
# 1. Install Python dependencies
uv sync

# 2. Start the local Supabase stack (Postgres, PostgREST, etc.)
#    First run will pull Docker images — may take a few minutes.
supabase start

# 3. Set your Anthropic API key
export ANTHROPIC_API_KEY="sk-ant-..."
#    Or create a .env file in the repo root:
#    ANTHROPIC_API_KEY=sk-ant-...
```

`supabase start` runs migrations automatically, so the database is ready to use immediately.

## Usage

```bash
# New investigation
uv run python main.py "Your question here" --budget 20

# Continue an existing question with more budget
uv run python main.py --continue QUESTION_ID --budget 10

# Add a question without investigating it yet
uv run python main.py --add-question "Some sub-question" --budget 0

# List all questions
uv run python main.py --list

# Ingest a source document
uv run python main.py --ingest FILE --for-question QUESTION_ID --budget 5

# Interactive chat about research
uv run python main.py --chat QUESTION_ID

# Generate HTML research map
uv run python main.py --map QUESTION_ID

# Generate executive summary
uv run python main.py --summary QUESTION_ID
```

For PDF ingestion, install the optional dependency: `uv sync --extra pdf`

## Development

```bash
# Run tests (uses an isolated 'test' schema — won't touch your data)
uv run pytest

# Stop the local Supabase stack
supabase stop

# Reset the database (re-applies all migrations, wipes data)
supabase db reset

# Create a new migration
supabase migration new my_migration_name
```

## Supabase Studio

While `supabase start` is running, you can browse your data at [http://127.0.0.1:54323](http://127.0.0.1:54323).
