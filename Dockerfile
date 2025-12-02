# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app

# Copy dependencies
COPY package*.json ./
RUN npm ci --prefer-offline

# Copy all source files
COPY . .

# Build Vite React app
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:stable-alpine

# Copy build output
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]






# # Stage 1: Build React app
# FROM node:20-alpine AS builder

# WORKDIR /app

# # Copy package.json and package-lock.json
# COPY package*.json ./

# # Install dependencies
# RUN npm install

# # Copy all source files
# COPY . .

# # Build the React app
# RUN npm run build

# # Stage 2: Serve with Nginx
# FROM nginx:stable-alpine

# # Copy build output to Nginx folder
# COPY --from=builder /app/dist /usr/share/nginx/html


# EXPOSE 80

# CMD ["nginx", "-g", "daemon off;"]
