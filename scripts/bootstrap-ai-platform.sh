#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME=${1:-synextra-ai-starter}

FRONTEND_PORT=${FRONTEND_PORT:-3000}
BACKEND_PORT=${BACKEND_PORT:-8000}
POSTGRES_PORT=${POSTGRES_PORT:-5432}

POSTGRES_DB=${POSTGRES_DB:-synextra}
POSTGRES_USER=${POSTGRES_USER:-synextra}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-synextra}

GREEN="\033[0;32m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
YELLOW="\033[1;33m"
RESET="\033[0m"

if [ -t 1 ] && command -v clear >/dev/null 2>&1; then
  clear
fi

echo -e "${CYAN}================================================${RESET}"
echo -e "${MAGENTA}🤖 SYNEXTRA AI PLATFORM STARTER${RESET}"
echo -e "${CYAN}NextJS • Bun • FastAPI • PostgreSQL${RESET}"
echo -e "${CYAN}Docker • Tailwind • Framer Motion • Starter Kit${RESET}"
echo -e "${CYAN}================================================${RESET}"

spinner() {
  local pid=$1
  local spin='-\|/'
  local i=0

  while kill -0 "$pid" 2>/dev/null; do
    i=$(((i + 1) % 4))
    printf "\r${YELLOW}[%c] Working...${RESET}" "${spin:$i:1}"
    sleep 0.1
  done

  printf "\r"
}

run_with_spinner() {
  local log_file
  log_file=$(mktemp)

  "$@" >"$log_file" 2>&1 &
  local pid=$!
  spinner "$pid"

  if ! wait "$pid"; then
    cat "$log_file"
    rm -f "$log_file"
    exit 1
  fi

  rm -f "$log_file"
}

wait_for() {
  local url=$1
  local name=$2
  local service=$3
  local timeout=${4:-150}
  local elapsed=0

  printf "${YELLOW}Waiting for %s${RESET}" "$name"

  until curl -fsS "$url" >/dev/null 2>&1; do
    if [ "$elapsed" -ge "$timeout" ]; then
      echo
      echo -e "${YELLOW}${name} did not become ready within ${timeout}s.${RESET}"
      docker compose ps || true
      docker compose logs --tail=120 "$service" || true
      exit 1
    fi

    printf "."
    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo -e " ${GREEN}READY${RESET}"
}

echo -e "${BLUE}Creating project directory...${RESET}"

if [ -d "$PROJECT_NAME" ]; then
  if [ "${FORCE:-0}" = "1" ]; then
    rm -rf "$PROJECT_NAME"
  else
    echo -e "${YELLOW}Project directory '$PROJECT_NAME' already exists.${RESET}"
    echo "Set FORCE=1 to replace it."
    exit 1
  fi
fi

mkdir -p "$PROJECT_NAME/backend/app" "$PROJECT_NAME/backend/tests" "$PROJECT_NAME/frontend"

cd "$PROJECT_NAME"

################################################
# BACKEND
################################################

echo -e "${CYAN}Setting up FastAPI backend...${RESET}"

cat > backend/app/__init__.py <<'PY'
PY

cat > backend/app/config.py <<'PY'
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://synextra:synextra@postgres:5432/synextra",
)

ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv("ALLOWED_ORIGINS", "http://localhost:3000").split(",")
    if origin.strip()
]
PY

cat > backend/app/db.py <<'PY'
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from .config import DATABASE_URL

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_session():
    with SessionLocal() as session:
        yield session
PY

cat > backend/app/models.py <<'PY'
from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class StarterModule(Base):
    __tablename__ = "starter_modules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(140))
    category: Mapped[str] = mapped_column(String(60), index=True)
    summary: Mapped[str] = mapped_column(Text)
    detail: Mapped[str] = mapped_column(Text)
    owner: Mapped[str] = mapped_column(String(80), default="Platform")
    stage: Mapped[str] = mapped_column(String(32), default="Seeded")
    tags: Mapped[str] = mapped_column(Text, default="")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)


class TeamNote(Base):
    __tablename__ = "team_notes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(80))
    title: Mapped[str] = mapped_column(String(140))
    message: Mapped[str] = mapped_column(Text)
    lane: Mapped[str] = mapped_column(String(40), default="Backlog")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=False), default=datetime.utcnow
    )
PY

cat > backend/app/schemas.py <<'PY'
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class StarterModuleRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    category: str
    summary: str
    detail: str
    owner: str
    stage: str
    tags: list[str]


