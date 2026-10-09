# Récapitulatif des commandes Docker

| Commande | Rôle | Exemple | À retenir |
|---|---|---|---|
| `docker run` | Crée puis démarre un nouveau conteneur à partir d'une image. | `docker run -d --name web -p 8080:80 nginx` | `-d` lance en arrière-plan, `--name` donne un nom, `-p` publie un port. |
| `docker ps` | Affiche les conteneurs en cours d'exécution. | `docker ps` | Utiliser `docker ps -a` pour voir aussi les conteneurs arrêtés. |
| `docker images` | Affiche les images Docker présentes localement. | `docker images` | Une image sert de modèle pour créer des conteneurs. |
| `docker stop` | Arrête un conteneur en cours d'exécution. | `docker stop web` | Le conteneur existe toujours après son arrêt. |
| `docker rm` | Supprime un conteneur. | `docker rm web` | Le conteneur doit généralement être arrêté. `docker rm -f web` force sa suppression. |
| `docker exec` | Exécute une commande dans un conteneur déjà démarré. | `docker exec -it web sh` | Très utile pour ouvrir un terminal dans un conteneur. |
| `docker logs` | Affiche les logs d'un conteneur. | `docker logs web` | `docker logs -f web` permet de suivre les logs en direct. |
| `docker inspect` | Affiche les informations détaillées d'un objet Docker. | `docker inspect web` | Permet de voir les ports, réseaux, volumes, variables d'environnement, état, etc. |

## Commandes complémentaires utiles

| Commande | Rôle | Exemple |
|---|---|---|
| `docker start` | Redémarre un conteneur existant qui est arrêté. | `docker start web` |
| `docker rmi` | Supprime une image Docker. | `docker rmi nginx` |

## Différences importantes

| Commandes | Différence |
|---|---|
| `docker run` vs `docker start` | `run` crée un **nouveau** conteneur puis le démarre ; `start` redémarre un conteneur **déjà existant**. |
| `docker rm` vs `docker rmi` | `rm` supprime un **conteneur** ; `rmi` supprime une **image**. |
| `docker ps` vs `docker ps -a` | `ps` montre seulement les conteneurs actifs ; `ps -a` montre tous les conteneurs. |

## Workflow typique

```bash
docker images
docker run -d --name web -p 8080:80 nginx
docker ps
docker logs web
docker exec -it web sh
docker inspect web
docker stop web
docker ps -a
docker rm web
```
