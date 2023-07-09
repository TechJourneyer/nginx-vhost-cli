
# Nginx Virtual Host CLI Script

This Bash script helps in creating and deleting virtual hosts for the Nginx web server.

## Prerequisites

- Nginx web server is installed and running.
- PHP-FPM is installed (required for setting up the `fastcgi_pass` parameter).

## Usage

1. Clone the repository:

   ```bash
   git clone <repository_url>
   ```

2. Navigate to the script directory:

   ```bash
   cd nginx-vhost-cli
   ```

3. Make the script executable:

   ```bash
   chmod +x create_vhost.sh
   ```

4. Create a virtual host:

   ```bash
   ./create_vhost.sh create
   ```

5. Delete a virtual host:

   ```bash
   ./create_vhost.sh delete
   ```

## License

This script is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.
```

Feel free to modify the content as needed to suit your requirements.