class TeamNoteCreate(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    title: str = Field(min_length=3, max_length=140)
    message: str = Field(min_length=10, max_length=800)
    lane: str = Field(min_length=3, max_length=40)


class TeamNoteRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    title: str
    message: str
    lane: str
    created_at: datetime


class MetricRead(BaseModel):
    label: str
    value: str
    detail: str


class AppSummaryRead(BaseModel):
    title: str
    strapline: str
    summary: str


class OverviewResponse(BaseModel):
    app: AppSummaryRead
    metrics: list[MetricRead]
    modules: list[StarterModuleRead]
    team_notes: list[TeamNoteRead]
PY

cat > backend/app/seed.py <<'PY'
from .models import StarterModule, TeamNote

SEED_MODULES = [
    {
        "title": "Azure-ready RAG service",
        "category": "Backend",
        "summary": "Typed FastAPI surface ready for Azure OpenAI, Azure AI Search, and grounded retrieval workflows.",
        "detail": "Use this module as the base for prompt orchestration, retrieval, source attribution, and service-level observability.",
        "owner": "Platform",
        "stage": "Seeded",
        "tags": "FastAPI|RAG|Azure OpenAI|Azure AI Search",
        "sort_order": 1,
    },
    {
        "title": "React operator workspace",
        "category": "Frontend",
        "summary": "Next.js starter with isolated hooks, API functions, UI primitives, and animation hooks already separated.",
        "detail": "Built as a starting point for dashboards, review flows, and internal tooling rather than a finished product.",
        "owner": "Experience",
        "stage": "Seeded",
        "tags": "Next.js|TypeScript|Framer Motion|Tailwind",
        "sort_order": 2,
    },
    {
        "title": "Evaluation and guardrail lane",
        "category": "AI Quality",
        "summary": "Starter data model for Responsible AI workflows, review gates, and production readiness discussions.",
        "detail": "Extend this to track prompt regressions, content filters, human review outcomes, and compliance evidence.",
        "owner": "AI Services",
        "stage": "Seeded",
        "tags": "Evaluation|Responsible AI|Guardrails|Auditability",
        "sort_order": 3,
    },
    {
        "title": "Delivery and discovery cockpit",
        "category": "Operations",
        "summary": "Seed content aligned to Synextra delivery: architecture spikes, client discovery, and team capture.",
        "detail": "The UI is intentionally modular so it can grow into delivery boards, architecture notes, or client-specific workspaces.",
        "owner": "Architecture",
        "stage": "Seeded",
        "tags": "Discovery|Pre-sales|Architecture|Delivery",
        "sort_order": 4,
    },
]

SEED_NOTES = [
    {
        "name": "Platform Team",
        "title": "Replace demo adapters with Azure clients",
        "message": "Keep the HTTP and schema boundaries stable, then swap the starter implementation for Azure OpenAI and Azure AI Search integrations.",
        "lane": "Backlog",
    },
    {
        "name": "Frontend Team",
        "title": "Add authenticated workspace views",
        "message": "Use the starter note feed as the first authenticated feature and layer in client-specific workspaces once identity is wired up.",
        "lane": "In Progress",
    },
]


def seed_database(session) -> None:
    if session.query(StarterModule).count() == 0:
        session.add_all(StarterModule(**item) for item in SEED_MODULES)

    if session.query(TeamNote).count() == 0:
        session.add_all(TeamNote(**item) for item in SEED_NOTES)

    session.commit()
PY

cat > backend/app/services.py <<'PY'
import time

from sqlalchemy import func, select
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from .db import SessionLocal, engine
from .models import Base, StarterModule, TeamNote
from .schemas import MetricRead
from .seed import seed_database


def ensure_database_ready(max_attempts: int = 20, delay_seconds: int = 2) -> None:
    last_error = None

    for _ in range(max_attempts):
        try:
            Base.metadata.create_all(bind=engine)
            with SessionLocal() as session:
                seed_database(session)
            return
        except OperationalError as exc:
            last_error = exc
            time.sleep(delay_seconds)

    raise RuntimeError("Database did not become ready in time") from last_error


def serialise_module(module: StarterModule) -> dict:
    return {
        "id": module.id,
        "title": module.title,
        "category": module.category,
        "summary": module.summary,
        "detail": module.detail,
        "owner": module.owner,
        "stage": module.stage,
        "tags": [tag for tag in module.tags.split("|") if tag],
    }


def serialise_note(note: TeamNote) -> dict:
    return {
        "id": note.id,
        "name": note.name,
        "title": note.title,
        "message": note.message,
        "lane": note.lane,
        "created_at": note.created_at,
    }


def list_modules(session: Session) -> list[dict]:
    statement = select(StarterModule).order_by(
        StarterModule.sort_order.asc(), StarterModule.id.asc()
    )
    return [serialise_module(item) for item in session.scalars(statement).all()]


def list_team_notes(session: Session) -> list[dict]:
    statement = select(TeamNote).order_by(TeamNote.created_at.desc(), TeamNote.id.desc())
    return [serialise_note(item) for item in session.scalars(statement).all()]


def build_metrics(session: Session) -> list[MetricRead]:
    module_count = session.scalar(select(func.count()).select_from(StarterModule)) or 0
    note_count = session.scalar(select(func.count()).select_from(TeamNote)) or 0
    categories = (
        session.query(StarterModule.category).distinct().count()
    )

    return [
        MetricRead(
            label="Seeded modules",
            value=str(module_count),
            detail="Database-backed starter records to prove the stack and UI wiring.",
        ),
        MetricRead(
            label="Team notes",
            value=str(note_count),
            detail="User-created records stored in Postgres and surfaced immediately in the frontend.",
        ),
        MetricRead(
            label="Focus lanes",
            value=str(categories),
            detail="Separated starter themes across backend, frontend, AI quality, and operations.",
        ),
        MetricRead(
            label="Default stack",
            value="FastAPI + Next.js",
            detail="Python backend, TypeScript frontend, Postgres persistence, Docker-first setup.",
        ),
    ]
PY

cat > backend/app/api.py <<'PY'
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from .db import get_session
from .models import TeamNote
from .schemas import OverviewResponse, TeamNoteCreate, TeamNoteRead
from .services import build_metrics, list_modules, list_team_notes, serialise_note

router = APIRouter()


@router.get("/health")
def health(session: Session = Depends(get_session)):
    return {"status": "ok", "modules": len(list_modules(session)), "notes": len(list_team_notes(session))}


@router.get("/api/overview", response_model=OverviewResponse)
def get_overview(session: Session = Depends(get_session)):
    return OverviewResponse(
        app={
            "title": "Synextra AI Platform Starter",
            "strapline": "A modular developer starting point for AI delivery, not a finished product.",
            "summary": (
                "This scaffold gives you a running FastAPI, Next.js, and Postgres baseline "
                "with separated frontend folders, starter data, and a database-backed input flow."
            ),
        },
        metrics=build_metrics(session),
        modules=list_modules(session),
        team_notes=list_team_notes(session),
    )


@router.post(
    "/api/team-notes",
    response_model=TeamNoteRead,
    status_code=status.HTTP_201_CREATED,
)
def create_team_note(payload: TeamNoteCreate, session: Session = Depends(get_session)):
    note = TeamNote(**payload.model_dump())
    session.add(note)
    session.commit()
    session.refresh(note)
    return TeamNoteRead.model_validate(serialise_note(note))
PY

cat > backend/app/main.py <<'PY'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api import router
from .config import ALLOWED_ORIGINS
from .services import ensure_database_ready

app = FastAPI(
    title="Synextra AI Platform Starter",
    description="Starter template for Synextra AI platform work.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup() -> None:
    ensure_database_ready()


@app.get("/")
def root():
    return {"message": "Synextra AI Platform Starter API", "status": "ok"}


app.include_router(router)
PY

cat > backend/requirements.txt <<'EOF'
fastapi
uvicorn[standard]
sqlalchemy
psycopg[binary]
EOF

cat > backend/tests/test_seed.py <<'PY'
import unittest

from app.seed import SEED_MODULES, SEED_NOTES


class SeedDataTests(unittest.TestCase):
    def test_seed_modules_exist(self):
        self.assertGreaterEqual(len(SEED_MODULES), 4)

    def test_seed_notes_exist(self):
        self.assertGreaterEqual(len(SEED_NOTES), 1)


if __name__ == "__main__":
    unittest.main()
PY

################################################
# FRONTEND
################################################

echo -e "${CYAN}Creating NextJS frontend (Bun)...${RESET}"

cd frontend

run_with_spinner bun create next-app@latest . --yes
run_with_spinner bun add framer-motion lucide-react clsx tailwind-merge class-variance-authority
perl -0pi -e 's/"lint": "eslint"/"lint": "eslint",\n    "typecheck": "tsc --noEmit",\n    "test": "bun test"/' package.json

mkdir -p app/demo components/dashboard components/ui functions hooks services tests types lib

cat > components.json <<'EOF'
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "app/globals.css",
    "baseColor": "slate",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib"
  }
}
EOF

