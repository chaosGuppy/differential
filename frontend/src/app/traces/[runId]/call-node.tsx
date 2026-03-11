"use client";

import { useState } from "react";
import Link from "next/link";
import type {
  Call,
  CallTraceOut,
  DispatchExecutedEventOut,
  DispatchesPlannedEventOut,
} from "@/api/types.gen";
import { LLMExchangeDetail } from "./llm-exchange-detail";

type TraceEvent = CallTraceOut["events"][number];

const CALL_TYPE_COLORS: Record<string, string> = {
  scout: "bg-blue-100 text-blue-800",
  assess: "bg-purple-100 text-purple-800",
  prioritization: "bg-orange-100 text-orange-800",
  ingest: "bg-green-100 text-green-800",
};

const STATUS_STYLES: Record<string, string> = {
  running: "bg-yellow-100 text-yellow-700 animate-pulse",
  complete: "bg-green-100 text-green-700",
  failed: "bg-red-100 text-red-700",
  pending: "bg-gray-100 text-gray-500",
};

function formatTime(ts: string): string {
  try {
    const d = new Date(ts);
    return d.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
  } catch {
    return ts;
  }
}

function getDuration(call: Call): string | null {
  if (!call.created_at || !call.completed_at) return null;
  const start = new Date(call.created_at).getTime();
  const end = new Date(call.completed_at).getTime();
  const secs = Math.round((end - start) / 1000);
  if (secs < 60) return `${secs}s`;
  return `${Math.floor(secs / 60)}m${secs % 60}s`;
}

function PageChip({ pageId }: { pageId: string }) {
  const short = typeof pageId === "string" ? pageId.slice(0, 8) : pageId;
  return (
    <Link
      href={`/pages/${pageId}`}
      className="inline-block text-xs font-mono bg-gray-100 border rounded px-1.5 py-0.5 hover:bg-gray-200"
    >
      {short}
    </Link>
  );
}

function PageList({ pageIds }: { pageIds: string[] }) {
  if (!pageIds || pageIds.length === 0)
    return <span className="text-xs text-gray-400 italic">none</span>;
  return (
    <div className="flex flex-wrap gap-1">
      {pageIds.map((id) => (
        <PageChip key={id} pageId={id} />
      ))}
    </div>
  );
}

function MoveBadge({ moveType }: { moveType: string }) {
  const colors: Record<string, string> = {
    CREATE_CLAIM: "bg-green-100 text-green-700",
    CREATE_QUESTION: "bg-green-100 text-green-700",
    CREATE_JUDGEMENT: "bg-green-100 text-green-700",
    CREATE_CONCEPT: "bg-green-100 text-green-700",
    LINK_CONSIDERATION: "bg-blue-100 text-blue-700",
    LINK_CHILD_QUESTION: "bg-blue-100 text-blue-700",
    SUPERSEDE_PAGE: "bg-red-100 text-red-700",
    PROPOSE_HYPOTHESIS: "bg-yellow-100 text-yellow-700",
  };
  return (
    <span
      className={`text-xs font-semibold uppercase px-1.5 py-0.5 rounded ${colors[moveType] || "bg-gray-100 text-gray-600"}`}
    >
      {moveType}
    </span>
  );
}

