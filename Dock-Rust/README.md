# 🦀 Dock-Rust

Full Stack Docker Environment Generator

Dock-Rust is a CLI tool that generates ready-to-use full-stack development environments using Docker.

It creates a complete application stack including:

- Next.js frontend with Bun
- Rust backend
- PostgreSQL database
- Redis caching
- Testing environment
- Docker Compose configuration

The goal is to remove repetitive setup work and provide a consistent development environment for new projects.

---

## Features

- Interactive project creation
- Template-based project generation
- Docker Compose orchestration
- Next.js + Bun frontend setup
- Rust backend setup
- PostgreSQL integration
- Redis caching layer
- Environment configuration generation
- Built-in system diagnostics

---

# Requirements

Before installing Dock-Rust, ensure you have:

- Docker
- Docker Compose
- Git
- Bun
- Rust

Check your environment:

```bash
./dock-rust.sh doctor
```

---

# Installation

Clone the repository:

```bash
git clone <repository-url>
```

Make the script executable:

```bash
chmod +x dock-rust.sh
```

Run the installer:

```bash
./dock-rust.sh install
```

---

# Creating a Project

Create a new project:

```bash
./dock-rust.sh new
```

Dock-Rust will ask:

```text
Project name:
```

Example:

```text
Project name: doctor
```

The project will be created:

```text
Projects/
└── doctor/
```

---

# Generated Structure

Example project:

```text
doctor/
│
├── backend/
│   ├── Cargo.toml
│   └── src/
│       └── main.rs
│
├── frontend/
│   ├── package.json
│   ├── app/
│   └── next.config.ts
│
├── database/
│
├── redis/
│
├── testing/
│
├── docker/
│   ├── backend.Dockerfile
│   ├── frontend.Dockerfile
│   └── postgres/
│       └── init.sql
│
└── docker-compose.yml
```

---

# Running Projects

Start a project:

```bash
./dock-rust.sh up doctor
```

Stop a project:

```bash
./dock-rust.sh down doctor
```

---

# Technology Stack

## Frontend

- Next.js
- React
- TypeScript
- Bun

## Backend

- Rust
- Axum
- Tokio

## Infrastructure

- Docker
- Docker Compose
- PostgreSQL
- Redis

---

# Project Philosophy

Dock-Rust follows a template-driven approach.

The generated projects inside:

```text
Projects/
```

are created from:

```text
templates/
```

All improvements are made by updating templates rather than manually modifying generated projects.

This ensures every new project receives the latest architecture and configuration.

---

# Roadmap

Future improvements:

- Project update command
- Template versioning
- Automated migrations
- Database tooling
- Test generation
- CI/CD templates
- Security scanning
- Production Docker builds
- Kubernetes templates

---

# Commands

Available commands:

```bash
dock-rust doctor
```

Checks system requirements.

```bash
dock-rust new
```

Creates a new project.

```bash
dock-rust up <project>
```

Starts containers.

```bash
dock-rust down <project>
```

Stops containers.

---

Built with:

- Bash
- Docker
- Rust
- Next.js
- Bun
