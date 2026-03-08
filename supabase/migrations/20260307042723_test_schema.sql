-- Isolated test schema so tests don't clobber production data.
CREATE SCHEMA IF NOT EXISTS test;

-- Grant access to PostgREST roles.
GRANT USAGE ON SCHEMA test TO anon, authenticated, service_role;

CREATE TABLE test.pages (LIKE public.pages INCLUDING ALL);
CREATE TABLE test.page_links (LIKE public.page_links INCLUDING ALL);
CREATE TABLE test.calls (LIKE public.calls INCLUDING ALL);
CREATE TABLE test.budget (LIKE public.budget INCLUDING ALL);
CREATE TABLE test.page_ratings (LIKE public.page_ratings INCLUDING ALL);
CREATE TABLE test.page_flags (LIKE public.page_flags INCLUDING ALL);

-- Foreign keys aren't copied by LIKE, so add them explicitly.
ALTER TABLE test.page_links
    ADD FOREIGN KEY (from_page_id) REFERENCES test.pages(id),
    ADD FOREIGN KEY (to_page_id) REFERENCES test.pages(id);
ALTER TABLE test.calls
    ADD FOREIGN KEY (scope_page_id) REFERENCES test.pages(id);
ALTER TABLE test.page_ratings
    ADD FOREIGN KEY (page_id) REFERENCES test.pages(id),
    ADD FOREIGN KEY (call_id) REFERENCES test.calls(id);

-- RPC functions scoped to the test schema.
CREATE OR REPLACE FUNCTION test.consume_budget(amount INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
DECLARE
    cur_total INTEGER;
    cur_used INTEGER;
BEGIN
    SELECT total, used INTO cur_total, cur_used FROM test.budget WHERE id = 1;
    IF cur_total IS NULL OR (cur_used + amount) > cur_total THEN
        RETURN FALSE;
    END IF;
    UPDATE test.budget SET used = used + amount WHERE id = 1;
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION test.add_budget(amount INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE test.budget SET total = total + amount WHERE id = 1;
END;
$$;

CREATE OR REPLACE FUNCTION test.increment_call_budget_used(call_id TEXT, amount INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE test.calls SET budget_used = budget_used + amount WHERE id = call_id;
END;
$$;

CREATE OR REPLACE FUNCTION test.get_root_questions(ws TEXT)
RETURNS SETOF test.pages
LANGUAGE sql STABLE AS $$
    SELECT p.* FROM test.pages p
    WHERE p.page_type = 'question'
      AND p.workspace = ws
      AND p.is_superseded = FALSE
      AND p.id NOT IN (
          SELECT to_page_id FROM test.page_links WHERE link_type = 'child_question'
      )
    ORDER BY p.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION test.get_ingest_history()
RETURNS TABLE(source_id TEXT, question_id TEXT)
LANGUAGE sql STABLE AS $$
    SELECT DISTINCT c.scope_page_id AS source_id, pl.to_page_id AS question_id
    FROM test.calls c
    JOIN test.pages p ON p.provenance_call_id = c.id
    JOIN test.page_links pl ON pl.from_page_id = p.id AND pl.link_type = 'consideration'
    WHERE c.call_type = 'ingest' AND c.status = 'complete';
$$;

CREATE OR REPLACE FUNCTION test.count_active_judgements(qid TEXT)
RETURNS BIGINT
LANGUAGE sql STABLE AS $$
    SELECT COUNT(*) FROM test.page_links pl
    JOIN test.pages p ON pl.from_page_id = p.id
    WHERE pl.to_page_id = qid AND p.page_type = 'judgement' AND p.is_superseded = FALSE;
$$;

-- RLS: allow-all policies for the test schema tables.
ALTER TABLE test.pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE test.page_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE test.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE test.budget ENABLE ROW LEVEL SECURITY;
ALTER TABLE test.page_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE test.page_flags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow all" ON test.pages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON test.page_links FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON test.calls FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON test.budget FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON test.page_ratings FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow all" ON test.page_flags FOR ALL USING (true) WITH CHECK (true);

-- Grant table-level access (must come after table creation).
GRANT ALL ON ALL TABLES IN SCHEMA test TO anon, authenticated, service_role;
