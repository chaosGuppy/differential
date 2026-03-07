"""Scout call: find missing considerations on a question."""
import json as _json

from differential.calls.common import (
    _complete_call, _dedup, _format_extra_pages, _print_page_ratings,
    _run_closing_review, _run_phase1, _run_with_loading, _PHASE1_TASK,
)
from differential.context import build_call_context
from differential.database import DB
from differential.executor import execute_all_moves
from differential.llm import build_system_prompt, build_user_message
from differential.models import Call, CallStatus
from differential.parser import ParsedOutput


def run_scout(
    question_id: str,
    call: Call,
    db: DB,
) -> tuple[ParsedOutput, dict]:
    """
    Run a Scout call on a question.
    Returns (parsed_output, review_dict).
    """
    print(f"\n[SCOUT] {call.id[:8]} — question {question_id[:8]}")

    preloaded = _json.loads(call.context_page_ids or "[]")
    system_prompt = build_system_prompt("scout")
    context_text, short_id_map = build_call_context(question_id, db, extra_page_ids=preloaded)

    task = (
        f"Scout for missing considerations on this question.\n\n"
        f"Question ID (use this when linking considerations): `{question_id}`"
    )

    phase1_user = build_user_message(context_text, _PHASE1_TASK)
    phase1_raw, short_load_ids = _run_phase1(system_prompt, phase1_user)

    full_load_ids = [short_id_map[s] for s in short_load_ids if s in short_id_map]
    valid_load_ids = [pid for pid in full_load_ids if db.get_page(pid)]

    extra_pages_text = _format_extra_pages(valid_load_ids, db)
    phase2_user = (
        (f"## Loaded Pages\n\n{extra_pages_text}\n\n---\n\n") if extra_pages_text else ""
    ) + "Perform your main task now. You may use LOAD_PAGE if you need additional pages.\n\n" + task

    messages = [
        {"role": "user",      "content": phase1_user},
        {"role": "assistant", "content": phase1_raw or "(no preliminary analysis)"},
        {"role": "user",      "content": phase2_user},
    ]
    raw, parsed, phase2_ids = _run_with_loading(system_prompt, messages, short_id_map, db)

    db.update_call_status(call.id, CallStatus.RUNNING)
    created = execute_all_moves(parsed, call, db)

    all_loaded_ids = _dedup(preloaded + valid_load_ids + phase2_ids)
    review = _run_closing_review(call, raw, context_text, all_loaded_ids, db)
    remaining_fruit = 5
    if review:
        remaining_fruit = review.get("remaining_fruit", 5)
        print(f"  [review] remaining_fruit={remaining_fruit}, "
              f"confidence={review.get('confidence_in_output', '?')}")
        _print_page_ratings(review)

    call.review_json = _json.dumps(review or {})
    _complete_call(call, db, f"Scout complete. Created {len(created)} pages. Remaining fruit: {remaining_fruit}")
    return parsed, review or {}
