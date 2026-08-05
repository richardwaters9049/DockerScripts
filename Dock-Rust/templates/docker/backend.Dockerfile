FROM rust:latest

WORKDIR /app

COPY backend .

RUN cargo build

EXPOSE 8000

CMD ["cargo", "run"]