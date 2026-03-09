"""Pydantic models for move payloads — single source of truth for move structures."""

from pydantic import BaseModel, Field

from differential.models import MoveType


class CreatePagePayload(BaseModel):
    summary: str = ""
    content: str = ""
    epistemic_status: float = 2.5
    epistemic_type: str = ""
    workspace: str = "research"
    provenance_model: str = "claude-opus-4-6"
    # Extra fields stored in page.extra
    status: str | None = None
    remaining_fruit: float | None = None
    parent_question_id: str | None = None
    key_dependencies: str | None = None
    sensitivity_analysis: str | None = None
    confidence_type: str | None = None
    decomposition_status: str | None = None
    source_url: str | None = None
    source_id: str | None = None
    direction: str | None = None
    strength: float | None = None
    hypothesis: str | None = None


class LinkConsiderationPayload(BaseModel):
    claim_id: str | None = Field(None, description="Page ID of the claim (alias: from_page_id)")
    from_page_id: str | None = None
    question_id: str | None = Field(None, description="Page ID of the question (alias: to_page_id)")
    to_page_id: str | None = None
    direction: str = "neutral"
    strength: float = 2.5
    reasoning: str = ""


class LinkPagesPayload(BaseModel):
    from_page_id: str | None = Field(None, description="(alias: parent_id)")
    parent_id: str | None = None
    to_page_id: str | None = Field(None, description="(alias: child_id)")
    child_id: str | None = None
    reasoning: str = ""


class SupersedePagePayload(CreatePagePayload):
    old_page_id: str = ""


class FlagFunninessPayload(BaseModel):
    page_id: str = ""
    note: str = ""


class ReportDuplicatePayload(BaseModel):
    page_id_a: str = ""
    page_id_b: str = ""


class ProposeHypothesisPayload(BaseModel):
    parent_question_id: str = ""
    hypothesis: str = ""
    reasoning: str = ""
    epistemic_status: float = 2.5
    direction: str = "neutral"
    strength: float = 2.5
    provenance_model: str = "claude-opus-4-6"


class LoadPagePayload(BaseModel):
    page_id: str = ""


MOVE_PAYLOAD_MODELS: dict[MoveType, type[BaseModel]] = {
    MoveType.CREATE_CLAIM: CreatePagePayload,
    MoveType.CREATE_QUESTION: CreatePagePayload,
    MoveType.CREATE_JUDGEMENT: CreatePagePayload,
    MoveType.CREATE_CONCEPT: CreatePagePayload,
    MoveType.CREATE_WIKI_PAGE: CreatePagePayload,
    MoveType.LINK_CONSIDERATION: LinkConsiderationPayload,
    MoveType.LINK_CHILD_QUESTION: LinkPagesPayload,
    MoveType.LINK_RELATED: LinkPagesPayload,
    MoveType.SUPERSEDE_PAGE: SupersedePagePayload,
    MoveType.FLAG_FUNNINESS: FlagFunninessPayload,
    MoveType.REPORT_DUPLICATE: ReportDuplicatePayload,
    MoveType.PROPOSE_HYPOTHESIS: ProposeHypothesisPayload,
    MoveType.LOAD_PAGE: LoadPagePayload,
}


def move_to_trace_dict(move_type: MoveType, payload: dict) -> dict:
    """Convert a raw move payload to a clean trace dict via the pydantic model.

    Parses through the model to normalize field names and drop unknown keys,
    then excludes None/default values for compact output.
    """
    model_cls = MOVE_PAYLOAD_MODELS.get(move_type)
    if not model_cls:
        return payload
    try:
        parsed = model_cls.model_validate(payload)
        return parsed.model_dump(exclude_none=True, exclude_defaults=True)
    except Exception:
        return payload
