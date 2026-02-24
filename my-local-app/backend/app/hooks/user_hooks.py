from fastapi import HTTPException
from app.database import db


async def get_users():
    try:
        return await db.user.find_many(order={"id": "asc"})
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


async def create_user(name: str, email: str, password: str):
    try:
        return await db.user.create(data={"name": name, "email": email, "password": password})
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
