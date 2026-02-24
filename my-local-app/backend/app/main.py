from fastapi import FastAPI, Form
from fastapi.middleware.cors import CORSMiddleware
import asyncio
from contextlib import asynccontextmanager

from app.hooks import user_hooks
from app.database import db


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    while True:
        try:
            await db.connect()
            await db.user.count()
            print("✅ Database connected successfully")
            break
        except Exception:
            print("⏳ Waiting for database...")
            await asyncio.sleep(2)

    yield

    # Shutdown
    await db.disconnect()


app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    return {
        "message": "Welcome to docker-nextpy API",
        "docs": "/docs",
        "users": "/users",
    }


@app.get("/users")
async def users():
    return await user_hooks.get_users()


@app.post("/users")
async def create_user(
    name: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
):
    return await user_hooks.create_user(name, email, password)
