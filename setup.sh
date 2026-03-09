#!/bin/bash
set -e

# =============================================================================
# Cloudflare Tunnel Setup Script
# =============================================================================
# This script sets up Cloudflare Tunnel for SSH Zero Trust access on Ubuntu.
# It installs OpenSSH Server if needed, configures SSH, and starts the tunnel.
#
# Usage: ./setup.sh
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# =============================================================================
# Prerequisites Check
# =============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_warning "This script should not be run as root. It will use sudo when needed."
        exit 1
    fi

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed."
        print_info "Please install Docker first: https://docs.docker.com/engine/install/ubuntu/"
        exit 1
    fi
    print_success "Docker is installed"

    # Check if docker compose is available
    if ! docker compose version &> /dev/null && ! docker-compose version &> /dev/null; then
        print_error "Docker Compose is not installed."
        print_info "Please install Docker Compose first: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_success "Docker Compose is installed"

    # Check if user can run docker
    if ! docker ps &> /dev/null; then
        print_error "Cannot run Docker commands. You may need to add your user to the docker group:"
        print_info "  sudo usermod -aG docker \$USER"
        print_info "  newgrp docker"
        print_info "Then log out and back in for changes to take effect."
        exit 1
    fi
    print_success "Docker is accessible"

    echo ""
}

# =============================================================================
# OpenSSH Server Installation and Configuration
# =============================================================================

install_and_configure_ssh() {
    print_header "OpenSSH Server Setup"

    # Check if sshd exists
    if ! command -v sshd &> /dev/null; then
        print_warning "OpenSSH Server is not installed. Installing..."

        # Update package list
        print_info "Updating package list..."
        sudo apt update

        # Install openssh-server
        print_info "Installing openssh-server..."
        sudo DEBIAN_FRONTEND=noninteractive apt install -y openssh-server

        print_success "OpenSSH Server installed"
    else
        print_success "OpenSSH Server is already installed"
    fi

    # Ensure SSH service is enabled
    print_info "Enabling SSH service..."
    sudo systemctl enable ssh 2>/dev/null || sudo systemctl enable sshd 2>/dev/null

    # Start SSH service if not running
    if ! sudo systemctl is-active --quiet ssh && ! sudo systemctl is-active --quiet sshd; then
        print_info "Starting SSH service..."
        sudo systemctl start ssh 2>/dev/null || sudo systemctl start sshd 2>/dev/null
        print_success "SSH service started"
    else
        print_success "SSH service is already running"
    fi

    # Verify SSH is listening on port 22
    print_info "Verifying SSH is listening on port 22..."
    sleep 2  # Give it a moment to start

    if ss -tln 2>/dev/null | grep -q ':22' || netstat -tln 2>/dev/null | grep -q ':22'; then
        print_success "SSH is listening on port 22"
    else
        print_warning "Could not verify SSH is listening. Check manually with: sudo ss -tlnp | grep :22"
    fi

    echo ""
}

# =============================================================================
# Environment Configuration
# =============================================================================

validate_env_file() {
    print_header "Environment Configuration"

    # Check if .env file exists
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        print_warning ".env file not found. Creating from .env.example..."
        if [ -f "$SCRIPT_DIR/.env.example" ]; then
            cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
            print_success ".env file created"
        else
            print_error ".env.example not found. Please create .env file manually."
            exit 1
        fi
    fi

    # Check if TUNNEL_TOKEN is set
    if ! grep -q "^TUNNEL_TOKEN=" "$SCRIPT_DIR/.env" || grep -q "^TUNNEL_TOKEN=$" "$SCRIPT_DIR/.env"; then
        print_error "TUNNEL_TOKEN is not set in .env file."
        print_info "Please add your Cloudflare Tunnel token to the .env file:"
        print_info "  nano .env"
        print_info "Get your token from: https://one.dash.cloudflare.com/ -> Access -> Tunnels -> Your Tunnel"
        exit 1
    fi

    # Extract and validate token format (basic check for JWT format)
    TUNNEL_TOKEN=$(grep "^TUNNEL_TOKEN=" "$SCRIPT_DIR/.env" | cut -d'=' -f2-)
    if [[ ! "$TUNNEL_TOKEN" =~ ^eyJ ]]; then
        print_warning "TUNNEL_TOKEN format looks unusual (should start with 'eyJ')"
        print_info "Current token: ${TUNNEL_TOKEN:0:20}..."
    else
        print_success "TUNNEL_TOKEN is set"
    fi

    echo ""
}

