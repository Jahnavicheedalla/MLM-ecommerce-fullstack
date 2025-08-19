# 🚀 Multi-Level Marketing Application Deployment Guide

This guide will help you deploy your MLM application with nginx and set up proper file upload handling.

## 📋 Prerequisites

- Ubuntu 20.04+ server
- Root or sudo access
- Domain name (optional but recommended)
- SSH access to your server

## 🛠️ Quick Deployment

### 1. Upload Your Code
```bash
# On your local machine, upload the project to your server
scp -r multi-level-marketing/ user@your-server-ip:/tmp/
```

### 2. Run the Deployment Script
```bash
# SSH into your server
ssh user@your-server-ip

# Switch to root
sudo su

# Navigate to the uploaded project
cd /tmp/multi-level-marketing

# Make the deployment script executable
chmod +x deploy.sh

# Run the deployment script
./deploy.sh
```

## 🔧 Manual Deployment Steps

If you prefer to deploy manually, follow these steps:

### 1. Server Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git nginx postgresql postgresql-contrib

# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt install -y nodejs

# Install PM2
sudo npm install -g pm2
```

### 2. Application Setup

```bash
# Create application directory
sudo mkdir -p /var/www/multi-level-marketing
sudo mkdir -p /var/www/multi-level-marketing/uploads

# Set permissions
sudo chown -R www-data:www-data /var/www/multi-level-marketing
sudo chmod -R 755 /var/www/multi-level-marketing
sudo chmod -R 777 /var/www/multi-level-marketing/uploads

# Copy your application files
sudo cp -r /tmp/multi-level-marketing/* /var/www/multi-level-marketing/
cd /var/www/multi-level-marketing

# Install dependencies
npm install

# Build the application
npm run build
```

### 3. Environment Configuration

Create a `.env` file in `/var/www/multi-level-marketing/`:

```env
# Database Configuration
DATABASE_URL=postgresql://mlm_user:your_secure_password@localhost:5432/mlm_database

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
```

### 4. Database Setup

```bash
# Create database and user
sudo -u postgres psql -c "CREATE DATABASE mlm_database;"
sudo -u postgres psql -c "CREATE USER mlm_user WITH ENCRYPTED PASSWORD 'your_secure_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mlm_database TO mlm_user;"
sudo -u postgres psql -c "\c mlm_database; GRANT ALL ON SCHEMA public TO mlm_user;"

# Run migrations
npm run migrate
```

### 5. Nginx Configuration

```bash
# Copy nginx configuration
sudo cp nginx.conf /etc/nginx/sites-available/multi-level-marketing

# Update the domain in nginx config
sudo sed -i 's/your-domain.com/your-actual-domain.com/g' /etc/nginx/sites-available/multi-level-marketing

# Update uploads path
sudo sed -i 's|/var/www/multi-level-marketing/uploads/|/var/www/multi-level-marketing/uploads/|g' /etc/nginx/sites-available/multi-level-marketing

# Enable the site
sudo ln -sf /etc/nginx/sites-available/multi-level-marketing /etc/nginx/sites-enabled/

# Test nginx configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### 6. PM2 Configuration

Create `ecosystem.config.js`:

```javascript
module.exports = {
  apps: [{
    name: 'multi-level-marketing',
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
```

### 7. Start the Application

```bash
# Create logs directory
mkdir -p logs

# Start with PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Setup PM2 to start on boot
pm2 startup systemd -u root --hp /root
```

### 8. Firewall Setup

```bash
# Allow SSH and Nginx
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable
```

## 📁 File Upload Configuration

### How File Uploads Work

1. **Upload Process**:
   - Users upload files through your API endpoints
   - Files are saved to `/var/www/multi-level-marketing/uploads/`
   - File URLs are stored in the database

2. **File Serving**:
   - Nginx serves files directly from the uploads directory
   - Files are accessible at `http://your-domain.com/uploads/filename.jpg`
   - Only image files (jpg, jpeg, png, gif, webp) are allowed

3. **Security**:
   - File size limit: 10MB
   - Only image files are accepted
   - Direct access to executable files is blocked

### File Upload Endpoints

Your application already has these endpoints:

- `POST /product/add-with-photo` - Add product with photo
- Files are automatically saved and URLs are stored in the database

### Example File Upload Response

```json
{
  "statusCode": 201,
  "message": "Product added successfully",
  "data": {
    "id": 1,
    "productName": "Sample Product",
    "photoUrl": "http://your-domain.com/uploads/uuid-filename.jpg",
    "createdAt": "2024-01-01T00:00:00.000Z"
  }
}
```

## 🔍 Monitoring and Maintenance

### Check Application Status
```bash
# View PM2 status
pm2 status

# View logs
pm2 logs multi-level-marketing

# Restart application
pm2 restart multi-level-marketing
```

### Update Application
```bash
# Pull latest changes
git pull

# Install dependencies
npm install

# Build application
npm run build

# Restart application
pm2 restart multi-level-marketing
```

### Monitor File Uploads
```bash
# Check uploads directory
ls -la /var/www/multi-level-marketing/uploads/

# Check disk usage
df -h /var/www/multi-level-marketing/uploads/

# Monitor nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## 🔒 Security Considerations

### 1. File Upload Security
- Only image files are allowed
- File size is limited to 10MB
- Files are served with proper headers
- Direct access to executable files is blocked

### 2. Environment Variables
- Use strong JWT secrets
- Use secure database passwords
- Keep your `.env` file secure

### 3. SSL/HTTPS
- Enable HTTPS for production
- Use Let's Encrypt for free SSL certificates
- Update your nginx configuration for SSL

### 4. Firewall
- Only allow necessary ports (80, 443, 22)
- Use UFW or iptables for firewall management

## 🚨 Troubleshooting

### Common Issues

1. **Application won't start**:
   ```bash
   # Check logs
   pm2 logs multi-level-marketing
   
   # Check environment variables
   cat .env
   
   # Check database connection
   npm run migrate
   ```

2. **File uploads not working**:
   ```bash
   # Check uploads directory permissions
   ls -la /var/www/multi-level-marketing/uploads/
   
   # Check nginx configuration
   sudo nginx -t
   
   # Check nginx logs
   sudo tail -f /var/log/nginx/error.log
   ```

3. **Database connection issues**:
   ```bash
   # Check PostgreSQL status
   sudo systemctl status postgresql
   
   # Test database connection
   psql -h localhost -U mlm_user -d mlm_database
   ```

4. **Nginx issues**:
   ```bash
   # Test nginx configuration
   sudo nginx -t
   
   # Restart nginx
   sudo systemctl restart nginx
   
   # Check nginx status
   sudo systemctl status nginx
   ```

## 📞 Support

If you encounter any issues:

1. Check the logs: `pm2 logs multi-level-marketing`
2. Verify your environment configuration
3. Ensure all services are running
4. Check file permissions and ownership

## 🎉 Success!

Once deployed, your application will be available at:
- **Main Application**: `http://your-domain.com`
- **API Documentation**: `http://your-domain.com/api-docs`
- **Health Check**: `http://your-domain.com/health`
- **File Uploads**: `http://your-domain.com/uploads/`

Your file upload system is now fully configured and ready for production use! 🚀
