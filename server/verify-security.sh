#!/bin/bash

# Security Verification Script for Mobile Proxy Server
# Run this script to verify the security configuration

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Mobile Proxy Server - Security Verification             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

VPS_IP="139.59.22.1"

echo "Testing port accessibility from external network..."
echo ""

# Test WebSocket port (should be accessible)
echo "1. Testing WebSocket port 8080 (should be OPEN)..."
timeout 3 bash -c "echo > /dev/tcp/$VPS_IP/8080" 2>/dev/null && echo "   ✅ Port 8080 is OPEN (Correct - WebSocket needs external access)" || echo "   ❌ Port 8080 is CLOSED (Error - WebSocket should be accessible)"
echo ""

# Test Data Tunnel port (should be accessible)
echo "2. Testing Data Tunnel port 8081 (should be OPEN)..."
timeout 3 bash -c "echo > /dev/tcp/$VPS_IP/8081" 2>/dev/null && echo "   ✅ Port 8081 is OPEN (Correct - Data tunnel needs external access)" || echo "   ❌ Port 8081 is CLOSED (Error - Data tunnel should be accessible)"
echo ""

# Test Proxy port (should NOT be accessible externally)
echo "3. Testing Proxy port 1080 (should be CLOSED externally)..."
timeout 3 bash -c "echo > /dev/tcp/$VPS_IP/1080" 2>/dev/null && echo "   ❌ Port 1080 is OPEN (Security Risk - Proxy should be localhost only!)" || echo "   ✅ Port 1080 is CLOSED (Correct - Proxy is secured to localhost)"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Expected Results:"
echo "  ✅ Port 8080: OPEN (WebSocket)"
echo "  ✅ Port 8081: OPEN (Data Tunnel)"
echo "  ✅ Port 1080: CLOSED (Proxy - localhost only)"
echo ""
echo "If all tests pass, your server is properly secured!"
echo ""
