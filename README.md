# Cal Tracker

Aplicacion para registrar y consultar informacion nutricional.

## Servidor

Dominio: `https://bettercalories.app`

IP del servidor: `82.223.104.126`

Usuario: `root`

Comando SSH:

```bash
ssh root@82.223.104.126
```

El servidor esta preparado con Docker, NGINX y HTTPS mediante Let's Encrypt.
De momento NGINX sirve una pagina estatica dummy para validar el despliegue.

## CI/CD backend

El backend se despliega con GitHub Actions, Bun, GHCR y blue/green en Docker.

Dominios API:

- Dev: `https://dev-api.bettercalories.app`
- Pro: `https://api.bettercalories.app`

Registros DNS necesarios:

```text
A api.bettercalories.app -> 82.223.104.126
A dev-api.bettercalories.app -> 82.223.104.126
```

Secrets de GitHub necesarios:

- `VPS_HOST`: `82.223.104.126`
- `VPS_USER`: `root`
- `VPS_SSH_PRIVATE_KEY`
- `GHCR_USERNAME`
- `GHCR_READ_TOKEN`
- `DEPLOY_ENV_FILE`
- `DEV_ENV_FILE`
- `PRO_ENV_FILE`

`DEPLOY_ENV_FILE` debe incluir:

```env
POSTGRES_PASSWORD=change-me
BACKEND_IMAGE=ghcr.io/autofactu/cal-tracker-backend:bootstrap
```

Dev usa el schema Postgres `cal_tracker_dev` y produccion usa `cal_tracker_pro`.
El despliegue a dev se ejecuta con push a `main`; produccion se ejecuta con tags `v*`.
