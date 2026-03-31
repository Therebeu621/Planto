# Build stage
FROM debian:bookworm-slim AS build

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
ENV FLUTTER_VERSION="3.24.0"
RUN git clone https://github.com/flutter/flutter.git /flutter --branch stable --depth 1
ENV PATH="/flutter/bin:$PATH"

# Pre-download Flutter dependencies
RUN flutter precache --web
RUN flutter doctor

# Set working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the app
COPY . .

# Build for web (API_BASE_URL can be overridden at build time)
ARG API_BASE_URL=""
RUN if [ -n "$API_BASE_URL" ]; then \
      flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL; \
    else \
      flutter build web --release; \
    fi

# Production stage - lightweight nginx server
FROM nginx:alpine

# Copy built web app and disable service worker caching
COPY --from=build /app/build/web /usr/share/nginx/html
RUN rm -f /usr/share/nginx/html/flutter_service_worker.js

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
