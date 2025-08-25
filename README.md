# Apache Monitoring Extension for AppDynamics

A lightweight, custom monitoring solution for Apache web servers that integrates seamlessly with AppDynamics Machine Agent to provide real-time performance metrics.

## Overview

This solution provides comprehensive Apache monitoring through AppDynamics custom metrics, collecting key performance indicators including server load, request statistics, worker utilization, CPU usage, and traffic metrics.

## Features

- **Real-time Metrics Collection**: Gathers 20+ Apache performance metrics every minute
- **Whole Number Values**: All metrics converted to integers for cleaner dashboards
- **Multi-Server Support**: Monitor multiple Apache instances from a single script
- **Protocol Flexibility**: Automatically tries HTTP and HTTPS endpoints
- **Health Monitoring**: Built-in script health and status tracking
- **AppDynamics Integration**: Native format output for Machine Agent consumption

## Collected Metrics

### Load Metrics
- System load averages (1min, 5min, 15min) × 100
- CPU user and system utilization × 100

### Request Metrics  
- Total requests served
- Requests per 1000 seconds
- Bytes per request/second

### Worker Metrics
- Busy/idle worker counts
- Worker utilization percentage
- Total worker capacity

### Server Metrics
- Uptime in seconds and days
- Total traffic in KB
- Server status (up/down)

## Quick Start

### Prerequisites

- Apache web server with mod_status enabled
- AppDynamics Machine Agent installed
- curl utility available

### 1. Apache Configuration

Enable Apache status module and configure access:

```bash
# Enable mod_status
sudo a2enmod status

# Create status configuration
sudo tee /etc/apache2/conf-available/apache-status.conf << 'EOF'
<IfModule mod_status.c>
    ExtendedStatus On
    
    <Location "/server-status">
        SetHandler server-status
        Require local
        Require ip 127.0.0.1
        # Add your monitoring server IPs
        Require ip 10.0.0.0/8
        Require ip 172.16.0.0/12  
        Require ip 192.168.0.0/16
    </Location>
</IfModule>
EOF

# Enable configuration and restart
sudo a2enconf apache-status
sudo systemctl restart apache2
```

### 2. Verify Apache Status

Test that the status endpoint is accessible:

```bash
curl http://localhost/server-status?auto
```

You should see output containing `ServerVersion:` and various metrics.

### 3. Deploy Monitoring Script

```bash
# Navigate to Machine Agent monitors directory
cd /opt/appdynamics/machine-agent/monitors/

# Create monitor directory
sudo mkdir ApacheMonitor
cd ApacheMonitor

# Download monitoring script
wget https://raw.githubusercontent.com/Abhimanyu9988/apache-appdynamics-monitoring/main/apache-monitor.sh
chmod +x apache-monitor.sh

# Download monitor configuration
wget https://raw.githubusercontent.com/Abhimanyu9988/apache-appdynamics-monitoring/main/monitor.xml
```

### 4. Configure Servers

Edit the script to specify your Apache servers:

```bash
vim apache-monitor.sh

# Update this section:
SERVERS=(
    "your-apache-server1.com"
    "your-apache-server2.com" 
    "localhost"
)
```

### 5. Test the Script

```bash
./apache-monitor.sh
```

Expected output format:
```
name=Custom Metrics|Apache Monitor|localhost|Status,value=1
name=Custom Metrics|Apache Monitor|localhost|Load Average|1 Minute x100,value=132
name=Custom Metrics|Apache Monitor|localhost|Requests|Total Accesses,value=1250
...
```

### 6. Deploy to Machine Agent

Create `monitor.xml` configuration:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<monitor>
    <name>ApacheMonitor</name>
    <type>managed</type>
    <description>Apache Server Monitoring for AppDynamics</description>
    <monitor-run-task>
        <execution-style>periodic</execution-style>
        <execution-frequency-in-seconds>60</execution-frequency-in-seconds>
        <name>Apache Monitor Task</name>
        <type>executable</type>
        <executable-task>
            <type>file</type>
            <file>apache-monitor.sh</file>
        </executable-task>
    </monitor-run-task>
</monitor>
```

Restart the Machine Agent:
```bash
sudo systemctl restart appdynamics-machine-agent
```

## Viewing Metrics in AppDynamics

Metrics appear in AppDynamics Controller under:
```
Application Infrastructure Performance > [Your Tier] > Custom Metrics > Apache Monitor
```

### Metric Categories
- **Status**: Server availability (0=down, 1=up)
- **Load Average**: System load × 100 
- **Requests**: Access counts and rates
- **Traffic**: Bandwidth utilization
- **CPU**: Processor usage × 100
- **Workers**: Apache worker thread status
- **Server**: Uptime and availability

## Configuration Options

### Multiple Servers
```bash
SERVERS=(
    "web01.example.com"
    "web02.example.com"
    "192.168.1.100"
    "localhost"
)
```

### Custom Endpoints
The script automatically tries these endpoints:
- `http://server/server-status?auto`
- `https://server/server-status?auto`

### Metric Scaling
- Load averages multiplied by 100 (1.25 → 125)
- CPU percentages multiplied by 100 (5.7% → 570) 
- Request rates per 1000 seconds
- All values rounded to whole numbers

## Troubleshooting

### Common Issues

**403 Forbidden Error**
- Check Apache status module configuration
- Verify IP address access permissions
- Ensure `ExtendedStatus On` is set

**Connection Refused**
- Verify Apache is running: `systemctl status apache2`
- Check firewall rules between monitoring and target servers
- Test manual curl access

**No Metrics in AppDynamics**
- Verify Machine Agent is running
- Check monitor.xml syntax and file permissions
- Review Machine Agent logs: `/opt/appdynamics/machine-agent/logs/`
- Test script output manually

**Script Returns All Zeros**
- Check server hostname resolution
- Verify correct protocol (HTTP vs HTTPS)
- Ensure Apache status page returns data

### Debug Mode

Enable debug output by modifying the script:
```bash
# Add after metrics_data assignment
echo "Debug: Endpoint: $endpoint" >&2
echo "Debug: Response length: ${#metrics_data}" >&2
```

## Performance Impact

- Minimal overhead: Single HTTP request per server per minute
- Low resource usage: Basic curl and text processing
- Non-blocking: Uses connection timeouts to prevent hangs

## Compatibility

**Tested Apache Versions:**
- Apache 2.4.x (Ubuntu, RHEL, CentOS)
- Apache 2.2.x (legacy systems)

**Supported Platforms:**
- Ubuntu 18.04+
- RHEL/CentOS 7+
- Amazon Linux 2
- Rocky Linux 8+

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test with your Apache environment  
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For issues and questions:
- Open a GitHub issue
- Include Apache version and OS details
- Provide sample script output
- Check AppDynamics Machine Agent logs

## Related Resources

- [AppDynamics Machine Agent Documentation](https://docs.appdynamics.com/appd/24.x/latest/en/infrastructure-visibility/machine-agent)
- [Apache mod_status Documentation](https://httpd.apache.org/docs/2.4/mod/mod_status.html)
- [Custom Metrics with AppDynamics](https://docs.appdynamics.com/appd/24.x/latest/en/infrastructure-visibility/machine-agent/extensions-and-custom-metrics)