cat > lib/utils.ts <<'TS'
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
TS

cat > types/dashboard.ts <<'TS'
export interface Metric {
  label: string;
  value: string;
  detail: string;
}

export interface StarterModule {
  id: number;
  title: string;
  category: string;
  summary: string;
  detail: string;
  owner: string;
  stage: string;
  tags: string[];
}

export interface TeamNote {
  id: number;
  name: string;
  title: string;
  message: string;
  lane: string;
  createdAt: string;
}

export interface AppSummary {
  title: string;
  strapline: string;
  summary: string;
}

export interface OverviewResponse {
  app: AppSummary;
  metrics: Metric[];
  modules: StarterModule[];
  teamNotes: TeamNote[];
}

export interface TeamNoteInput {
  name: string;
  title: string;
  message: string;
  lane: string;
}
TS

cat > functions/api.ts <<'TS'
import type { OverviewResponse, TeamNote, TeamNoteInput } from "@/types/dashboard";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

async function apiFetch<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
    cache: "no-store",
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed with ${response.status}`);
  }

  return response.json() as Promise<T>;
}

function normaliseNote(note: {
  id: number;
  name: string;
  title: string;
  message: string;
  lane: string;
  created_at: string;
}): TeamNote {
  return {
    id: note.id,
    name: note.name,
    title: note.title,
    message: note.message,
    lane: note.lane,
    createdAt: note.created_at,
  };
}

export async function fetchOverview(): Promise<OverviewResponse> {
  const payload = await apiFetch<{
    app: OverviewResponse["app"];
    metrics: OverviewResponse["metrics"];
    modules: OverviewResponse["modules"];
    team_notes: Array<{
      id: number;
      name: string;
      title: string;
      message: string;
      lane: string;
      created_at: string;
    }>;
  }>("/api/overview");

  return {
    app: payload.app,
    metrics: payload.metrics,
    modules: payload.modules,
    teamNotes: payload.team_notes.map(normaliseNote),
  };
}

export async function createTeamNote(input: TeamNoteInput): Promise<TeamNote> {
  const payload = await apiFetch<{
    id: number;
    name: string;
    title: string;
    message: string;
    lane: string;
    created_at: string;
  }>("/api/team-notes", {
    method: "POST",
    body: JSON.stringify(input),
  });

  return normaliseNote(payload);
}
TS

cat > services/dashboard.ts <<'TS'
import type { StarterModule, TeamNote } from "@/types/dashboard";

export function filterModules(modules: StarterModule[], query: string) {
  const trimmed = query.trim().toLowerCase();

  if (!trimmed) {
    return modules;
  }

  return modules.filter((module) => {
    const haystack = `${module.title} ${module.category} ${module.summary} ${module.detail} ${module.tags.join(" ")}`.toLowerCase();
    return haystack.includes(trimmed);
  });
}

export function sortNotesByNewest(notes: TeamNote[]) {
  return [...notes].sort(
    (left, right) =>
      new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime(),
  );
}

export function laneTone(lane: string) {
  switch (lane.toLowerCase()) {
    case "in progress":
      return "accent";
    case "review":
      return "secondary";
    default:
      return "default";
  }
}
TS

cat > hooks/use-dashboard.ts <<'TS'
"use client";

import { startTransition, useEffect, useState } from "react";

import { createTeamNote, fetchOverview } from "@/functions/api";
import type { OverviewResponse, TeamNoteInput } from "@/types/dashboard";

export function useDashboard() {
  const [overview, setOverview] = useState<OverviewResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function loadOverview() {
    try {
      setLoading(true);
      setError(null);
      const nextOverview = await fetchOverview();
      startTransition(() => {
        setOverview(nextOverview);
      });
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Unable to load starter data.",
      );
    } finally {
      setLoading(false);
    }
  }

  async function saveNote(input: TeamNoteInput) {
    try {
      setSaving(true);
      setError(null);
      await createTeamNote(input);
      await loadOverview();
    } catch (caughtError) {
      setError(
        caughtError instanceof Error
          ? caughtError.message
          : "Unable to save the team note.",
      );
      throw caughtError;
    } finally {
      setSaving(false);
    }
  }

  useEffect(() => {
    void loadOverview();
  }, []);

  return {
    overview,
    loading,
    saving,
    error,
    refresh: loadOverview,
    saveNote,
  };
}
TS

cat > components/ui/button.tsx <<'TSX'
import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-full text-sm font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--ring)] disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default:
          "bg-[color:var(--accent)] px-5 py-3 text-[color:var(--accent-foreground)] shadow-lg shadow-[color:var(--shadow-color)] hover:bg-[color:var(--accent-strong)]",
        secondary:
          "bg-[color:var(--secondary)] px-5 py-3 text-[color:var(--secondary-foreground)] hover:bg-[color:var(--secondary-strong)]",
        outline:
          "border border-[color:var(--border-strong)] bg-white/8 px-5 py-3 text-[color:var(--foreground)] hover:bg-white/12",
      },
      size: {
        default: "h-11",
        lg: "h-12 px-6 text-base",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, ...props }, ref) => (
    <button
      ref={ref}
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  ),
);

Button.displayName = "Button";

export { Button, buttonVariants };
TSX

cat > components/ui/badge.tsx <<'TSX'
import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center rounded-full border px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em]",
  {
    variants: {
      variant: {
        default:
          "border-[color:var(--border-strong)] bg-white/8 text-[color:var(--foreground)]",
        accent:
          "border-transparent bg-[color:var(--accent-soft)] text-[color:var(--accent-foreground)]",
        secondary:
          "border-transparent bg-[color:var(--secondary-soft)] text-[color:var(--secondary-foreground)]",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />;
}
TSX

cat > components/ui/card.tsx <<'TSX'
import * as React from "react";

import { cn } from "@/lib/utils";

export function Card({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "rounded-[28px] border border-[color:var(--border)] bg-[color:var(--card)] text-[color:var(--card-foreground)] shadow-[0_24px_80px_-40px_var(--shadow-color)] backdrop-blur",
        className,
      )}
      {...props}
    />
  );
}

export function CardHeader({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("flex flex-col gap-3 p-6", className)} {...props} />;
}

export function CardTitle({
  className,
  ...props
}: React.HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h3
      className={cn("text-xl font-semibold tracking-tight text-[color:var(--foreground)]", className)}
      {...props}
    />
  );
}

export function CardDescription({
  className,
  ...props
}: React.HTMLAttributes<HTMLParagraphElement>) {
  return (
    <p
      className={cn("text-sm leading-6 text-[color:var(--muted-foreground)]", className)}
      {...props}
    />
  );
}

export function CardContent({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn("px-6 pb-6", className)} {...props} />;
}
TSX

cat > components/ui/input.tsx <<'TSX'
import * as React from "react";

import { cn } from "@/lib/utils";

const Input = React.forwardRef<HTMLInputElement, React.ComponentProps<"input">>(
  ({ className, ...props }, ref) => {
    return (
      <input
        ref={ref}
        className={cn(
          "flex h-12 w-full rounded-full border border-[color:var(--border-strong)] bg-black/20 px-5 text-sm text-[color:var(--foreground)] shadow-inner outline-none transition focus-visible:ring-2 focus-visible:ring-[color:var(--ring)] placeholder:text-[color:var(--muted-foreground)]",
          className,
        )}
        {...props}
      />
    );
  },
);

Input.displayName = "Input";

export { Input };
TSX

cat > components/ui/textarea.tsx <<'TSX'
import * as React from "react";

import { cn } from "@/lib/utils";

const Textarea = React.forwardRef<
  HTMLTextAreaElement,
  React.ComponentProps<"textarea">
>(({ className, ...props }, ref) => {
  return (
    <textarea
      ref={ref}
      className={cn(
        "min-h-32 w-full rounded-[24px] border border-[color:var(--border-strong)] bg-black/20 px-5 py-4 text-sm text-[color:var(--foreground)] outline-none transition focus-visible:ring-2 focus-visible:ring-[color:var(--ring)] placeholder:text-[color:var(--muted-foreground)]",
        className,
      )}
      {...props}
    />
  );
});

Textarea.displayName = "Textarea";

export { Textarea };
TSX

cat > components/ui/separator.tsx <<'TSX'
import * as React from "react";

import { cn } from "@/lib/utils";

export function Separator({
  className,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      aria-hidden="true"
      className={cn("h-px w-full bg-[color:var(--border)]", className)}
      {...props}
    />
  );
}
TSX

cat > components/dashboard/hero-panel.tsx <<'TSX'
import { motion } from "framer-motion";
import { Database, LayoutTemplate, MessageSquarePlus, ShieldCheck } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import type { AppSummary, Metric } from "@/types/dashboard";

const quickFacts = [
  { icon: LayoutTemplate, label: "Starter shape", value: "Separated files and folders" },
  { icon: Database, label: "Persistence", value: "Seeded Postgres with live note capture" },
  { icon: MessageSquarePlus, label: "Workflow", value: "Create a note and watch it render back" },
  { icon: ShieldCheck, label: "Intent", value: "Starting point, not a finished product" },
];

export function HeroPanel({
  app,
  metrics,
  onRefresh,
}: {
  app: AppSummary;
  metrics: Metric[];
  onRefresh: () => Promise<void> | void;
}) {
  return (
    <motion.section
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.45 }}
      className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]"
    >
      <Card className="overflow-hidden bg-[linear-gradient(145deg,rgba(7,11,24,0.96),rgba(15,23,42,0.82))]">
        <CardHeader className="gap-5 p-8 md:p-10">
          <div className="flex flex-wrap gap-3">
            <Badge variant="accent">Developer starting point</Badge>
            <Badge>FastAPI + Next.js + Postgres</Badge>
          </div>
          <div className="space-y-4">
            <h1 className="font-display text-5xl leading-tight text-balance text-white md:text-6xl">
              {app.title}
            </h1>
            <p className="text-sm font-semibold uppercase tracking-[0.2em] text-cyan-200/80">
              {app.strapline}
            </p>
            <p className="max-w-3xl text-base leading-8 text-slate-300 md:text-lg">
              {app.summary}
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Button size="lg" onClick={onRefresh}>
              Refresh starter data
            </Button>
            <Button variant="outline" size="lg" onClick={() => window.location.assign("/demo")}>
              Open demo route
            </Button>
          </div>
        </CardHeader>
      </Card>

      <div className="grid gap-4">
        {metrics.map((metric, index) => (
          <motion.div
            key={metric.label}
            initial={{ opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.06 * index, duration: 0.35 }}
          >
            <Card className="bg-white/6">
              <CardHeader className="gap-2 pb-4">
                <CardDescription>{metric.label}</CardDescription>
                <CardTitle className="font-display text-3xl text-white">
                  {metric.value}
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm leading-6 text-slate-300">{metric.detail}</p>
              </CardContent>
            </Card>
          </motion.div>
        ))}
        <div className="grid gap-4 sm:grid-cols-2">
          {quickFacts.map(({ icon: Icon, label, value }) => (
            <Card key={label} className="bg-black/20">
              <CardContent className="p-5">
                <Icon className="mb-4 size-5 text-cyan-300" />
                <p className="text-xs uppercase tracking-[0.18em] text-slate-400">{label}</p>
                <p className="mt-2 text-sm font-semibold text-white">{value}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </motion.section>
  );
}
TSX

cat > components/dashboard/module-grid.tsx <<'TSX'
import { motion } from "framer-motion";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { StarterModule } from "@/types/dashboard";

export function ModuleGrid({ modules }: { modules: StarterModule[] }) {
  return (
    <section className="space-y-6">
      <div className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">
          Seeded starter modules
        </p>
        <h2 className="font-display text-3xl text-white">
          Database-backed dummy data for the first sprint
        </h2>
        <p className="max-w-3xl text-sm leading-7 text-slate-300">
          These records are seeded into Postgres on startup so the generated app proves the stack,
          the API shape, and the frontend rendering path immediately.
        </p>
      </div>

      <div className="grid gap-5 xl:grid-cols-2">
        {modules.map((module, index) => (
          <motion.div
            key={module.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.04 * index, duration: 0.35 }}
          >
            <Card className="h-full bg-white/6">
              <CardHeader>
                <div className="flex flex-wrap items-center gap-3">
                  <Badge variant="accent">{module.category}</Badge>
                  <Badge>{module.stage}</Badge>
                  <span className="text-xs uppercase tracking-[0.18em] text-slate-400">
                    {module.owner}
                  </span>
                </div>
                <CardTitle className="font-display text-2xl text-white">
                  {module.title}
                </CardTitle>
                <CardDescription>{module.summary}</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <p className="text-sm leading-7 text-slate-300">{module.detail}</p>
                <div className="flex flex-wrap gap-2">
                  {module.tags.map((tag) => (
                    <span
                      key={tag}
                      className="rounded-full bg-white/8 px-3 py-1 text-xs font-medium text-slate-200"
                    >
                      {tag}
                    </span>
                  ))}
                </div>
              </CardContent>
            </Card>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
TSX

cat > components/dashboard/team-note-form.tsx <<'TSX'
"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import type { TeamNoteInput } from "@/types/dashboard";

const initialState: TeamNoteInput = {
  name: "",
  title: "",
  message: "",
  lane: "Backlog",
};

export function TeamNoteForm({
  onSubmit,
  saving,
}: {
  onSubmit: (value: TeamNoteInput) => Promise<void>;
  saving: boolean;
}) {
  const [form, setForm] = useState<TeamNoteInput>(initialState);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await onSubmit(form);
    setForm(initialState);
  }

  return (
    <Card className="bg-[linear-gradient(180deg,rgba(17,24,39,0.88),rgba(15,23,42,0.78))]">
      <CardHeader>
        <CardTitle className="font-display text-2xl text-white">
          Capture a starter note
        </CardTitle>
        <CardDescription>
          Submit a note, store it in Postgres, and render it back into the workspace immediately.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form className="space-y-4" onSubmit={handleSubmit}>
          <Input
            placeholder="Your name"
            value={form.name}
            onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))}
            required
          />
          <Input
            placeholder="Note title"
            value={form.title}
            onChange={(event) => setForm((current) => ({ ...current, title: event.target.value }))}
            required
          />
          <Input
            placeholder="Lane (Backlog, In Progress, Review)"
            value={form.lane}
            onChange={(event) => setForm((current) => ({ ...current, lane: event.target.value }))}
            required
          />
          <Textarea
            placeholder="Add a short engineering note, backlog item, or architecture reminder."
            value={form.message}
            onChange={(event) => setForm((current) => ({ ...current, message: event.target.value }))}
            required
          />
          <Button type="submit" disabled={saving}>
            {saving ? "Saving note..." : "Store note in database"}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
TSX

cat > components/dashboard/team-note-list.tsx <<'TSX'
import { motion } from "framer-motion";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { laneTone } from "@/services/dashboard";
import type { TeamNote } from "@/types/dashboard";

export function TeamNoteList({ notes }: { notes: TeamNote[] }) {
  return (
    <section className="space-y-6">
      <div className="space-y-2">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">
          Team notes
        </p>
        <h2 className="font-display text-3xl text-white">
          User-created records coming back from the API
        </h2>
        <p className="max-w-3xl text-sm leading-7 text-slate-300">
          This is the simplest proof that the database is connected, writable, and visible to the
          frontend.
        </p>
      </div>

      <div className="grid gap-4">
        {notes.map((note, index) => (
          <motion.div
            key={note.id}
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.04 * index, duration: 0.3 }}
          >
            <Card className="bg-white/6">
              <CardHeader>
                <div className="flex flex-wrap items-center gap-3">
                  <Badge variant={laneTone(note.lane)}>{note.lane}</Badge>
                  <span className="text-xs uppercase tracking-[0.18em] text-slate-400">
                    {new Date(note.createdAt).toLocaleString()}
                  </span>
                </div>
                <CardTitle className="font-display text-xl text-white">
                  {note.title}
                </CardTitle>
                <CardDescription>Submitted by {note.name}</CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-sm leading-7 text-slate-300">{note.message}</p>
              </CardContent>
            </Card>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
TSX

cat > components/dashboard/starter-shell.tsx <<'TSX'
"use client";

import { useDeferredValue, useMemo, useState } from "react";

import { HeroPanel } from "@/components/dashboard/hero-panel";
import { ModuleGrid } from "@/components/dashboard/module-grid";
import { TeamNoteForm } from "@/components/dashboard/team-note-form";
import { TeamNoteList } from "@/components/dashboard/team-note-list";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import { useDashboard } from "@/hooks/use-dashboard";
import { filterModules, sortNotesByNewest } from "@/services/dashboard";

export function StarterShell() {
  const { overview, loading, saving, error, refresh, saveNote } = useDashboard();
  const [query, setQuery] = useState("");
  const deferredQuery = useDeferredValue(query);

  const filteredModules = useMemo(
    () => filterModules(overview?.modules ?? [], deferredQuery),
    [overview?.modules, deferredQuery],
  );

  const sortedNotes = useMemo(
    () => sortNotesByNewest(overview?.teamNotes ?? []),
    [overview?.teamNotes],
  );

  return (
    <div className="relative overflow-hidden">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(45,212,191,0.14),transparent_24%),radial-gradient(circle_at_top_right,rgba(56,189,248,0.12),transparent_28%),radial-gradient(circle_at_bottom_right,rgba(168,85,247,0.16),transparent_26%)]" />
      <main className="relative mx-auto flex min-h-screen w-full max-w-7xl flex-col gap-8 px-6 py-8 md:px-10 md:py-10">
        {overview ? (
          <HeroPanel app={overview.app} metrics={overview.metrics} onRefresh={refresh} />
        ) : null}

        {error ? (
          <Card className="border-red-500/30 bg-red-500/10">
            <CardContent className="p-5 text-sm font-medium text-red-200">
              {error}
            </CardContent>
          </Card>
        ) : null}

        <section className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
          <div className="space-y-6">
            <div className="space-y-3">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-slate-400">
                Filter starter data
              </p>
              <Input
                placeholder="Filter seeded modules by title, category, or tag"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
              />
            </div>
            <Separator />
            <ModuleGrid modules={filteredModules} />
          </div>

          <div className="space-y-6">
            <TeamNoteForm onSubmit={saveNote} saving={saving} />
            <TeamNoteList notes={sortedNotes} />
          </div>
        </section>

        {loading ? (
          <div className="pb-8 text-sm font-medium uppercase tracking-[0.18em] text-slate-400">
            Loading starter data...
          </div>
        ) : null}
      </main>
    </div>
  );
}
TSX

cat > app/page.tsx <<'TSX'
import { StarterShell } from "@/components/dashboard/starter-shell";

export default function Page() {
  return <StarterShell />;
}
TSX

cat > app/demo/page.tsx <<'TSX'
export { default } from "../page";
TSX

cat > app/layout.tsx <<'TSX'
import type { Metadata } from "next";
import { IBM_Plex_Sans, Space_Grotesk } from "next/font/google";

import "./globals.css";

const bodyFont = IBM_Plex_Sans({
  variable: "--font-body",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

const displayFont = Space_Grotesk({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["500", "600", "700"],
});

export const metadata: Metadata = {
  title: "Synextra AI Platform Starter",
  description: "Developer starter for Synextra AI platform work.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${bodyFont.variable} ${displayFont.variable}`}
    >
      <body suppressHydrationWarning className="min-h-screen">
        {children}
      </body>
    </html>
  );
}
TSX

