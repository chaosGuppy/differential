-- Add trace_json column to calls table for execution tracing.
ALTER TABLE public.calls ADD COLUMN trace_json JSONB DEFAULT '[]';

-- Index on parent_call_id for efficient child-call lookups.
CREATE INDEX idx_calls_parent ON public.calls(parent_call_id);

-- RPC: append trace events to a call's trace_json.
CREATE OR REPLACE FUNCTION append_call_trace(cid TEXT, new_events JSONB)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE calls SET trace_json = COALESCE(trace_json, '[]'::jsonb) || new_events
    WHERE id = cid;
END;
$$;
