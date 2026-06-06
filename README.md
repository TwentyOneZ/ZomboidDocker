# Project Zomboid Unstable Docker

Servidor dedicado de Project Zomboid usando Docker e SteamCMD. O container baixa e atualiza o Project Zomboid Dedicated Server pelo SteamCMD com o app ID `380870`.

A branch padrao e `unstable`, instalada com:

```bash
app_update 380870 -beta unstable validate
```

Aviso: a versao `unstable` pode quebrar mods, saves ou compatibilidade com clientes. Todos os jogadores precisam usar uma versao compativel do Project Zomboid, preferencialmente na mesma branch do servidor.

## Requisitos

- Docker
- Docker Compose v2
- Linux, Windows com Docker Desktop, ou WSL2

## Uso Rapido

1. Clone o repositorio:

```bash
git clone <URL_DO_REPOSITORIO>
cd pz-unstable-docker
```

2. Crie o arquivo `.env`:

Linux, macOS, Git Bash ou WSL:

```bash
cp .env.example .env
```

Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

3. Edite o `.env`:

```bash
SERVER_NAME=Perspex
STEAM_BRANCH=unstable
UPDATE_ON_START=true
TZ=America/Sao_Paulo
BACKUP_ENABLED=true
BACKUP_TIME=04:30
SHUTDOWN_GRACE_SECONDS=180
BACKUP_TARGET_PATH=G:/Meu Drive/Shared/Zomboid
```

No Windows, prefira `G:/Meu Drive/Shared/Zomboid` no `.env`. Isso aponta para a mesma pasta que `G:\Meu Drive\Shared\Zomboid`, mas evita problemas de parsing no Docker Compose.

4. Suba o servidor:

```bash
docker compose up --build -d
```

5. Veja os logs:

```bash
docker compose logs -f pzserver
```

6. Pare o servidor:

```bash
docker compose stop
```

7. Atualize o servidor:

```bash
docker compose restart
```

Com `UPDATE_ON_START=true`, o restart executa o SteamCMD novamente antes de iniciar o servidor.

8. Acesse o shell do container:

```bash
docker exec -it pz-unstable bash
```

## Backup Diario

O container para o servidor todos os dias as `04:30`, gera um arquivo `.tar.gz` em `./backups`, move esse arquivo para o destino configurado em `BACKUP_TARGET_PATH` e inicia o servidor novamente.

Padrao recomendado para Windows:

```bash
BACKUP_TARGET_PATH=G:/Meu Drive/Shared/Zomboid
```

Dentro do container, esse caminho e montado como:

```txt
/backup-target
```

Se o destino externo falhar, o servidor sera reiniciado mesmo assim. Confira os logs e a pasta `./backups` para localizar arquivos que nao foram movidos.

## Scripts

Os scripts em `scripts/` sao atalhos para os comandos principais:

```bash
bash scripts/start.sh
bash scripts/stop.sh
bash scripts/logs.sh
bash scripts/shell.sh
```

No Linux, se quiser executa-los diretamente:

```bash
chmod +x scripts/*.sh
./scripts/start.sh
```

## Dados Persistentes

Os saves, configuracoes, mods e arquivos gerados pelo Project Zomboid ficam fora do container:

```txt
./data/Zomboid
./data/Zomboid/Server/<SERVER_NAME>.ini
./data/Zomboid/Server/<SERVER_NAME>_SandboxVars.lua
./data/Zomboid/Server/<SERVER_NAME>_spawnregions.lua
```

Os arquivos baixados do Dedicated Server pelo SteamCMD ficam em:

```txt
./server
```

Os backups temporarios locais ficam em:

```txt
./backups
```

As pastas `data/`, `server/`, `backups/` e `backup-target/` sao ignoradas pelo Git e nao devem ser enviadas ao GitHub. Nao versione saves, mods baixados, arquivos gerados do servidor, backups, nem o arquivo `.env`.

## Configuracao do Servidor

Depois da primeira inicializacao, edite:

```txt
./data/Zomboid/Server/<SERVER_NAME>.ini
```

Nesse arquivo voce pode configurar senha, nome publico, quantidade de jogadores e mods. Alguns campos comuns sao:

```ini
PublicName=Meu Servidor PZ
Public=true
Password=senha-do-servidor
MaxPlayers=16
```

Exemplo de configuracao de mods:

```ini
Mods=NomeDoMod1;NomeDoMod2
WorkshopItems=123456789;987654321
```

O valor em `Mods=` usa os IDs internos dos mods. O valor em `WorkshopItems=` usa os IDs numericos dos itens da Steam Workshop.

## Portas Recomendadas

Abra estas portas no firewall e no port forwarding do roteador quando o servidor for acessado pela internet:

```txt
16261/UDP
16262-16272/UDP
8766/UDP
8767/UDP
27015/TCP
```

O `docker-compose.yml` ja mapeia essas portas para o host.

## Linux e Windows

Em Linux, rode os comandos na pasta do projeto. Em Windows, use PowerShell, Git Bash ou WSL2 com Docker Desktop ativo.

Para Linux, troque o destino do backup por uma pasta valida do host:

```bash
BACKUP_TARGET_PATH=/home/seu-usuario/zomboid-backups
```

Se o `entrypoint.sh` falhar no Windows com erro parecido com `bad interpreter`, `bash\r` ou `$'\r': command not found`, reconstrua a imagem depois desta correcao:

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

Este repositorio tambem inclui `.gitattributes` para manter scripts com line endings LF.

## Troubleshooting

- Se o servidor nao baixar, verifique a conexao com a internet e os logs do SteamCMD.
- Se os jogadores nao conectarem, verifique firewall, port forwarding e se as portas UDP/TCP estao abertas.
- Se mods nao carregarem, confira `Mods=` e `WorkshopItems=` no arquivo `.ini`.
- Se houver conflito de versao, confirme que cliente e servidor estao na mesma branch.
- Se o backup nao aparecer no Google Drive, confirme que `BACKUP_TARGET_PATH` existe no host e esta compartilhado com o Docker Desktop.
- Se usar Windows e o `entrypoint.sh` falhar, converta os line endings de CRLF para LF e reconstrua a imagem.
