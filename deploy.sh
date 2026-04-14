#!/bin/bash

# ============================================
# GegoK12 AWS Deployment Script
# ============================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ] && [ "$1" != "docker-only" ]; then 
    print_warning "This script needs root privileges for initial setup."
    echo "Please run: sudo bash deploy.sh"
    exit 1
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")
export SERVER_IP

print_header "GegoK12 Docker Deployment Script"

# ============================================
# Step 1: Install Docker
# ============================================
print_header "Step 1: Installing Docker"

if command -v docker &> /dev/null; then
    print_success "Docker is already installed"
    docker --version
else
    print_info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    
    # Add current user to docker group
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
    else
        usermod -aG docker $(whoami)
    fi
    
    # Start Docker
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker installed successfully"
    docker --version
fi

# ============================================
# Step 2: Install Docker Compose
# ============================================
print_header "Step 2: Installing Docker Compose"

if command -v docker-compose &> /dev/null; then
    print_success "Docker Compose is already installed"
    docker-compose --version
else
    print_info "Installing Docker Compose..."
    apt update && apt install -y docker-compose
    print_success "Docker Compose installed"
fi

# ============================================
# Step 3: Check and Create Directory
# ============================================
print_header "Step 3: Setting Up Application Directory"

APP_DIR="/var/www/gegok12"

if [ -d "$APP_DIR" ]; then
    print_warning "Directory $APP_DIR already exists"
    read -p "Do you want to update the existing installation? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Exiting. Set a different directory or backup existing files."
        exit 1
    fi
else
    mkdir -p $APP_DIR
    print_success "Created directory: $APP_DIR"
fi

# ============================================
# Step 4: Copy Application Files
# ============================================
print_header "Step 4: Copying Application Files"

CURRENT_DIR=$(pwd)

# Copy files to app directory
cp -r $CURRENT_DIR/* $APP_DIR/ 2>/dev/null || true

# Create necessary directories
mkdir -p $APP_DIR/storage/{app,framework/{cache,sessions,views},logs}
mkdir -p $APP_DIR/bootstrap/cache

# Set permissions
chmod -R 775 $APP_DIR/storage
chmod -R 775 $APP_DIR/bootstrap/cache
chmod -R 777 $APP_DIR/storage

print_success "Application files copied"

# ============================================
# Step 5: Configure Environment
# ============================================
print_header "Step 5: Configuring Environment"

ENV_FILE="$APP_DIR/.env"

# Generate random password for database
DB_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)

if [ ! -f "$ENV_FILE" ]; then
    cp $APP_DIR/.env.example $ENV_FILE
    print_success "Created .env file from example"
fi

# Update .env with Docker settings
sed -i "s/DB_HOST=127.0.0.1/DB_HOST=db/g" $ENV_FILE
sed -i "s/DB_CONNECTION=mysql/DB_CONNECTION=mysql/g" $ENV_FILE
sed -i "s/DB_PORT=3306/DB_PORT=3306/g" $ENV_FILE
sed -i "s/DB_DATABASE=homestead/DB_DATABASE=school/g" $ENV_FILE
sed -i "s/DB_USERNAME=homestead/DB_USERNAME=laravel/g" $ENV_FILE
sed -i "s/DB_PASSWORD=secret/DB_PASSWORD=$DB_PASSWORD/g" $ENV_FILE
sed -i "s/APP_ENV=local/APP_ENV=production/g" $ENV_FILE
sed -i "s/APP_DEBUG=false/APP_DEBUG=false/g" $ENV_FILE
sed -i "s|APP_URL=http://localhost|APP_URL=http://$SERVER_IP|g" $ENV_FILE
sed -i "s/CACHE_DRIVER=file/CACHE_DRIVER=file/g" $ENV_FILE
sed -i "s/SESSION_DRIVER=file/SESSION_DRIVER=file/g" $ENV_FILE

print_success "Environment configured"
print_info "Database password: $DB_PASSWORD (save this!)"

# ============================================
# Step 6: Start Docker Containers
# ============================================
print_header "Step 6: Starting Docker Containers"

cd $APP_DIR

# Update docker-compose with correct password
sed -i "s/root_password/$DB_PASSWORD/g" docker-compose.yml

# Build and start containers
print_info "Building containers (this may take a few minutes)..."
docker-compose up -d --build

# Wait for database to be ready
print_info "Waiting for database to be ready..."
sleep 10

# Check if containers are running
sleep 5
docker-compose ps

print_success "Containers started"

# ============================================
# Step 7: Setup Laravel
# ============================================
print_header "Step 7: Setting Up Laravel"

# Generate application key
print_info "Generating application key..."
docker-compose exec -T app php artisan key:generate

# Run migrations
print_info "Running database migrations..."
docker-compose exec -T app php artisan migrate --force

# Create storage link
print_info "Creating storage link..."
docker-compose exec -T app php artisan storage:link

# Clear caches
print_info "Clearing caches..."
docker-compose exec -T app php artisan config:clear
docker-compose exec -T app php artisan cache:clear
docker-compose exec -T app php artisan route:clear
docker-compose exec -T app php artisan view:clear

print_success "Laravel setup complete"

# ============================================
# Step 8: Install NPM Dependencies
# ============================================
print_header "Step 8: Installing Frontend Dependencies"

print_info "This may take a few minutes..."
docker-compose exec -T node npm install 2>/dev/null || print_warning "NPM install skipped - run manually if needed"

# Build assets (optional - comment out if not needed)
# print_info "Building frontend assets..."
# docker-compose exec -T node npm run production 2>/dev/null || print_warning "NPM build skipped"

print_success "Frontend dependencies processed"

# ============================================
# Step 9: Configure Firewall
# ============================================
print_header "Step 9: Configuring Firewall"

# Allow SSH (already default)
# ufw allow 22/tcp

# Allow HTTP
ufw allow 80/tcp 2>/dev/null || true
ufw allow 443/tcp 2>/dev/null || true

# Allow phpMyAdmin (optional - disable in production!)
ufw allow 8092/tcp 2>/dev/null || true

# Reload firewall
ufw reload 2>/dev/null || true

print_success "Firewall configured"

# ============================================
# Final Information
# ============================================
print_header "Deployment Complete!"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Your GegoK12 App is Ready!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "  🌐 App URL:       ${BLUE}http://$SERVER_IP${NC}"
echo -e "  📊 phpMyAdmin:    ${BLUE}http://$SERVER_IP:8092${NC}"
echo -e "  🔐 DB User:       laravel"
echo -e "  🔑 DB Pass:      $DB_PASSWORD"
echo -e "  📁 App Dir:      $APP_DIR"
echo ""
echo "  Useful Commands:"
echo "  ----------------"
echo "  - View logs:    cd $APP_DIR && docker-compose logs -f"
echo "  - Restart:      cd $APP_DIR && docker-compose restart"
echo "  - Stop:         cd $APP_DIR && docker-compose down"
echo "  - SSH to app:   cd $APP_DIR && docker-compose exec app bash"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT SECURITY NOTES:${NC}"
echo "  1. Change the database password in production!"
echo "  2. Disable phpMyAdmin port (8092) after setup!"
echo "  3. Set APP_DEBUG=false in production!"
echo "  4. Consider setting up SSL with Let's Encrypt"
echo ""
print_success "Deployment successful!"