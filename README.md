# Project Zomboid Unstable Docker

Servidor dedicado de Project Zomboid usando Docker e SteamCMD. O container baixa e atualiza o Project Zomboid Dedicated Server pelo SteamCMD com o app ID `380870`.

A branch padrão é `unstable`, instalada com:

```bash
app_update 380870 -beta unstable validate
```

Aviso: a versão `unstable` pode quebrar mods, saves ou compatibilidade com clientes. Todos os jogadores precisam usar uma versão compatível do Project Zomboid, preferencialmente na mesma branch do servidor.

## Requisitos

- Docker
- Docker Compose v2
- Linux, Windows com Docker Desktop, ou WSL2

## Uso Rápido

1. Clone o repositório:

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
```

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

## Scripts

Os scripts em `scripts/` são atalhos para os comandos principais:

```bash
bash scripts/start.sh
bash scripts/stop.sh
bash scripts/logs.sh
bash scripts/shell.sh
```

No Linux, se quiser executá-los diretamente:

```bash
chmod +x scripts/*.sh
./scripts/start.sh
```

## Dados Persistentes

Os saves, configurações, mods e arquivos gerados pelo Project Zomboid ficam fora do container:

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

As pastas `data/` e `server/` são ignoradas pelo Git e não devem ser enviadas ao GitHub. Não versione saves, mods baixados, arquivos gerados do servidor, nem o arquivo `.env`.

## Configuração do Servidor

Depois da primeira inicialização, edite:

```txt
./data/Zomboid/Server/<SERVER_NAME>.ini
```

Nesse arquivo você pode configurar senha, nome público, quantidade de jogadores e mods. Alguns campos comuns são:

```ini
PublicName=Meu Servidor PZ
Public=true
Password=senha-do-servidor
MaxPlayers=16
```

Exemplo de configuração de mods:

```ini
Mods=NomeDoMod1;NomeDoMod2
WorkshopItems=123456789;987654321
```

O valor em `Mods=` usa os IDs internos dos mods. O valor em `WorkshopItems=` usa os IDs numéricos dos itens da Steam Workshop.

## Portas Recomendadas

Abra estas portas no firewall e no port forwarding do roteador quando o servidor for acessado pela internet:

```txt
16261/UDP
16262-16272/UDP
8766/UDP
8767/UDP
27015/TCP
```

O `docker-compose.yml` já mapeia essas portas para o host.

## Linux e Windows

Em Linux, rode os comandos na pasta do projeto. Em Windows, use PowerShell, Git Bash ou WSL2 com Docker Desktop ativo.

Se o `entrypoint.sh` falhar no Windows com erro parecido com `bad interpreter` ou `$'\r': command not found`, converta os line endings de CRLF para LF. No Git, você pode forçar isso com:

```bash
git config core.autocrlf input
git add --renormalize .
```

## Troubleshooting

- Se o servidor não baixar, verifique a conexão com a internet e os logs do SteamCMD.
- Se os jogadores não conectarem, verifique firewall, port forwarding e se as portas UDP/TCP estão abertas.
- Se mods não carregarem, confira `Mods=` e `WorkshopItems=` no arquivo `.ini`.
- Se houver conflito de versão, confirme que cliente e servidor estão na mesma branch.
- Se usar Windows e o `entrypoint.sh` falhar, converta os line endings de CRLF para LF.
