#!/bin/bash

# Multi-Level Marketing Application Deployment Script
# This script sets up the server environment and deploys the application

set -e  # Exit on any error

echo "🚀 Starting deployment of Multi-Level Marketing Application..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="multi-level-marketing"
APP_DIR="/var/www/$APP_NAME"
NGINX_CONF="/etc/nginx/sites-available/$APP_NAME"
NGINX_ENABLED="/etc/nginx/sites-enabled/$APP_NAME"
SERVICE_NAME="$APP_NAME"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Update system packages
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install required packages
print_status "Installing required packages..."
apt install -y curl wget git nginx postgresql postgresql-contrib

# Install Node.js 18.x
print_status "Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Install PM2 for process management
print_status "Installing PM2..."
npm install -g pm2

# Create application directory
print_status "Creating application directory..."
mkdir -p $APP_DIR
mkdir -p $APP_DIR/uploads

# Set proper permissions
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR
chmod -R 777 $APP_DIR/uploads

# Copy application files (assuming you're running this from the project directory)
print_status "Copying application files..."
cp -r . $APP_DIR/
cd $APP_DIR

# Install dependencies
print_status "Installing Node.js dependencies..."
npm install

# Build the application
print_status "Building the application..."
npm run build

# Create environment file if it doesn't exist
if [ ! -f .env ]; then
    print_warning "Creating .env file template..."
    cat > .env << EOF
# Database Configuration
DATABASE_URL=postgresql://username:password@localhost:5432/mlm_database

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production

# Server Configuration
SERVER_PORT=3000
NODE_ENV=production

# CORS Configuration
CORS_ORIGIN=http://your-domain.com,https://your-domain.com

# Base URL for file uploads
BASE_URL=http://your-domain.com
NGINX_BASE_URL=http://your-domain.com

# Razorpay Configuration (optional)
RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret
RAZORPAY_WEBHOOK_SECRET=your_razorpay_webhook_secret
EOF
    print_warning "Please update the .env file with your actual configuration values"
fi

# Setup nginx configuration
print_status "Setting up nginx configuration..."
cp nginx.conf $NGINX_CONF

# Replace placeholder domain with actual domain (you'll need to update this)
sed -i 's/your-domain.com/your-actual-domain.com/g' $NGINX_CONF

# Update uploads path in nginx config
sed -i "s|/var/www/multi-level-marketing/uploads/|$APP_DIR/uploads/|g" $NGINX_CONF

# Enable the site
ln -sf $NGINX_CONF $NGINX_ENABLED

# Test nginx configuration
print_status "Testing nginx configuration..."
nginx -t

# Restart nginx
print_status "Restarting nginx..."
systemctl restart nginx
systemctl enable nginx

# Create PM2 ecosystem file
print_status "Creating PM2 configuration..."
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: '$SERVICE_NAME',
    script: 'dist/src/main.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    restart_delay: 4000,
    max_restarts: 10,
    min_uptime: '10s'
  }]
};
EOF

# Create logs directory
mkdir -p logs

# Start the application with PM2
print_status "Starting application with PM2..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Setup PM2 to start on boot
pm2 startup systemd -u root --hp /root

# Create database setup script
print_status "Creating database setup script..."
cat > setup-database.sql << EOF
-- Create database and user for MLM application
CREATE DATABASE mlm_database;
CREATE USER mlm_user WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE mlm_database TO mlm_user;
\c mlm_database;
GRANT ALL ON SCHEMA public TO mlm_user;
EOF

print_status "Database setup script created. Run the following commands:"
echo "sudo -u postgres psql -f setup-database.sql"
echo "npm run migrate"

# Setup firewall
print_status "Setting up firewall..."
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Create maintenance script
print_status "Creating maintenance scripts..."
cat > maintenance.sh << 'EOF'
#!/bin/bash
# Maintenance script for MLM application

case "$1" in
    restart)
        echo "Restarting application..."
        pm2 restart multi-level-marketing
        ;;
    stop)
        echo "Stopping application..."
        pm2 stop multi-level-marketing
        ;;
    start)
        echo "Starting application..."
        pm2 start multi-level-marketing
        ;;
    logs)
        echo "Showing application logs..."
        pm2 logs multi-level-marketing
        ;;
    status)
        echo "Application status:"
        pm2 status
        ;;
    update)
        echo "Updating application..."
        git pull
        npm install
        npm run build
        pm2 restart multi-level-marketing
        ;;
    *)
        echo "Usage: $0 {restart|stop|start|logs|status|update}"
        exit 1
        ;;
esac
EOF

chmod +x maintenance.sh

print_status "Deployment completed successfully! 🎉"
echo ""
echo "Next steps:"
echo "1. Update the .env file with your actual configuration"
echo "2. Set up your database: sudo -u postgres psql -f setup-database.sql"
echo "3. Run database migrations: npm run migrate"
echo "4. Update your domain in nginx.conf"
echo "5. Test the application: http://your-domain.com"
echo ""
echo "Useful commands:"
echo "- Check application status: ./maintenance.sh status"
echo "- View logs: ./maintenance.sh logs"
echo "- Restart application: ./maintenance.sh restart"
echo "- Update application: ./maintenance.sh update"
echo ""
echo "File uploads will be available at: http://your-domain.com/uploads/"