cat > app/globals.css <<'CSS'
@import "tailwindcss";

:root {
  --background: #040712;
  --foreground: #e5eefc;
  --muted-foreground: #9fb2d1;
  --card: rgba(8, 15, 29, 0.74);
  --card-foreground: #e5eefc;
  --surface: rgba(15, 23, 42, 0.82);
  --border: rgba(148, 163, 184, 0.18);
  --border-strong: rgba(148, 163, 184, 0.34);
  --accent: #2dd4bf;
  --accent-strong: #14b8a6;
  --accent-foreground: #042f2e;
  --accent-soft: rgba(45, 212, 191, 0.2);
  --secondary: #38bdf8;
  --secondary-strong: #0ea5e9;
  --secondary-foreground: #082f49;
  --secondary-soft: rgba(56, 189, 248, 0.2);
  --ring: rgba(45, 212, 191, 0.45);
  --shadow-color: rgba(2, 6, 23, 0.55);
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-border: var(--border);
  --font-sans: var(--font-body);
}

* {
  border-color: var(--border);
}

html,
body {
  min-height: 100%;
}

body {
  background:
    radial-gradient(circle at top left, rgba(45, 212, 191, 0.12), transparent 22%),
    radial-gradient(circle at top right, rgba(56, 189, 248, 0.12), transparent 28%),
    radial-gradient(circle at bottom, rgba(76, 29, 149, 0.28), transparent 30%),
    linear-gradient(180deg, #030712 0%, #07111f 45%, #02050d 100%);
  color: var(--foreground);
  font-family: var(--font-body), sans-serif;
}

.font-display {
  font-family: var(--font-display), sans-serif;
}

::selection {
  background: rgba(45, 212, 191, 0.28);
}
CSS

cat > tests/dashboard.test.ts <<'TS'
import assert from "node:assert/strict";
import test from "node:test";

import { sortNotesByNewest } from "../services/dashboard";

test("sortNotesByNewest returns newest item first", () => {
  const notes = sortNotesByNewest([
    {
      id: 1,
      name: "A",
      title: "Old",
      message: "Old note",
      lane: "Backlog",
      createdAt: "2026-03-01T10:00:00.000Z",
    },
    {
      id: 2,
      name: "B",
      title: "New",
      message: "New note",
      lane: "Review",
      createdAt: "2026-03-03T10:00:00.000Z",
    },
  ]);

  assert.equal(notes[0]?.title, "New");
});
TS

cd ..

################################################
# DOCKER
################################################

echo -e "${CYAN}Creating Docker setup...${RESET}"

cat > .dockerignore <<'EOF'
.git
.gitignore
frontend/.next
frontend/node_modules
frontend/.turbo
backend/__pycache__
backend/.pytest_cache
EOF

cat > Dockerfile.backend <<'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY backend .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
EOF

cat > Dockerfile.frontend <<'EOF'
FROM oven/bun:1

WORKDIR /app

COPY frontend/package.json frontend/bun.lock ./
RUN bun install --frozen-lockfile

COPY frontend .

CMD ["bun", "run", "dev", "--hostname", "0.0.0.0", "--port", "3000"]
EOF

cat > docker-compose.yml <<EOF
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "${POSTGRES_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 20

  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    environment:
      DATABASE_URL: postgresql+psycopg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      ALLOWED_ORIGINS: http://localhost:${FRONTEND_PORT}
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "${BACKEND_PORT}:8000"

  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend
    environment:
      NEXT_PUBLIC_API_BASE_URL: http://localhost:${BACKEND_PORT}
    depends_on:
      backend:
        condition: service_started
    ports:
      - "${FRONTEND_PORT}:3000"

volumes:
  postgres_data:
EOF

cat > .env.example <<EOF
FRONTEND_PORT=3000
BACKEND_PORT=8000
POSTGRES_PORT=5432
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
EOF

cat > Makefile <<'EOF'
up:
	docker compose up --build

down:
	docker compose down

typecheck:
	cd frontend && bun run typecheck

frontend-test:
	cd frontend && bun run test

backend-test:
	cd backend && python3 -m unittest discover -s tests
EOF

################################################
# BUILD
################################################

echo -e "${GREEN}Building Docker containers...${RESET}"

compose_log=$(mktemp)
docker compose up --build -d >"$compose_log" 2>&1 &
compose_pid=$!
spinner "$compose_pid"

if ! wait "$compose_pid"; then
  cat "$compose_log"
  rm -f "$compose_log"
  exit 1
fi

rm -f "$compose_log"

wait_for "http://localhost:${BACKEND_PORT}/health" Backend backend
wait_for "http://localhost:${FRONTEND_PORT}" Frontend frontend

echo -e "${CYAN}================================================${RESET}"
echo -e "${GREEN}🎉 STARTER READY${RESET}"
echo -e "${CYAN}================================================${RESET}"

echo "Frontend → http://localhost:${FRONTEND_PORT}"
echo "Demo     → http://localhost:${FRONTEND_PORT}/demo"
echo "Backend  → http://localhost:${BACKEND_PORT}"
echo "Health   → http://localhost:${BACKEND_PORT}/health"
echo "Overview → http://localhost:${BACKEND_PORT}/api/overview"

echo -e "${CYAN}================================================${RESET}"

docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
