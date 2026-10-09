| Commande          | À quoi elle sert | Exemple | À retenir |
|---|---|---|---|
| `docker build`      | Crée une image a partir d'un Dockerfile | `docker build -t name:tag ` | **Crée** |
| `docker run`      | Crée et démarre un nouveau conteneur à partir d’une image | `docker run -d nginx` | **Crée + démarre** |
| `docker ps`       | Affiche les conteneurs en cours d’exécution | `docker ps` | Ajouter `-a` pour voir aussi les conteneurs arrêtés |
| `docker images`   | Affiche les images Docker présentes en local | `docker images` | Permet de voir les images disponibles |
| `docker stop`     | Arrête un conteneur en cours d’exécution | `docker stop mon-nginx` | Le conteneur n’est pas supprimé |
| `docker rm`   | Supprime un conteneur | `docker rm mon-nginx` | En général, il faut l’arrêter avant |
| `docker exec` | Exécute une commande dans un conteneur déjà démarré | `docker exec -it mon-nginx sh` | Très utilisé pour entrer dans un conteneur |
| `docker logs` | Affiche les logs d’un conteneur | `docker logs mon-nginx` | Avec `-f`, on suit les logs en direct |
| `docker inspect` | Affiche les informations détaillées d’un conteneur ou objet Docker | `docker inspect mon-nginx` | Réseau, IP, volumes, variables, ports, etc. |