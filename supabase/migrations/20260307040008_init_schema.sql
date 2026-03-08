CREATE TABLE pages (
    id TEXT PRIMARY KEY,
    page_type TEXT NOT NULL,
    layer TEXT NOT NULL,
    workspace TEXT NOT NULL,
    content TEXT NOT NULL,
    summary TEXT NOT NULL,
    epistemic_status DOUBLE PRECISION DEFAULT 0.5,
    epistemic_type TEXT DEFAULT '',
    provenance_model TEXT DEFAULT '',
    provenance_call_type TEXT DEFAULT '',
    provenance_call_id TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL,
    superseded_by TEXT,
    is_superseded BOOLEAN DEFAULT FALSE,
    extra JSONB DEFAULT '{}'
);

CREATE TABLE page_links (
    id TEXT PRIMARY KEY,
    from_page_id TEXT NOT NULL REFERENCES pages(id),
    to_page_id TEXT NOT NULL REFERENCES pages(id),
    link_type TEXT NOT NULL,
    direction TEXT,
    strength DOUBLE PRECISION DEFAULT 0.5,
    reasoning TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE calls (
    id TEXT PRIMARY KEY,
    call_type TEXT NOT NULL,
    workspace TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    parent_call_id TEXT,
    scope_page_id TEXT REFERENCES pages(id),
    budget_allocated INTEGER,
    budget_used INTEGER DEFAULT 0,
    context_page_ids JSONB DEFAULT '[]',
    result_summary TEXT DEFAULT '',
    review_json JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ
);

CREATE TABLE budget (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    total INTEGER NOT NULL,
    used INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE page_ratings (
    id TEXT PRIMARY KEY,
    page_id TEXT NOT NULL REFERENCES pages(id),
    call_id TEXT NOT NULL REFERENCES calls(id),
    score INTEGER NOT NULL,
    note TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE page_flags (
    id TEXT PRIMARY KEY,
    flag_type TEXT NOT NULL,
    call_id TEXT,
    page_id TEXT,
    page_id_a TEXT,
    page_id_b TEXT,
    note TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL
);

-- Indexes for common query patterns
CREATE INDEX idx_pages_workspace_type ON pages(workspace, page_type);
CREATE INDEX idx_pages_is_superseded ON pages(is_superseded);
CREATE INDEX idx_page_links_from ON page_links(from_page_id);
CREATE INDEX idx_page_links_to ON page_links(to_page_id);
CREATE INDEX idx_page_links_type ON page_links(link_type);
CREATE INDEX idx_calls_scope ON calls(scope_page_id);
CREATE INDEX idx_calls_type_status ON calls(call_type, status);
CREATE INDEX idx_pages_provenance_call ON pages(provenance_call_id);

-- RPC: atomic budget consumption
CREATE OR REPLACE FUNCTION consume_budget(amount INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
    cur_total INTEGER;
    cur_used INTEGER;
BEGIN
    SELECT total, used INTO cur_total, cur_used FROM budget WHERE id = 1;
    IF cur_total IS NULL OR (cur_used + amount) > cur_total THEN
        RETURN FALSE;
    END IF;
    UPDATE budget SET used = used + amount WHERE id = 1;
    RETURN TRUE;
END;
$$;

-- RPC: atomic budget addition
CREATE OR REPLACE FUNCTION add_budget(amount INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE budget SET total = total + amount WHERE id = 1;
END;
$$;

-- RPC: atomic call budget_used increment
CREATE OR REPLACE FUNCTION increment_call_budget_used(call_id TEXT, amount INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE calls SET budget_used = budget_used + amount WHERE id = call_id;
END;
$$;

-- RPC: root questions (not appearing as child in any link)
CREATE OR REPLACE FUNCTION get_root_questions(ws TEXT)
RETURNS SETOF pages
LANGUAGE sql STABLE AS $$
    SELECT p.* FROM pages p
    WHERE p.page_type = 'question'
      AND p.workspace = ws
      AND p.is_superseded = FALSE
      AND p.id NOT IN (
          SELECT to_page_id FROM page_links WHERE link_type = 'child_question'
      )
    ORDER BY p.created_at DESC;
$$;

-- RPC: ingest history (which sources extracted against which questions)
CREATE OR REPLACE FUNCTION get_ingest_history()
RETURNS TABLE(source_id TEXT, question_id TEXT)
LANGUAGE sql STABLE AS $$
    SELECT DISTINCT c.scope_page_id AS source_id, pl.to_page_id AS question_id
    FROM calls c
    JOIN pages p ON p.provenance_call_id = c.id
    JOIN page_links pl ON pl.from_page_id = p.id AND pl.link_type = 'consideration'
    WHERE c.call_type = 'ingest' AND c.status = 'complete';
$$;

-- RPC: count active judgements for a question
CREATE OR REPLACE FUNCTION count_active_judgements(qid TEXT)
RETURNS BIGINT
LANGUAGE sql STABLE AS $$
    SELECT COUNT(*) FROM page_links pl
    JOIN pages p ON pl.from_page_id = p.id
    WHERE pl.to_page_id = qid AND p.page_type = 'judgement' AND p.is_superseded = FALSE;
$$;

-- Disable RLS on all tables (local-only, no auth needed)
ALTER TABLE pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE page_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget ENABLE ROW LEVEL SECURITY;
ALTER TABLE page_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE page_flags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow all" ON pages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON page_links FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON calls FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON budget FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON page_ratings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON page_flags FOR ALL USING (true) WITH CHECK (true);
