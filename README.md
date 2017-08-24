# -POC0_ocsg61_np
---

Docker Project/POC to deploy using Docker Compose the product : OCSG 6.1 ( Oracle Communications Gatekeeper)


## Requisites

Copy the next files from *official Oracle Download WebSites* to main directory where Dockerfile is located:

  * jdk-8u144-linux-x64.rpm
  * ocsg_multitier_generic.jar

  ## Built Image

  > sudo docker build -t <your id/name>/ocsg:6.1 .

  ## Run Image

  A Docker compose file is included, modify as needed
  > sudo docker-compose up

  *Note:* Launch in detached mode to avoid see the Std Output in your Prompt after launch command

  ## Alternative Run Method

  You can launch the containers *"independently"*:

    1. docker run --name <choose a name:i.e: ocsg6-mysql> -e MYSQL_ROOT_PASSWORD=<your password> -e MYSQL_DATABASE=ocsg -e MYSQL_USER=ocsg -e MYSQL_PASSWORD=<your password> -d mysql:5.6
    2. docker run -d --name <choose a name: i.e: ocsg6> -p 7001:7001 --link <name>:<name> <name>/<name>:<tag>

  ## Test Product

  > Access to the WebLogic Console under 7001 port to check the Admin Node
