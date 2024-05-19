
# PrestaShop Development Environment

This repository provides a complete setup for a PrestaShop development environment using Docker. The setup includes two main components:

1. **Base Container**: Contains all dependencies and tools needed for PrestaShop development except PrestaShop itself. It includes a decent shell and the ability to SSH into it using a public key.
2. **Development Container**: Can be quickly adapted and deployed, containing the PrestaShop application.

## Prerequisites

Ensure you have Docker and Docker Compose installed on your machine.

## Setup Instructions

### Building the Base and Development Containers

1. Clone this repository.
2. You can change Dockerfile.devel to install a different version of PS or customize your image
3. Build the Docker images using the provided `docker.sh` script:

   ```sh
   ./docker.sh build
   ```

### Running the Development Environment

1. Start the development environment:

   ```sh
   ./docker.sh up
   ```

### SSH Access to the Base Container

The base container is set up with OpenSSH server and allows SSH access using public key authentication. Ensure your public key is added to the container.

## Configuration Details

### Dockerfile.base

This Dockerfile sets up the base container with all necessary dependencies and tools except PrestaShop. It includes configurations for PHP, SSH, and other essential tools.

### Dockerfile.devel

This Dockerfile sets up the development container, adding PrestaShop and other necessary configurations for a development environment.

### docker-compose.yml

This file defines the services and configurations for Docker Compose, including the PrestaShop service and MySQL database.

## Scripts

### docker.sh

This script facilitates building and managing the Docker containers. It includes commands for building the base and development containers and starting the development environment.

### install_everything.sh

This script automates the setup process by:

1. Updating package lists and installing necessary dependencies.
2. Installing Docker and Docker Compose.
3. Setting up Docker images and containers for PrestaShop.
4. Configuring the development environment.

## Notes

- Ensure your public SSH key is correctly added to the configuration for SSH access.
- Adjust any environment variables as necessary in the `docker-compose.yml` file.

## Links

- https://ramyhakam.medium.com/php-remote-debugging-with-vscode-a-comprehensive-guide-f20e67000b7d
- PS Commands : https://github.com/nenes25/prestashop_console/blob/1.7/COMMANDS.md
- module bootstrap: https://github.com/friends-of-presta/demo-cqrs-hooks-usage-module
- http://logio.org/
- https://webkul.com/blog/create-your-own-console-command-in-prestashop-1-7/