# =============================================================================
# Docker Compose Operations
# =============================================================================

start_tunnel() {
    print_header "Starting Cloudflare Tunnel"

    # Stop existing container if running
    if docker ps -a --format '{{.Names}}' | grep -q '^cloudflared-ssh-tunnel$'; then
        print_info "Stopping existing cloudflared container..."
        docker compose down
    fi

    # Pull latest image
    print_info "Pulling latest cloudflared image..."
    docker compose pull

    # Start the tunnel
    print_info "Starting Cloudflare Tunnel..."
    docker compose up -d

    # Wait a moment for container to start
    sleep 3

    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q '^cloudflared-ssh-tunnel$'; then
        print_success "Cloudflare Tunnel container is running"
    else
        print_error "Failed to start Cloudflare Tunnel container"
        print_info "Check logs with: docker compose logs cloudflared"
        exit 1
    fi

    echo ""
}

# =============================================================================
# Verification
# =============================================================================

verify_setup() {
    print_header "Verification"

    # Check SSH is listening
    print_info "Checking SSH service..."
    if ss -tln 2>/dev/null | grep -q ':22' || netstat -tln 2>/dev/null | grep -q ':22'; then
        print_success "SSH is listening on port 22"
    else
        print_warning "Could not verify SSH is listening on port 22"
        print_info "Check manually: sudo ss -tlnp | grep :22"
    fi

    # Check Docker container
    print_info "Checking Docker container..."
    if docker ps --format '{{.Names}}' | grep -q '^cloudflared-ssh-tunnel$'; then
        print_success "Cloudflare Tunnel container is running"
    else
        print_error "Cloudflare Tunnel container is not running"
        return 1
    fi

    # Check container logs for successful connection
    print_info "Checking tunnel connection status..."
    if docker compose logs --tail=20 cloudflared 2>/dev/null | grep -q "connected\|INF.*connection"; then
        print_success "Tunnel is connected to Cloudflare"
    else
        print_warning "Could not verify tunnel connection. Check logs:"
        print_info "  docker compose logs -f cloudflared"
    fi

    echo ""
}

# =============================================================================
# Next Steps
# =============================================================================

print_next_steps() {
    print_header "Setup Complete!"

    echo -e "${GREEN}Your Cloudflare Tunnel for SSH Zero Trust Access is ready!${NC}"
    echo ""
    echo "Next Steps:"
    echo ""
    echo "1. Configure your SSH application in Cloudflare Zero Trust:"
    echo "   - Go to: https://one.dash.cloudflare.com/"
    echo "   - Navigate to: Access -> Applications -> Add an application"
    echo "   - Set up SSH access with hostname: ssh-homelab.kelanach.xyz"
    echo ""
    echo "2. Configure the public hostname for your tunnel:"
    echo "   - Go to: Access -> Tunnels -> Your Tunnel"
    echo "   - Add Public Hostname:"
    echo "     - Subdomain: ssh-homelab"
    echo "     - Domain: kelanach.xyz"
    echo "     - Service: SSH"
    echo "     - URL: ssh://localhost:22"
    echo ""
    echo "3. Test the connection:"
    echo "   - Visit your application URL in a browser"
    echo "   - Authenticate using Cloudflare Access"
    echo "   - Access your host via browser-based SSH"
    echo ""
    echo "Useful Commands:"
    echo "  - View logs:         docker compose logs -f cloudflared"
    echo "  - Stop tunnel:       docker compose down"
    echo "  - Restart tunnel:    docker compose restart"
    echo "  - Check status:      docker compose ps"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    clear
    print_header "Cloudflare Tunnel Setup for SSH Zero Trust Access"

    check_prerequisites
    install_and_configure_ssh
    validate_env_file
    start_tunnel
    verify_setup
    print_next_steps

    print_success "Setup completed successfully!"
    echo ""
}

# Run main function
main
