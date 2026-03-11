import Link from "next/link";
import type { RunTraceOut } from "@/api/types.gen";
import { TraceViewer } from "./trace-viewer";

const API_BASE = process.env.API_BASE_URL || "http://localhost:8000";

async function getRunTrace(runId: string): Promise<RunTraceOut | null> {
  const res = await fetch(`${API_BASE}/api/runs/${runId}/trace`, {
    cache: "no-store",
  });
  if (!res.ok) return null;
  return res.json();
}

async function getRealtimeConfig(): Promise<{
  url: string;
  anon_key: string;
} | null> {
  try {
    const res = await fetch(`${API_BASE}/api/realtime/config`, {
      cache: "no-store",
    });
    if (!res.ok) return null;
    return res.json();
  } catch {
    return null;
  }
}

export default async function TracePage({
  params,
}: {
  params: Promise<{ runId: string }>;
}) {
  const { runId } = await params;
  const [trace, realtimeConfig] = await Promise.all([
    getRunTrace(runId),
    getRealtimeConfig(),
  ]);

  if (!trace) {
    return (
      <main className="max-w-6xl mx-auto p-8">
        <p className="text-red-500">Run not found: {runId}</p>
        <Link href="/" className="text-blue-600 hover:underline text-sm">
          &larr; Back
        </Link>
      </main>
    );
  }

  return (
    <main className="max-w-6xl mx-auto p-8">
      {trace.question && (
        <Link
          href={`/questions/${trace.question.id}`}
          className="text-blue-600 hover:underline text-sm"
        >
          &larr; {trace.question.summary}
        </Link>
      )}
      <h1 className="text-2xl font-semibold mt-2 mb-1">Execution Trace</h1>
      <p className="text-sm text-gray-500 mb-6 font-mono">
        run {runId.slice(0, 8)}
      </p>
      <TraceViewer
        initialTrace={trace}
        runId={runId}
        realtimeConfig={realtimeConfig}
      />
    </main>
  );
}
