# DevOps Playground: Automating MySQL Backup with Bash, Docker, and GitHub Actions

This project is a hands-on DevOps exercise to create a CI/CD pipeline for a simple MySQL database backup script using Bash, Docker, and GitHub Actions. The goal is to automate the process of backing up a database, running tests, and building a Docker image.

---

## Overview

The project is divided into five iterations:

1. **Set up a MySQL database** using Docker and seed it with dummy data.
2. **Create a Bash script** to automate the database backup process.
3. **Write unit tests** for the Bash script using the Bash Automated Testing System (BATS).
4. **Dockerize the application** to create a portable artifact.
5. **Set up a CI/CD pipeline** using GitHub Actions to automate testing and Docker image creation.

---

## Steps to Reproduce

### Iteration 1: Set Up MySQL Database

1. Start a MySQL container using Docker:

        docker run --name mysql-demo -e MYSQL_ROOT_PASSWORD=admin -e MYSQL_DATABASE=mydatabase -p 3306:3306 -d mysql:latest

2. Create a `seed.sql` file to seed the database with dummy data:

        -- seed.sql
        USE mydatabase;
        CREATE TABLE IF NOT EXISTS employees (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100),
            position VARCHAR(100),
            salary INT
        );

        INSERT INTO employees (name, position, salary) VALUES 
        ('Alice', 'Engineer', 70000),
        ('Bob', 'Manager', 85000),
        ('Charlie', 'Analyst', 60000);

3. Apply the SQL script to the database:

        mysql -h 127.0.0.1 -u root -padmin < seed.sql

4. Verify the data was inserted:

        mysql -h 127.0.0.1 -u root -padmin -e "SELECT * FROM mydatabase.employees;"

---

### Iteration 2: Create a Bash Script for Backup

1. Create a `.env` file to store sensitive information:

        # .env
        DB_HOST="127.0.0.1"
        DB_USER="root"
        MYSQL_PWD="admin"
        DB_NAME="mydatabase"

2. Write the `backup.sh` script:

        #!/bin/bash

        # Load environment variables
        set -a
        [ -f .env ] && . .env
        set +a

        # Configuration
        BACKUP_DIR="backups"
        TIMESTAMP=$(date +"%F_%T")

        # Create backup directory if it doesn't exist
        if [ ! -d "$BACKUP_DIR" ]; then
            mkdir -p "$BACKUP_DIR"
        fi

        # Perform the backup
        mysqldump -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql"

        # Check if the backup was successful
        if [ $? -eq 0 ]; then
            echo "$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql"
        else
            echo "Backup failed!"
            exit 1
        fi

3. Make the script executable:

        chmod +x backup.sh

4. Run the script:

        ./backup.sh

---

### Iteration 3: Write Unit Tests with BATS

1. Create a `test.bats` file:

        # test.bats
        #!/usr/bin/env bats

        # Configuration for testing
        BACKUP_DIR="backups"
        DB_NAME="mydatabase"

        # Test 1: Check if backup directory exists
        @test "Backup directory exists" {
          run bash -c "[ -d \"$BACKUP_DIR\" ]"
          [ "$status" -eq 0 ]
        }

        # Test 2: Check if backup file is created and non-empty
        @test "Backup file is created and is non-empty" {
          run bash ./backup.sh
          BACKUP_FILE=$output
          [ "$status" -eq 0 ] && [ -f $BACKUP_FILE ] && [ "$(wc -c < $BACKUP_FILE)" -gt 0 ]
        }

2. Run the tests:

        bats test.bats

---

### Iteration 4: Dockerize the Application

1. Create a `Dockerfile`:

        # Dockerfile
        FROM ubuntu:20.04

        # Set environment variables
        ENV DEBIAN_FRONTEND=noninteractive

        # Install dependencies
        RUN apt-get update && apt-get install -y \
            mysql-client \
            bats \
            && apt-get clean

        # Create working directory
        WORKDIR /usr/src/app

        # Copy the backup and BATS test scripts into the container
        COPY backup.sh test.bats ./

        # Make the backup script executable
        RUN chmod +x backup.sh

        # Create the backup directory inside the container
        RUN mkdir backups

        # Entry point to run the BATS tests
        ENTRYPOINT ["/usr/bin/bash"]

2. Build the Docker image:

        docker build -t dbbackup:latest .