function EventSection({ event }: { event: TraceEvent }) {
  const warningBorder =
    event.event === "warning"
      ? "border-l-2 border-yellow-400 pl-2"
      : event.event === "error"
        ? "border-l-2 border-red-400 pl-2"
        : "";

  return (
    <div className={`py-1.5 border-b border-gray-100 last:border-0 ${warningBorder}`}>
      <div className="flex items-baseline gap-2 mb-0.5">
        <span className="text-xs font-medium bg-gray-100 px-1.5 rounded">
          {event.event}
        </span>
        <span className="text-xs text-gray-400 font-mono">
          {formatTime(event.ts)}
        </span>
      </div>

      {event.event === "context_built" && (
        <div className="ml-2 text-xs space-y-1">
          {(event.working_context_page_ids ?? []).length > 0 && (
            <div>
              <span className="text-gray-500 font-medium">Working context: </span>
              <PageList pageIds={event.working_context_page_ids ?? []} />
            </div>
          )}
          {(event.preloaded_page_ids ?? []).length > 0 && (
            <div>
              <span className="text-gray-500 font-medium">Preloaded: </span>
              <PageList pageIds={event.preloaded_page_ids ?? []} />
            </div>
          )}
          {event.budget != null && (
            <div className="text-gray-500">Budget: {event.budget}</div>
          )}
        </div>
      )}

      {(event.event === "phase1_loaded" || event.event === "phase2_loaded") && (
        <div className="ml-2 text-xs">
          <PageList pageIds={event.page_ids ?? []} />
        </div>
      )}

      {event.event === "moves_executed" && (
        <div className="ml-2 text-xs space-y-1">
          {(event.moves ?? [])
            .filter((m) => m.type !== "LOAD_PAGE")
            .map((m, i) => (
              <div key={i} className="flex items-baseline gap-1.5">
                <MoveBadge moveType={m.type} />
                <span className="text-gray-600">
                  {m.summary || ""}
                </span>
              </div>
            ))}
          {(event.created_page_ids ?? []).length > 0 && (
            <div>
              <span className="text-gray-500 font-medium">Created: </span>
              <PageList pageIds={event.created_page_ids ?? []} />
            </div>
          )}
        </div>
      )}

      {event.event === "review_complete" && (
        <div className="ml-2 text-xs text-gray-600">
          fruit={String(event.remaining_fruit)}, confidence=
          {String(event.confidence)}
        </div>
      )}

      {event.event === "llm_exchange" && (
        <div className="ml-2 text-xs text-gray-500">
          {event.phase} round {event.round}
          {event.input_tokens != null && (
            <span>
              {" "}
              ({event.input_tokens}/{event.output_tokens} tokens)
            </span>
          )}
        </div>
      )}

      {event.event === "warning" && (
        <div className="ml-2 text-xs text-yellow-700">
          {event.message}
        </div>
      )}

      {event.event === "error" && (
        <div className="ml-2 text-xs text-red-700">
          {event.message}
        </div>
      )}

      {event.event === "dispatches_planned" && (
        <div className="ml-2 text-xs space-y-0.5">
          {(event.dispatches ?? []).map(
            (d, i) => (
              <div key={i} className="flex items-baseline gap-1.5">
                <span className="text-gray-400">{i + 1}.</span>
                <span
                  className={`text-xs font-semibold uppercase px-1.5 py-0.5 rounded ${CALL_TYPE_COLORS[d.call_type] || "bg-gray-100"}`}
                >
                  {d.call_type}
                </span>
                {d.reason ? (
                  <span className="text-gray-500">
                    &mdash; {String(d.reason)}
                  </span>
                ) : null}
              </div>
            ),
          )}
        </div>
      )}
    </div>
  );
}

