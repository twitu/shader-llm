# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
FROM elixir:1.15-alpine

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache build-base git

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy all application files
COPY . .

# Compile the application
ENV MIX_ENV=prod
RUN mix compile

# Run the application
CMD ["mix", "run", "--no-halt"] 
