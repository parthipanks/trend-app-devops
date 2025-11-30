# Use Node to serve the static dist folder
FROM node:18-alpine

# Workdir inside container
WORKDIR /app

# Install a simple static file server
RUN npm install -g serve

# Copy the pre-built static files from dist folder
COPY dist ./dist

# Expose port 3000 inside the container
EXPOSE 3000

# Serve the 'dist' folder on port 3000
CMD ["serve", "-s", "dist", "-l", "3000"]