3. Test the Docker image:

        docker run --network="host" \
        -v $(pwd)/backups:/usr/src/app/backups \
        -e DB_HOST=127.0.0.1 \
        -e DB_USER=root \
        -e DB_PASSWORD=admin \
        -e DB_NAME=mydatabase \
        -it dbbackup:latest /usr/bin/bash backup.sh

4. Push the Docker image to Docker Hub:

        docker tag dbbackup:latest <your-dockerhub-username>/dbbackup:1.0.0
        docker push <your-dockerhub-username>/dbbackup:1.0.0

---

### Iteration 5: Set Up CI/CD with GitHub Actions

1. Create a `.github/workflows/ci-cd.yml` file:

        name: CI/CD Pipeline for MySQL Backup Script

        on:
          push:
            branches:
              - main
          pull_request:
            branches:
              - main
        env: 
          DB_HOST: "127.0.0.1"
          DB_USER: "root"
          MYSQL_PWD: "password"
          DB_NAME: "mydatabase"

        jobs:
          test:
            name: Run BATS Tests
            runs-on: ubuntu-latest

            services:
              mysql:
                image: mysql:latest
                env:
                  MYSQL_ROOT_PASSWORD: password
                options: >-
                  --health-cmd="mysqladmin ping --silent"
                  --health-interval=10s
                  --health-timeout=5s
                  --health-retries=5
                ports:
                  - 3306:3306

            steps:
              # Step 1: Checkout the repository
              - name: Checkout code
                uses: actions/checkout@v4

              # Step 2: Install BATS and MySQL client
              - name: Install dependencies
                run: |
                  sudo apt-get update
                  sudo apt-get install -y bats mysql-client

              - name: Create backups directory
                run: mkdir -p backups

              # Step 3: Wait for MySQL service to be ready
              - name: Wait for MySQL to be ready
                run: |
                  for i in {1..30}; do
                    if mysqladmin ping -h 127.0.0.1 --silent; then
                      echo "MySQL is ready!"
                      break
                    fi
                    echo "Waiting for MySQL..."
                    sleep 5
                  done

              # Step 4: Seed the database using the SQL script
              - name: Seed database
                run: mysql -h 127.0.0.1 -u root -ppassword < seed.sql

              # Step 5: Run the BATS tests
              - name: Run BATS tests
                run: bats test.bats

          build:
            name: Build and Push Docker Image
            runs-on: ubuntu-latest
            needs: test

            steps:
              # Step 1: Checkout the repository
              - name: Checkout code
                uses: actions/checkout@v4

              # Step 2: Set up Docker Buildx
              - name: Set up Docker Buildx
                uses: docker/setup-buildx-action@v3

              # Step 3: Log in to Docker Hub
              - name: Log in to Docker Hub
                uses: docker/login-action@v3
                with:
                  username: ${{ secrets.DOCKER_USERNAME }}
                  password: ${{ secrets.DOCKER_PASSWORD }}

              # Step 4: Get commit hash and semantic version for tagging
              - name: Set up tags for Docker image
                id: vars
                run: |
                  COMMIT_HASH=$(git rev-parse --short HEAD)
                  echo "COMMIT_HASH=${COMMIT_HASH}" >> $GITHUB_ENV

                  # Extract version from git tags (fallback to 0.1.0 if no tags are available)
                  TAG_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.1.0")
                  echo "TAG_VERSION=${TAG_VERSION}" >> $GITHUB_ENV

              # Step 5: Build and tag the Docker image
              - name: Build Docker image
                run: |
                  docker build -t ${{ secrets.DOCKER_USERNAME }}/mysql-backup:${{ env.TAG_VERSION }} -t ${{ secrets.DOCKER_USERNAME }}/mysql-backup:${{ env.COMMIT_HASH }} .

              # Step 6: Push the Docker image to Docker Hub
              - name: Push Docker image
                run: |
                  docker push ${{ secrets.DOCKER_USERNAME }}/mysql-backup:${{ env.TAG_VERSION }}
                  docker push ${{ secrets.DOCKER_USERNAME }}/mysql-backup:${{ env.COMMIT_HASH }}

---

## Conclusion

This project demonstrates how to automate a simple yet practical task (database backup) using Bash, Docker, and GitHub Actions. It covers the entire CI/CD pipeline, from testing to building and pushing Docker images.

