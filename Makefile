COMPOSE  = docker compose -f srcs/docker-compose.yml
DATA_DIR = /home/dabuchhe/data
SECRETS  = secrets/db_user_password.txt secrets/db_root_password.txt \
           secrets/wp_user_password.txt secrets/wp_admin_password.txt

all: up

up: $(SECRETS)
	@for f in $(SECRETS); do [ -s $$f ] || { \
		echo "$$f is empty: write its password in it, then run make again"; exit 1; }; done
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	$(COMPOSE) up -d --build

secrets: $(SECRETS)

$(SECRETS):
	mkdir -p secrets
	touch $@

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

.PHONY: all up down ps logs clean fclean re secrets
