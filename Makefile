.PHONY: dev-frontend dev-backend dev clean help setup

# Default target when just running 'make'
help:
	@echo "✨ Available commands:"
	@echo "  make setup        - 🔧 Setup development environment (asdf, bundle config)"
	@echo "  make dev          - 🚀 Start both frontend and backend servers"
	@echo "  make dev-frontend - 🌐 Start frontend dev server only"
	@echo "  make dev-backend  - 🔌 Start backend dev server only"
	@echo "  make clean        - 🧹 Kill all development servers"

# Setup development environment
setup:
	@echo "🔧 Setting up development environment..."
	@echo "📦 Installing Ruby and Node.js using asdf..."
	@asdf install
	@echo "💎 Configuring Bundler..."
	@cd backend && bundle config set --local path vendor/bundle
	@echo "📚 Installing backend dependencies..."
	@cd backend && bundle install
	@echo "📦 Installing frontend dependencies..."
	@cd frontend && bun install
	@echo "✅ Development environment setup complete!"

# Start frontend development server
dev-frontend:
	@echo "🌐 Starting frontend development server..."
	@cd frontend && bun run dev

# Start backend development server
dev-backend:
	@echo "🔌 Starting backend development server..."
	@cd backend && bundle exec rails s

# Start both servers in separate iTerm tabs
dev:
	@echo "🚀 Starting both frontend and backend servers in separate iTerm tabs..."
	@osascript -e 'tell application "iTerm"' \
		-e 'create window with default profile' \
		-e 'tell current session of current window' \
		-e 'write text "cd $(shell pwd)/backend && bundle exec rails s"' \
		-e 'set name to "Backend Server"' \
		-e 'end tell' \
		-e 'tell current window' \
		-e 'create tab with default profile' \
		-e 'tell current session of current tab' \
		-e 'write text "cd $(shell pwd)/frontend && bun run dev"' \
		-e 'set name to "Frontend Server"' \
		-e 'end tell' \
		-e 'end tell' \
		-e 'end tell'
	@echo "✅ Servers started in separate iTerm tabs."

# Clean up processes
clean:
	@echo "🧹 Cleaning up development servers..."
	@pkill -f "bun run dev" || true
	@pkill -f "rails s" || true
	@echo "🎉 All development servers stopped."
