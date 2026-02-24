FROM --platform=linux/amd64 python:3.11

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

RUN pip install --upgrade pip \
 && pip install -r requirements.txt

# Copy the rest of the application
COPY . .

# Generate Prisma client after schema is copied
RUN prisma generate

CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8000","--reload"]
