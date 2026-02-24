import asyncio
from prisma import Prisma


SEED_USERS = [
    {"name": "Alice", "email": "alice@example.com", "password": "secret"},
    {"name": "Bob", "email": "bob@example.com", "password": "secret"},
    {"name": "Charlie", "email": "charlie@example.com", "password": "secret"},
]


async def main():
    db = Prisma()
    await db.connect()

    try:
        for user in SEED_USERS:
            existing = await db.user.find_unique(where={"email": user["email"]})
            if existing:
                await db.user.update(
                    where={"id": existing.id},
                    data={"name": user["name"], "password": user["password"]},
                )
            else:
                await db.user.create(data=user)
        print("Seed completed successfully.")
    finally:
        await db.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