export function CallNode({
  trace,
  depth,
}: {
  trace: CallTraceOut;
  depth: number;
}) {
  const [isOpen, setIsOpen] = useState(depth <= 1);
  const [showExchanges, setShowExchanges] = useState(false);
  const { call, events, children } = trace;
  const shortId = call.id.slice(0, 8);
  const duration = getDuration(call);

  const warningCount = events.filter((e) => e.event === "warning").length;
  const errorCount = events.filter((e) => e.event === "error").length;

  const skipEvents = new Set(["dispatches_planned", "dispatch_executed"]);
  const displayableEvents = events.filter((e) => !skipEvents.has(e.event));

  const dispatchEvents = events.filter(
    (e): e is DispatchesPlannedEventOut => e.event === "dispatches_planned",
  );
  const executedMap = new Map<number, DispatchExecutedEventOut>();
  for (const e of events) {
    if (e.event === "dispatch_executed") {
      executedMap.set(e.index, e);
    }
  }

  return (
    <div
      id={`call-${shortId}`}
      className={`border rounded-lg ${depth > 0 ? "ml-4" : ""}`}
      style={{
        borderLeftColor:
          call.call_type === "scout"
            ? "#93c5fd"
            : call.call_type === "assess"
              ? "#c084fc"
              : call.call_type === "prioritization"
                ? "#fdba74"
                : call.call_type === "ingest"
                  ? "#86efac"
                  : "#d1d5db",
        borderLeftWidth: "3px",
      }}
    >
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full flex items-center gap-2 px-3 py-2 text-left hover:bg-gray-50"
      >
        <span className="text-xs text-gray-400">{isOpen ? "▼" : "▶"}</span>
        <span
          className={`text-xs font-semibold uppercase px-1.5 py-0.5 rounded ${CALL_TYPE_COLORS[call.call_type] || "bg-gray-100"}`}
        >
          {call.call_type}
        </span>
        <span className="text-xs font-mono text-gray-400">[{shortId}]</span>
        <span
          className={`text-xs px-1.5 py-0.5 rounded ${STATUS_STYLES[call.status] || "bg-gray-100"}`}
        >
          {call.status}
          {duration && ` (${duration})`}
        </span>
        {warningCount > 0 && (
          <span className="text-xs bg-yellow-100 text-yellow-700 px-1.5 py-0.5 rounded">
            {warningCount} warning{warningCount > 1 ? "s" : ""}
          </span>
        )}
        {errorCount > 0 && (
          <span className="text-xs bg-red-100 text-red-700 px-1.5 py-0.5 rounded">
            {errorCount} error{errorCount > 1 ? "s" : ""}
          </span>
        )}
      </button>

      {isOpen && (
        <div className="px-3 pb-3 space-y-2">
          {dispatchEvents.length > 0 && (
            <div className="bg-gray-50 rounded p-2 text-xs">
              <strong className="text-gray-600">Dispatches:</strong>
              <ol className="list-decimal ml-4 mt-1 space-y-0.5">
                {(dispatchEvents[0]?.dispatches ?? []).map((d, i) => {
                  const ex = executedMap.get(i);
                  const childCallId = ex?.child_call_id;
                  return (
                    <li key={i}>
                      {childCallId ? (
                        <a
                          href={`#call-${childCallId.slice(0, 8)}`}
                          className="hover:underline"
                          onClick={(e) => {
                            e.preventDefault();
                            document
                              .getElementById(
                                `call-${childCallId.slice(0, 8)}`,
                              )
                              ?.scrollIntoView({ behavior: "smooth" });
                          }}
                        >
                          <span
                            className={`font-semibold uppercase px-1 rounded ${CALL_TYPE_COLORS[d.call_type] || ""}`}
                          >
                            {d.call_type}
                          </span>
                        </a>
                      ) : (
                        <span
                          className={`font-semibold uppercase px-1 rounded opacity-50 ${CALL_TYPE_COLORS[d.call_type] || ""}`}
                        >
                          {d.call_type}
                          {!ex && " (skipped)"}
                        </span>
                      )}
                      {d.reason ? (
                        <span className="text-gray-500 ml-1">
                          {String(d.reason)}
                        </span>
                      ) : null}
                    </li>
                  );
                })}
              </ol>
            </div>
          )}

          {displayableEvents.length > 0 && (
            <div>
              {displayableEvents.map((ev, i) => (
                <EventSection key={`${ev.ts}-${i}`} event={ev} />
              ))}
            </div>
          )}

          <button
            onClick={() => setShowExchanges(!showExchanges)}
            className="text-xs text-blue-600 hover:underline"
          >
            {showExchanges ? "Hide" : "Show"} LLM exchanges
          </button>
          {showExchanges && <LLMExchangeDetail callId={call.id} />}

          {children.length > 0 && (
            <div className="space-y-2 mt-2">
              {children.map((child) => (
                <CallNode key={child.call.id} trace={child} depth={depth + 1} />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
