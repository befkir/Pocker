# build stage
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# copy pubspec and get dependencies
COPY pubspec.* ./
RUN flutter pub get

# copy the rest of the app
COPY . .

# build web
RUN flutter build web --release

# serve with simple nginx server
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy custom nginx config for reverse proxying API requests
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
