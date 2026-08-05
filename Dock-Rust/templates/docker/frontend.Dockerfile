FROM oven/bun:latest

WORKDIR /app

COPY frontend .

RUN bun install

EXPOSE 3000

CMD ["bun", "run", "dev", "--hostname", "0.0.0.0"]