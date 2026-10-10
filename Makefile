COMPOSE  = docker compose -f srcs/docker-compose.yml
DATA_DIR = /home/dabuchhe/data

all: up

up:
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down --rmi all -v

fclean: clean
	sudo rm -rf $(DATA_DIR)

re: fclean all

.PHONY: all up down ps logs clean fclean re
